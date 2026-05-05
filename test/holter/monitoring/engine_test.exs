defmodule Holter.Monitoring.EngineTest do
  use Holter.DataCase, async: true
  alias Holter.Monitoring
  alias Holter.Monitoring.Engine

  @monitor_attrs %{
    url: "https://test.local",
    method: :get,
    interval_seconds: 60,
    logical_state: :active,
    raw_keyword_positive: "success",
    raw_keyword_negative: "error",
    health_status: :up
  }

  setup do
    workspace = workspace_fixture()
    attrs = Map.put(@monitor_attrs, :workspace_id, workspace.id)
    {:ok, monitor} = Monitoring.create_monitor(attrs)
    %{monitor: monitor, workspace: workspace}
  end

  describe "when response is 200 OK and matching keywords" do
    setup %{monitor: monitor} do
      {:ok, _} =
        Engine.process_response(monitor, ok_response("Everything is a success!"), %{
          duration_ms: 100
        })

      :ok
    end

    test "sets health_status to :up", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :up
    end
  end

  describe "when response is HTTP 500" do
    setup %{monitor: monitor} do
      {:ok, _} =
        Engine.process_response(monitor, error_response(500, "Internal Error"), %{
          duration_ms: 100
        })

      :ok
    end

    test "sets health_status to :down", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :down
    end

    test "opens a downtime incident", %{monitor: monitor} do
      assert %{type: :downtime} = Monitoring.get_open_incident(monitor.id, :downtime)
    end

    test "sets the incident root_cause from the HTTP status", %{monitor: monitor} do
      assert %{root_cause: "HTTP Error: 500"} =
               Monitoring.get_open_incident(monitor.id, :downtime)
    end
  end

  describe "when positive keyword is missing" do
    setup %{monitor: monitor} do
      {:ok, _} =
        Engine.process_response(monitor, ok_response("No match here"), %{duration_ms: 100})

      :ok
    end

    test "sets health_status to :down", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :down
    end

    test "opens a downtime incident", %{monitor: monitor} do
      assert %{type: :downtime} = Monitoring.get_open_incident(monitor.id, :downtime)
    end

    test "sets root_cause to missing keywords message including the keyword name", %{
      monitor: monitor
    } do
      assert %{root_cause: "Missing required keywords: \"success\""} =
               Monitoring.get_open_incident(monitor.id, :downtime)
    end
  end

  describe "when forbidden keyword is found (defacement)" do
    setup %{monitor: monitor} do
      {:ok, _} =
        Engine.process_response(monitor, ok_response("success but has an error"), %{
          duration_ms: 100
        })

      :ok
    end

    test "sets health_status to :compromised", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :compromised
    end

    test "opens a defacement incident", %{monitor: monitor} do
      assert %{type: :defacement} = Monitoring.get_open_incident(monitor.id, :defacement)
    end

    test "sets root_cause to found forbidden keywords message including the keyword name", %{
      monitor: monitor
    } do
      assert %{root_cause: "Found forbidden keywords: \"error\""} =
               Monitoring.get_open_incident(monitor.id, :defacement)
    end
  end

  describe "when transitioning from down to compromised" do
    setup %{monitor: monitor} do
      {:ok, monitor_down} =
        Engine.process_response(monitor, error_response(500, ""), %{duration_ms: 100})

      {:ok, _} =
        Engine.process_response(monitor_down, ok_response("success error"), %{duration_ms: 100})

      :ok
    end

    test "resolves the downtime incident", %{monitor: monitor} do
      assert is_nil(Monitoring.get_open_incident(monitor.id, :downtime))
    end

    test "opens a defacement incident", %{monitor: monitor} do
      assert %{type: :defacement} = Monitoring.get_open_incident(monitor.id, :defacement)
    end

    test "sets health_status to :compromised", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :compromised
    end
  end

  describe "when recovering from defacement" do
    setup %{monitor: monitor} do
      {:ok, monitor_hacked} =
        Engine.process_response(monitor, ok_response("success error"), %{duration_ms: 100})

      {:ok, _} =
        Engine.process_response(monitor_hacked, ok_response("success"), %{duration_ms: 100})

      :ok
    end

    test "resolves the defacement incident", %{monitor: monitor} do
      assert is_nil(Monitoring.get_open_incident(monitor.id, :defacement))
    end

    test "sets health_status to :up", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :up
    end
  end

  describe "handle_failure/3 on network error" do
    setup %{monitor: monitor} do
      {:ok, _} = Engine.handle_failure(monitor, %RuntimeError{message: "connection refused"}, 50)
      :ok
    end

    test "sets health_status to :down", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :down
    end

    test "records the exception message in the log", %{monitor: monitor} do
      assert [%{error_message: "connection refused"}] =
               Monitoring.list_monitor_logs(monitor, %{}).logs
    end
  end

  describe "selective evidence storage on failure" do
    setup %{monitor: monitor} do
      {:ok, _} =
        Engine.process_response(
          monitor,
          error_response(500, "<html><body>Internal Error</body></html>"),
          %{duration_ms: 100}
        )

      %{log: List.first(Monitoring.list_monitor_logs(monitor, %{}).logs)}
    end

    test "records failure status", %{log: log} do
      assert log.status == :down
    end

    test "captures response headers", %{log: log} do
      assert log.response_headers["content-type"] == "text/plain"
    end

    test "captures sanitized response snippet", %{log: log} do
      assert log.response_snippet == "Internal Error"
    end
  end

  describe "selective evidence storage on identical checks" do
    setup %{monitor: monitor} do
      {:ok, monitor_down} =
        Engine.process_response(monitor, error_response(500, "Error 1"), %{duration_ms: 100})

      {:ok, _} =
        Engine.process_response(monitor_down, error_response(500, "Error 2"), %{duration_ms: 100})

      logs =
        Monitoring.list_monitor_logs(monitor, %{}).logs
        |> Enum.sort_by(&{&1.checked_at, &1.inserted_at, &1.id})

      %{logs: logs}
    end

    test "stores evidence for the first transition log", %{logs: [log1, _log2]} do
      assert log1.response_snippet == "Error 1"
    end

    test "omits snippet for the second identical check", %{logs: [_log1, log2]} do
      assert is_nil(log2.response_snippet)
    end

    test "omits headers for the second identical check", %{logs: [_log1, log2]} do
      assert is_nil(log2.response_headers)
    end
  end

  describe "robustness against real-world data variability" do
    test "handles content-type when it comes as a list", %{monitor: monitor} do
      response = %Req.Response{
        status: 200,
        body: "success",
        headers: [{"content-type", ["text/html; charset=utf-8"]}]
      }

      assert {:ok, _} = Engine.process_response(monitor, response, %{duration_ms: 100})
    end

    test "handles headers when they come as a string", %{monitor: monitor} do
      response = %Req.Response{
        status: 200,
        body: "success",
        headers: [{"content-type", "text/plain"}]
      }

      assert {:ok, _} = Engine.process_response(monitor, response, %{duration_ms: 100})
    end

    test "handles missing body gracefully", %{monitor: monitor} do
      response = %Req.Response{
        status: 200,
        body: nil,
        headers: []
      }

      assert {:ok, _} = Engine.process_response(monitor, response, %{duration_ms: 100})
    end

    test "handles non-UTF8 encoded body gracefully without crashing", %{monitor: monitor} do
      invalid_utf8_body = <<195, 40, 231, 97, 111>>

      response = %Req.Response{
        status: 200,
        body: invalid_utf8_body,
        headers: [{"content-type", "text/html; charset=ISO-8859-1"}]
      }

      assert {:ok, _} = Engine.process_response(monitor, response, %{duration_ms: 100})
    end

    test "saves non-UTF8 snippet correctly", %{monitor: monitor} do
      invalid_utf8_body = <<195, 40, 231, 97, 111>>

      response = %Req.Response{
        status: 500,
        body: invalid_utf8_body,
        headers: [{"content-type", "text/html; charset=ISO-8859-1"}]
      }

      {:ok, _} = Engine.process_response(monitor, response, %{duration_ms: 100})

      log = Monitoring.list_monitor_logs(monitor, %{}).logs |> List.first()
      assert is_binary(log.response_snippet)
    end

    test "ensures saved snippet is valid UTF8", %{monitor: monitor} do
      invalid_utf8_body = <<195, 40, 231, 97, 111>>

      response = %Req.Response{
        status: 500,
        body: invalid_utf8_body,
        headers: [{"content-type", "text/html; charset=ISO-8859-1"}]
      }

      {:ok, _} = Engine.process_response(monitor, response, %{duration_ms: 100})

      log = Monitoring.list_monitor_logs(monitor, %{}).logs |> List.first()
      assert String.valid?(log.response_snippet)
    end
  end

  describe "case-insensitive keyword matching" do
    test "matches positive keyword regardless of case", %{monitor: monitor} do
      assert {:ok, updated_monitor} =
               Engine.process_response(monitor, ok_response("SUCCESS"), %{duration_ms: 100})

      assert %{health_status: :up} = updated_monitor

      log = Monitoring.list_monitor_logs(monitor, %{}).logs |> List.first()
      assert %{status: :up, error_message: nil} = log
    end

    test "matches forbidden keyword regardless of case", %{monitor: monitor} do
      assert {:ok, updated_monitor} =
               Engine.process_response(monitor, ok_response("success but has ERROR"), %{
                 duration_ms: 100
               })

      assert %{health_status: :compromised} = updated_monitor

      log = Monitoring.list_monitor_logs(monitor, %{}).logs |> List.first()
      assert %{status: :compromised, error_message: "Found forbidden keywords: \"error\""} = log

      assert %{type: :defacement} = Monitoring.get_open_incident(monitor.id, :defacement)
    end
  end

  describe "incident-aware logging: active ssl_expiry incident during HTTP check" do
    setup %{monitor: monitor} do
      {:ok, ssl_incident} =
        Monitoring.create_incident(%{
          monitor_id: monitor.id,
          type: :ssl_expiry,
          started_at: DateTime.utc_now() |> DateTime.truncate(:second),
          root_cause: "Certificate expires in 3 days (Critical)"
        })

      {:ok, _} =
        Engine.process_response(monitor, ok_response("success"), %{duration_ms: 100})

      %{ssl_incident: ssl_incident}
    end

    test "log status inherits :compromised from Critical ssl_expiry incident instead of :up",
         %{monitor: monitor} do
      log = Monitoring.list_monitor_logs(monitor, %{}).logs |> List.first()
      assert log.status == :compromised
    end

    test "log incident_id links to the active ssl_expiry incident",
         %{monitor: monitor, ssl_incident: ssl_incident} do
      log = Monitoring.list_monitor_logs(monitor, %{}).logs |> List.first()
      assert log.incident_id == ssl_incident.id
    end

    test "ssl_expiry incident remains open because HTTP check lifecycle does not resolve it",
         %{monitor: monitor} do
      assert %{type: :ssl_expiry} = Monitoring.get_open_incident(monitor.id, :ssl_expiry)
    end

    test "monitor health_status reflects :compromised from open ssl_expiry incident, not raw :up check",
         %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :compromised
    end
  end

  describe "incident-aware logging: active degraded ssl_expiry incident during HTTP check" do
    setup %{monitor: monitor} do
      {:ok, _} =
        Monitoring.create_incident(%{
          monitor_id: monitor.id,
          type: :ssl_expiry,
          started_at: DateTime.utc_now() |> DateTime.truncate(:second),
          root_cause: "Certificate expires in 10 days (Warning)"
        })

      {:ok, _} =
        Engine.process_response(monitor, ok_response("success"), %{duration_ms: 100})

      :ok
    end

    test "log status is :degraded when ssl_expiry root_cause is a warning", %{monitor: monitor} do
      log = Monitoring.list_monitor_logs(monitor, %{}).logs |> List.first()
      assert log.status == :degraded
    end

    test "monitor health_status reflects :degraded from open warning ssl_expiry incident, not raw :up check",
         %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :degraded
    end
  end

  describe "incident-aware logging: no active incidents" do
    setup %{monitor: monitor} do
      {:ok, _} =
        Engine.process_response(monitor, ok_response("success"), %{duration_ms: 100})

      :ok
    end

    test "log status equals the raw check result when no open incidents exist",
         %{monitor: monitor} do
      log = Monitoring.list_monitor_logs(monitor, %{}).logs |> List.first()
      assert log.status == :up
    end

    test "log incident_id is nil when no open incidents exist", %{monitor: monitor} do
      log = Monitoring.list_monitor_logs(monitor, %{}).logs |> List.first()
      assert is_nil(log.incident_id)
    end
  end

  describe "Unit-level Bug Simulation: Log Status Race Condition" do
    test "the log recorded during recovery incorrectly inherits the OLD status",
         %{monitor: monitor} do
      {:ok, _} = Engine.handle_failure(monitor, %RuntimeError{message: "fail"}, 100)

      response = %Req.Response{status: 200, body: "success", headers: []}
      {:ok, _} = Engine.process_response(monitor, response, %{duration_ms: 50})

      %{logs: [latest_log | _]} = Monitoring.list_monitor_logs(monitor, %{page_size: 1})
      assert latest_log.status == :up
    end
  end

  describe "Unit-level Bug Simulation: Compromised -> Down transition" do
    test "defacement incident SHOULD resolve when monitor goes down (fails if bug exists)",
         %{monitor: monitor} do
      {:ok, monitor} =
        Engine.process_response(monitor, ok_response("success error"), %{duration_ms: 100})

      assert length(Monitoring.list_open_incidents(monitor.id)) == 1

      {:ok, _} = Engine.process_response(monitor, error_response(500, ""), %{duration_ms: 100})

      assert length(Monitoring.list_open_incidents(monitor.id)) == 1
      assert %{type: :downtime} = Monitoring.get_open_incident(monitor.id, :downtime)
    end
  end

  describe "Bug simulation: Log Status Transition (Race Condition)" do
    test "Given a DOWN monitor, when it returns to UP, then the generated log SHOULD be UP (fails if bug exists)",
         %{monitor: monitor} do
      {:ok, _} = Engine.handle_failure(monitor, %RuntimeError{message: "fail"}, 100)
      monitor = Monitoring.get_monitor!(monitor.id)
      assert monitor.health_status == :down

      response = %Req.Response{status: 200, body: "success", headers: []}
      {:ok, updated_monitor} = Engine.process_response(monitor, response, %{duration_ms: 50})

      assert updated_monitor.health_status == :up

      %{logs: [latest_log | _]} = Monitoring.list_monitor_logs(updated_monitor, %{page_size: 1})

      assert latest_log.status == :up
    end
  end

  describe "Bug simulation: Orphaned Defacement Incident (Compromised -> Down)" do
    test "Given a COMPROMISED monitor, when it transitions to DOWN, then the defacement incident SHOULD be resolved (fails if bug exists)",
         %{monitor: monitor} do
      response_compromised = %Req.Response{
        status: 200,
        body: "success but has error",
        headers: []
      }

      {:ok, monitor} = Engine.process_response(monitor, response_compromised, %{duration_ms: 50})
      assert monitor.health_status == :compromised

      response_down = %Req.Response{status: 500, body: "Error", headers: []}
      {:ok, monitor} = Engine.process_response(monitor, response_down, %{duration_ms: 50})
      assert monitor.health_status == :down

      assert length(Monitoring.list_open_incidents(monitor.id)) == 1
      assert %{type: :downtime} = Monitoring.get_open_incident(monitor.id, :downtime)
    end
  end

  describe "Bug simulation: Stale State Update (Race Condition)" do
    test "older check results SHOULD NOT overwrite newer ones (fails if bug exists)",
         %{monitor: monitor} do
      t2 = DateTime.utc_now() |> DateTime.truncate(:second)
      {:ok, monitor} = Engine.handle_failure(monitor, %RuntimeError{message: "fail"}, 100)
      assert monitor.health_status == :down

      _response = %Req.Response{status: 200, body: "success", headers: []}

      {:ok, stale_monitor} =
        Monitoring.update_monitor(monitor, %{
          health_status: :up,
          last_checked_at: DateTime.add(t2, -60, :second)
        })

      assert stale_monitor.health_status == :down
    end
  end

  describe "Bug simulation: Downtime Masking Defacement" do
    test "when site is DOWN and has HACKED keywords, it SHOULD prioritize :down but NOT lose defacement context",
         %{monitor: monitor} do
      response = %Req.Response{status: 500, body: "Site HACKED", headers: []}
      {:ok, monitor} = Engine.process_response(monitor, response, %{duration_ms: 50})

      assert monitor.health_status == :down

      open_incidents = Monitoring.list_open_incidents(monitor.id)
      assert Enum.any?(open_incidents, &(&1.type == :defacement))
    end
  end

  describe "Bug simulation: forbidden keyword found AND required keyword missing simultaneously" do
    setup %{monitor: monitor} do
      {:ok, updated} =
        Engine.process_response(
          monitor,
          ok_response("this page has an error but nothing good"),
          %{duration_ms: 100}
        )

      %{updated: updated}
    end

    test "a defacement incident SHOULD be opened for the forbidden keyword (fails because bug exists)",
         %{monitor: monitor} do
      assert %{type: :defacement} = Monitoring.get_open_incident(monitor.id, :defacement)
    end

    test "a downtime incident SHOULD be opened for the missing required keyword (fails because bug exists)",
         %{monitor: monitor} do
      assert %{type: :downtime} = Monitoring.get_open_incident(monitor.id, :downtime)
    end

    test "health_status SHOULD be :down because :down has higher severity than :compromised in this system (fails because bug exists)",
         %{updated: updated} do
      assert updated.health_status == :down
    end

    test "two open incidents SHOULD exist — one per independent condition (fails because bug exists)",
         %{monitor: monitor} do
      assert length(Monitoring.list_open_incidents(monitor.id)) == 2
    end
  end

  describe "concurrent safety: open_if_missing" do
    test "processing a down response twice does not crash when incident already exists",
         %{monitor: monitor} do
      response = error_response(503, "down")

      {:ok, _} = Engine.process_response(monitor, response, %{duration_ms: 50})
      {:ok, updated} = Engine.process_response(monitor, response, %{duration_ms: 50})

      assert updated.health_status == :down
    end

    test "only one open downtime incident exists after two down responses for the same monitor",
         %{monitor: monitor} do
      response = error_response(503, "down")

      Engine.process_response(monitor, response, %{duration_ms: 50})
      Engine.process_response(monitor, response, %{duration_ms: 50})

      open = Monitoring.list_open_incidents(monitor.id)
      assert length(Enum.filter(open, &(&1.type == :downtime))) == 1
    end
  end

  describe "finalize_check pipeline: defacement_in_body defaults to false on handle_failure" do
    test "network failure does not open a defacement incident", %{monitor: monitor} do
      {:ok, _} = Engine.handle_failure(monitor, %RuntimeError{message: "timeout"}, 100)

      assert is_nil(Monitoring.get_open_incident(monitor.id, :defacement))
    end
  end

  describe "finalize_check pipeline: effective status computation" do
    test "log inherits ssl_expiry incident status even when HTTP check returns 200", %{
      monitor: monitor
    } do
      {:ok, _} =
        Monitoring.create_incident(%{
          monitor_id: monitor.id,
          type: :ssl_expiry,
          started_at: DateTime.utc_now() |> DateTime.truncate(:second),
          root_cause: "Certificate expires in 3 days (Critical)"
        })

      {:ok, _} = Engine.process_response(monitor, ok_response("success"), %{duration_ms: 100})

      log = Monitoring.list_monitor_logs(monitor, %{}).logs |> List.first()
      assert log.status == :compromised
    end
  end

  describe "open_incident_already_exists?/1" do
    test "returns true for a unique constraint changeset error", %{monitor: monitor} do
      Monitoring.create_incident(%{
        monitor_id: monitor.id,
        type: :downtime,
        started_at: DateTime.utc_now()
      })

      result =
        Monitoring.create_incident(%{
          monitor_id: monitor.id,
          type: :downtime,
          started_at: DateTime.utc_now()
        })

      assert Monitoring.open_incident_already_exists?(result)
    end

    test "returns false for a missing required field validation error" do
      result = Monitoring.create_incident(%{})
      refute Monitoring.open_incident_already_exists?(result)
    end

    test "returns false for a successful create", %{monitor: monitor} do
      result =
        Monitoring.create_incident(%{
          monitor_id: monitor.id,
          type: :downtime,
          started_at: DateTime.utc_now()
        })

      refute Monitoring.open_incident_already_exists?(result)
    end
  end

  defp ok_response(body),
    do: %Req.Response{status: 200, body: body, headers: [{"content-type", "text/plain"}]}

  defp error_response(status, body),
    do: %Req.Response{status: status, body: body, headers: [{"content-type", "text/plain"}]}
end

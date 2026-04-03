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
    {:ok, monitor} = Monitoring.create_monitor(@monitor_attrs)
    %{monitor: monitor}
  end

  describe "when response is 200 OK and matching keywords" do
    setup %{monitor: monitor} do
      {:ok, _} = Engine.process_response(monitor, ok_response("Everything is a success!"), 100)
      :ok
    end

    test "sets health_status to :up", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :up
    end
  end

  describe "when response is HTTP 500" do
    setup %{monitor: monitor} do
      {:ok, _} = Engine.process_response(monitor, error_response(500, "Internal Error"), 100)
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
      {:ok, _} = Engine.process_response(monitor, ok_response("No match here"), 100)
      :ok
    end

    test "sets health_status to :down", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :down
    end

    test "opens a downtime incident", %{monitor: monitor} do
      assert %{type: :downtime} = Monitoring.get_open_incident(monitor.id, :downtime)
    end

    test "sets root_cause to missing keywords message", %{monitor: monitor} do
      assert %{root_cause: "Missing required keywords"} =
               Monitoring.get_open_incident(monitor.id, :downtime)
    end
  end

  describe "when forbidden keyword is found (defacement)" do
    setup %{monitor: monitor} do
      {:ok, _} = Engine.process_response(monitor, ok_response("success but has an error"), 100)
      :ok
    end

    test "sets health_status to :compromised", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :compromised
    end

    test "opens a defacement incident", %{monitor: monitor} do
      assert %{type: :defacement} = Monitoring.get_open_incident(monitor.id, :defacement)
    end

    test "sets root_cause to found forbidden keywords message", %{monitor: monitor} do
      assert %{root_cause: "Found forbidden keywords"} =
               Monitoring.get_open_incident(monitor.id, :defacement)
    end
  end

  describe "when transitioning from down to compromised" do
    setup %{monitor: monitor} do
      {:ok, monitor_down} = Engine.process_response(monitor, error_response(500, ""), 100)
      {:ok, _} = Engine.process_response(monitor_down, ok_response("success error"), 100)
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
      {:ok, monitor_hacked} = Engine.process_response(monitor, ok_response("success error"), 100)
      {:ok, _} = Engine.process_response(monitor_hacked, ok_response("success"), 100)
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
      assert [%{error_message: "connection refused"}] = Monitoring.list_monitor_logs(monitor.id)
    end
  end

  describe "selective evidence storage on failure" do
    setup %{monitor: monitor} do
      {:ok, _} =
        Engine.process_response(
          monitor,
          error_response(500, "<html><body>Internal Error</body></html>"),
          100
        )

      %{log: List.first(Monitoring.list_monitor_logs(monitor.id))}
    end

    test "records failure status", %{log: log} do
      assert log.status == :failure
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
      {:ok, monitor_down} = Engine.process_response(monitor, error_response(500, "Error 1"), 100)
      {:ok, _} = Engine.process_response(monitor_down, error_response(500, "Error 2"), 100)

      logs = Monitoring.list_monitor_logs(monitor.id) |> Enum.sort_by(& &1.inserted_at)
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

  defp ok_response(body),
    do: %Req.Response{status: 200, body: body, headers: [{"content-type", "text/plain"}]}

  defp error_response(status, body),
    do: %Req.Response{status: status, body: body, headers: [{"content-type", "text/plain"}]}
end

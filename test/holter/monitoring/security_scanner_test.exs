defmodule Holter.Monitoring.SecurityScannerTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring
  alias Holter.Monitoring.Logs
  alias Holter.Monitoring.SecurityScanner

  setup do
    monitor =
      monitor_fixture(%{
        url: "https://example.com",
        method: "get",
        interval_seconds: 60,
        timeout_seconds: 30
      })

    Holter.Monitoring.create_monitor_log(%{
      monitor_id: monitor.id,
      status: :up,
      checked_at: DateTime.utc_now() |> DateTime.add(-1, :hour)
    })

    {:ok, monitor} = Holter.Monitoring.recalculate_health_status(monitor)

    %{monitor: monitor}
  end

  describe "when processing SSL with valid future expiry" do
    setup %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second)
      SecurityScanner.process_ssl(monitor, expiry)
      %{expiry: expiry}
    end

    test "updates the monitor ssl_expires_at field", %{monitor: monitor, expiry: expiry} do
      assert Monitoring.get_monitor!(monitor.id).ssl_expires_at == expiry
    end

    test "does not open any incident", %{monitor: monitor} do
      assert is_nil(Monitoring.get_open_incident(monitor.id))
    end
  end

  describe "when certificate is about to expire (Warning - 10 days)" do
    setup %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(10, :day)
      SecurityScanner.process_ssl(monitor, expiry)
      :ok
    end

    test "opens a warning incident", %{monitor: monitor} do
      assert %{type: :ssl_expiry} = Monitoring.get_open_incident(monitor.id)
    end

    test "sets appropriate root cause for warning", %{monitor: monitor} do
      assert %{root_cause: cause} = Monitoring.get_open_incident(monitor.id)
      assert cause =~ "Warning"
    end

    test "downgrades monitor health to :degraded", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :degraded
    end
  end

  describe "when certificate is critically close to expiry (Critical - 5 days)" do
    setup %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(5, :day)
      SecurityScanner.process_ssl(monitor, expiry)
      :ok
    end

    test "opens a critical incident", %{monitor: monitor} do
      assert %{type: :ssl_expiry} = Monitoring.get_open_incident(monitor.id)
    end

    test "sets appropriate root cause for critical", %{monitor: monitor} do
      assert %{root_cause: cause} = Monitoring.get_open_incident(monitor.id)
      assert cause =~ "Critical"
    end

    test "downgrades monitor health to :compromised", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :compromised
    end
  end

  describe "when certificate is expired" do
    setup %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(-1, :day)
      SecurityScanner.process_ssl(monitor, expiry)
      :ok
    end

    test "downgrades monitor health to :compromised", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :compromised
    end
  end

  describe "when transitioning from warning to critical" do
    setup %{monitor: monitor} do
      expiry_warning = DateTime.utc_now() |> DateTime.add(10, :day)
      SecurityScanner.process_ssl(monitor, expiry_warning)

      expiry_critical = DateTime.utc_now() |> DateTime.add(5, :day)
      SecurityScanner.process_ssl(monitor, expiry_critical)
      :ok
    end

    test "maintains the same incident record", %{monitor: monitor} do
      assert %{type: :ssl_expiry} = Monitoring.get_open_incident(monitor.id)
    end

    test "updates the root cause to critical", %{monitor: monitor} do
      assert %{root_cause: cause} = Monitoring.get_open_incident(monitor.id)
      assert cause =~ "Critical"
    end

    test "updates monitor health to :compromised", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :compromised
    end
  end

  describe "when a pending SSL incident is resolved" do
    setup %{monitor: monitor} do
      expiry_bad = DateTime.utc_now() |> DateTime.add(5, :day)
      SecurityScanner.process_ssl(monitor, expiry_bad)

      expiry_good = DateTime.utc_now() |> DateTime.add(20, :day)
      SecurityScanner.process_ssl(monitor, expiry_good)

      {:ok, _} = Holter.Monitoring.recalculate_health_status(monitor)
      :ok
    end

    test "closes the open incident", %{monitor: monitor} do
      assert is_nil(Monitoring.get_open_incident(monitor.id))
    end

    test "restores monitor health to :up", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :up
    end
  end

  describe "handle_ssl_error/2" do
    setup %{monitor: monitor} do
      SecurityScanner.handle_ssl_error(monitor, :nxdomain)
      :ok
    end

    test "creates an incident", %{monitor: monitor} do
      assert %{type: :ssl_expiry} = Monitoring.get_open_incident(monitor.id)
    end

    test "sets health_status to :compromised", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :compromised
    end
  end

  describe "SSL log linkage: process_ssl opens warning incident" do
    setup %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(10, :day)
      SecurityScanner.process_ssl(monitor, expiry)
      %{incident: Monitoring.get_open_incident(monitor.id, :ssl_expiry)}
    end

    test "ssl_expiry incident has at least one linked log immediately", %{incident: incident} do
      assert length(Logs.list_logs_by_incident(incident.id)) >= 1
    end

    test "linked log has status :degraded", %{incident: incident} do
      log = Logs.list_logs_by_incident(incident.id) |> List.first()
      assert log.status == :degraded
    end

    test "linked log incident_id matches the ssl incident", %{incident: incident} do
      log = Logs.list_logs_by_incident(incident.id) |> List.first()
      assert log.incident_id == incident.id
    end
  end

  describe "SSL log linkage: process_ssl opens critical incident" do
    setup %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(5, :day)
      SecurityScanner.process_ssl(monitor, expiry)
      %{incident: Monitoring.get_open_incident(monitor.id, :ssl_expiry)}
    end

    test "linked log has status :compromised", %{incident: incident} do
      log = Logs.list_logs_by_incident(incident.id) |> List.first()
      assert log.status == :compromised
    end
  end

  describe "SSL log linkage: handle_ssl_error" do
    setup %{monitor: monitor} do
      SecurityScanner.handle_ssl_error(monitor, :nxdomain)
      %{incident: Monitoring.get_open_incident(monitor.id, :ssl_expiry)}
    end

    test "ssl error incident has at least one linked log", %{incident: incident} do
      assert length(Logs.list_logs_by_incident(incident.id)) >= 1
    end

    test "ssl error log has status :compromised", %{incident: incident} do
      log = Logs.list_logs_by_incident(incident.id) |> List.first()
      assert log.status == :compromised
    end
  end

  describe "SSL log linkage: warning to critical escalation" do
    setup %{monitor: monitor} do
      expiry_warning = DateTime.utc_now() |> DateTime.add(10, :day)
      SecurityScanner.process_ssl(monitor, expiry_warning)

      expiry_critical = DateTime.utc_now() |> DateTime.add(5, :day)
      SecurityScanner.process_ssl(monitor, expiry_critical)

      %{incident: Monitoring.get_open_incident(monitor.id, :ssl_expiry)}
    end

    test "escalation produces a second log entry", %{incident: incident} do
      assert length(Logs.list_logs_by_incident(incident.id)) >= 2
    end

    test "most recent log has status :compromised after escalation", %{incident: incident} do
      log = Logs.list_logs_by_incident(incident.id) |> List.first()
      assert log.status == :compromised
    end
  end

  describe "SSL log linkage: coexistence with downtime incident" do
    setup %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(10, :day)
      SecurityScanner.process_ssl(monitor, expiry)
      ssl_incident = Monitoring.get_open_incident(monitor.id, :ssl_expiry)

      response = %Req.Response{
        status: 500,
        body: "Error",
        headers: [{"content-type", "text/plain"}]
      }

      Holter.Monitoring.Engine.process_response(monitor, response, %{duration_ms: 50})

      %{ssl_incident: ssl_incident}
    end

    test "ssl incident retains its log when a downtime incident opens later", %{
      ssl_incident: ssl_incident
    } do
      assert length(Logs.list_logs_by_incident(ssl_incident.id)) >= 1
    end
  end
end

defmodule Holter.Monitoring.SnapshotTest do
  use Holter.DataCase, async: true
  alias Holter.Monitoring
  alias Holter.Monitoring.Engine

  @monitor_attrs %{
    url: "https://example.local",
    method: :get,
    interval_seconds: 60,
    timeout_seconds: 30,
    raw_keyword_positive: "success",
    raw_keyword_negative: "error"
  }

  setup do
    monitor = monitor_fixture(@monitor_attrs)
    %{monitor: monitor}
  end

  test "Given a monitor check, when processed, then the log MUST contain a full state snapshot",
       %{
         monitor: monitor
       } do
    response = %Req.Response{
      status: 200,
      body: "Everything is a success",
      headers: [{"content-type", "text/plain"}]
    }

    {:ok, _} = Engine.process_response(monitor, response, 100)

    log = List.first(Monitoring.list_monitor_logs(monitor, %{}))
    assert log.monitor_snapshot
    assert log.monitor_snapshot["url"] == monitor.url
    assert log.monitor_snapshot["method"] == "get"
    assert log.monitor_snapshot["keyword_positive"] == ["success"]
  end

  test "Given a failure check, when an incident is opened, then the incident MUST contain a state snapshot",
       %{monitor: monitor} do
    response = %Req.Response{
      status: 500,
      body: "Internal Error",
      headers: [{"content-type", "text/plain"}]
    }

    {:ok, _} = Engine.process_response(monitor, response, 100)

    incident = Monitoring.get_open_incident(monitor.id, :downtime)
    assert incident.monitor_snapshot
    assert incident.monitor_snapshot["url"] == monitor.url
  end

  test "Given a monitor update, when a new check runs, then new log snapshot MUST reflect the updated state",
       %{monitor: monitor} do
    response_ok = %Req.Response{
      status: 200,
      body: "success",
      headers: [{"content-type", "text/plain"}]
    }

    {:ok, _} = Engine.process_response(monitor, response_ok, 100)
    log1 = List.first(Monitoring.list_monitor_logs(monitor, %{}))
    assert log1.monitor_snapshot["url"] == "https://example.local"

    {:ok, updated_monitor} = Monitoring.update_monitor(monitor, %{url: "https://new-url.local"})

    Process.sleep(1100)
    {:ok, _} = Engine.process_response(updated_monitor, response_ok, 100)

    [log2, _] = Monitoring.list_monitor_logs(monitor, %{})
    assert log2.monitor_snapshot["url"] == "https://new-url.local"

    assert log1.monitor_snapshot["url"] == "https://example.local"
  end

  test "Given an SSL error, when an incident is opened via SecurityScanner, then it MUST contain a snapshot",
       %{monitor: monitor} do
    alias Holter.Monitoring.SecurityScanner

    {:ok, monitor} = Monitoring.update_monitor(monitor, %{url: "https://secure.local"})

    {:ok, _} = SecurityScanner.handle_ssl_error(monitor, :nxdomain)

    incident = Monitoring.get_open_incident(monitor.id, :ssl_expiry)
    assert incident.monitor_snapshot
    assert incident.monitor_snapshot["url"] == "https://secure.local"
  end
end

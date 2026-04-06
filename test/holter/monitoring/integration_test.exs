defmodule Holter.Monitoring.IntegrationTest do
  use Holter.DataCase, async: false
  use Oban.Testing, repo: Holter.Repo

  alias Holter.Monitoring
  alias Holter.Monitoring.Workers.HTTPCheck
  alias Holter.Test.DummyService

  @call_id "check1"

  setup do
    old_client = Application.get_env(:holter, :monitor_client)
    old_monitoring = Application.get_env(:holter, :monitoring, [])

    Application.put_env(:holter, :monitor_client, Holter.Monitoring.MonitorClient.HTTP)

    Application.put_env(
      :holter,
      :monitoring,
      Keyword.put(old_monitoring, :trusted_hosts, ["localhost", "127.0.0.1"])
    )

    on_exit(fn ->
      Application.put_env(:holter, :monitor_client, old_client)
      Application.put_env(:holter, :monitoring, old_monitoring)
    end)

    DummyService.reset()
    port = Application.get_env(:holter, :dummy_port)

    monitor =
      monitor_fixture(%{
        url: "http://localhost:#{port}/probe/#{@call_id}",
        method: "get",
        interval_seconds: 60,
        logical_state: :active,
        health_status: :up,
        raw_keyword_positive: "OK",
        raw_keyword_negative: "FAIL"
      })

    %{monitor: monitor, job_args: %{"id" => monitor.id}}
  end

  describe "when the first check fails (500)" do
    setup %{job_args: job_args} do
      DummyService.enqueue(@call_id, status: 500, body: "Internal Server Error")
      :ok = perform_job(HTTPCheck, job_args)
      :ok
    end

    test "sets health_status to :down", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :down
    end

    test "opens a downtime incident", %{monitor: monitor} do
      assert Monitoring.get_open_incident(monitor.id, :downtime)
    end

    test "sets root_cause from HTTP status code", %{monitor: monitor} do
      assert %{root_cause: "HTTP Error: 500"} =
               Monitoring.get_open_incident(monitor.id, :downtime)
    end
  end

  describe "when the monitor checks down twice" do
    setup %{monitor: monitor, job_args: job_args} do
      DummyService.enqueue(@call_id, status: 500, body: "Down")
      :ok = perform_job(HTTPCheck, job_args)
      first_incident = Monitoring.get_open_incident(monitor.id, :downtime)

      DummyService.enqueue(@call_id, status: 500, body: "Still down")
      :ok = perform_job(HTTPCheck, job_args)

      %{first_incident: first_incident}
    end

    test "does not open a second incident", %{monitor: monitor, first_incident: first_incident} do
      assert Monitoring.get_open_incident(monitor.id, :downtime).id == first_incident.id
    end
  end

  describe "when the monitor recovers after downtime" do
    setup %{monitor: monitor, job_args: job_args} do
      DummyService.enqueue(@call_id, status: 500, body: "Down")
      :ok = perform_job(HTTPCheck, job_args)
      incident = Monitoring.get_open_incident(monitor.id, :downtime)

      DummyService.enqueue(@call_id, status: 200, body: "Everything is OK")
      :ok = perform_job(HTTPCheck, job_args)

      %{incident: incident}
    end

    test "sets health_status to :up", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :up
    end

    test "closes the open incident", %{monitor: monitor} do
      assert is_nil(Monitoring.get_open_incident(monitor.id, :downtime))
    end

    test "stamps resolved_at on the incident", %{incident: incident} do
      assert Holter.Repo.get!(Holter.Monitoring.Incident, incident.id).resolved_at
    end

    test "records duration_seconds on the incident", %{incident: incident} do
      assert Holter.Repo.get!(Holter.Monitoring.Incident, incident.id).duration_seconds >= 0
    end
  end

  describe "when monitor is defaced (forbidden keyword found)" do
    setup %{job_args: job_args} do
      DummyService.enqueue(@call_id, status: 200, body: "OK but has FAIL")
      :ok = perform_job(HTTPCheck, job_args)
      :ok
    end

    test "sets health_status to :compromised", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :compromised
    end

    test "opens a defacement incident", %{monitor: monitor} do
      assert %{type: :defacement} = Monitoring.get_open_incident(monitor.id, :defacement)
    end
  end
end

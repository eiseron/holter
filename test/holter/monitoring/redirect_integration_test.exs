defmodule Holter.Monitoring.RedirectIntegrationTest do
  use Holter.DataCase, async: false
  use Oban.Testing, repo: Holter.Repo

  alias Holter.Monitoring
  alias Holter.Monitoring.Workers.HTTPCheck
  alias Holter.Test.DummyService

  @call_id "redirect_test"

  setup do
    old_client = Application.get_env(:holter, :monitor_client)
    old_network = Application.get_env(:holter, :network, [])

    Application.put_env(:holter, :monitor_client, Holter.Monitoring.MonitorClient.HTTP)

    Application.put_env(
      :holter,
      :network,
      Keyword.put(old_network, :trusted_hosts, ["localhost", "127.0.0.1"])
    )

    on_exit(fn ->
      Application.put_env(:holter, :monitor_client, old_client)
      Application.put_env(:holter, :network, old_network)
    end)

    DummyService.reset()
    port = Application.get_env(:holter, :dummy_port)

    monitor =
      monitor_fixture(%{
        url: "http://localhost:#{port}/probe/#{@call_id}",
        method: "get",
        follow_redirects: true,
        max_redirects: 3
      })

    %{monitor: monitor, job_args: %{"id" => monitor.id}, port: port}
  end

  describe "following redirects" do
    test "follows a 301 to a final 200 OK", %{monitor: monitor, job_args: job_args, port: port} do
      DummyService.enqueue(@call_id,
        status: 301,
        headers: [{"location", "http://localhost:#{port}/probe/final"}]
      )

      DummyService.enqueue("final", status: 200, body: "FINAL CONTENT")

      :ok = perform_job(HTTPCheck, job_args)

      assert Monitoring.get_monitor!(monitor.id).health_status == :up

      assert [%{redirect_count: 1, last_redirect_url: last_url}] =
               Monitoring.list_monitor_logs(monitor, %{}).logs

      assert last_url =~ "/probe/final"
    end

    test "fails if max_redirects is reached", %{monitor: monitor, job_args: job_args, port: port} do
      DummyService.enqueue(@call_id,
        status: 302,
        headers: [{"location", "http://localhost:#{port}/probe/r1"}]
      )

      DummyService.enqueue("r1",
        status: 302,
        headers: [{"location", "http://localhost:#{port}/probe/r2"}]
      )

      DummyService.enqueue("r2",
        status: 302,
        headers: [{"location", "http://localhost:#{port}/probe/r3"}]
      )

      DummyService.enqueue("r3", status: 200, body: "TOO LATE")

      {:ok, monitor} = Monitoring.update_monitor(monitor, %{max_redirects: 2})

      :ok = perform_job(HTTPCheck, job_args)

      assert Monitoring.get_monitor!(monitor.id).health_status == :down

      assert [%{redirect_count: 2, status_code: 302}] =
               Monitoring.list_monitor_logs(monitor, %{}).logs
    end

    test "handles relative redirects correctly", %{monitor: monitor, job_args: job_args} do
      DummyService.enqueue(@call_id, status: 307, headers: [{"location", "/probe/relative"}])
      DummyService.enqueue("relative", status: 200, body: "RELATIVE OK")

      :ok = perform_job(HTTPCheck, job_args)

      assert Monitoring.get_monitor!(monitor.id).health_status == :up

      assert [%{redirect_count: 1, last_redirect_url: last_url}] =
               Monitoring.list_monitor_logs(monitor, %{}).logs

      assert last_url =~ "/probe/relative"
    end
  end

  describe "redirect_list for a single 301→200 chain" do
    setup %{monitor: monitor, job_args: job_args, port: port} do
      DummyService.enqueue(@call_id,
        status: 301,
        headers: [{"location", "http://localhost:#{port}/probe/final"}]
      )

      DummyService.enqueue("final", status: 200, body: "FINAL CONTENT")

      :ok = perform_job(HTTPCheck, job_args)

      [%{redirect_list: redirect_list}] = Monitoring.list_monitor_logs(monitor, %{}).logs
      [hop1, hop2] = redirect_list
      %{redirect_list: redirect_list, hop1: hop1, hop2: hop2}
    end

    test "list has two entries", %{redirect_list: redirect_list} do
      assert length(redirect_list) == 2
    end

    test "first hop status_code is 301", %{hop1: hop1} do
      assert hop1["status_code"] == 301
    end

    test "last hop status_code is 200", %{hop2: hop2} do
      assert hop2["status_code"] == 200
    end

    test "all hops have binary ip", %{redirect_list: redirect_list} do
      assert Enum.all?(redirect_list, &is_binary(&1["ip"]))
    end
  end
end

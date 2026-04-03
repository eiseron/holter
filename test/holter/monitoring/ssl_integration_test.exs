defmodule Holter.Monitoring.SSLIntegrationTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo
  import Mox

  alias Holter.Monitoring
  alias Holter.Monitoring.Workers.{MonitorDispatcher, SSLCheck}

  setup :verify_on_exit!

  setup do
    {:ok, monitor} =
      Monitoring.create_monitor(%{
        url: "https://secure-service.local",
        method: :get,
        interval_seconds: 60,
        logical_state: :active
      })

    %{monitor: monitor}
  end

  describe "when dispatching SSL checks" do
    setup do
      :ok = MonitorDispatcher.perform(%Oban.Job{})
      :ok
    end

    test "enqueues an SSLCheck job", %{monitor: monitor} do
      assert_enqueued(worker: SSLCheck, args: %{id: monitor.id})
    end
  end

  describe "when a monitor has a valid SSL certificate" do
    setup %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second)
      expect(Holter.Monitoring.MonitorClientMock, :get_ssl_expiration, fn _ -> {:ok, expiry} end)

      :ok = perform_job(SSLCheck, %{"id" => monitor.id})
      %{expiry: expiry}
    end

    test "updates the monitor ssl_expires_at field", %{monitor: monitor, expiry: expiry} do
      assert Monitoring.get_monitor!(monitor.id).ssl_expires_at == expiry
    end

    test "does not open any SSL incident", %{monitor: monitor} do
      assert is_nil(Monitoring.get_open_incident(monitor.id, :ssl_expiry))
    end

    test "sets health_status to :up", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :up
    end
  end

  describe "when SSL handshake fails" do
    setup %{monitor: monitor} do
      expect(Holter.Monitoring.MonitorClientMock, :get_ssl_expiration, fn _ ->
        {:error, :connection_refused}
      end)

      import ExUnit.CaptureLog
      capture_log(fn -> :ok = perform_job(SSLCheck, %{"id" => monitor.id}) end)
      :ok
    end

    test "creates an incident of type ssl_expiry", %{monitor: monitor} do
      assert %{type: :ssl_expiry} = Monitoring.get_open_incident(monitor.id, :ssl_expiry)
    end

    test "sets the root cause to the connection error", %{monitor: monitor} do
      assert %{root_cause: cause} = Monitoring.get_open_incident(monitor.id, :ssl_expiry)
      assert cause =~ "connection_refused"
    end

    test "sets health_status to :compromised", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :compromised
    end
  end

  describe "when certificate is critically close to expiry" do
    setup %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(5, :day) |> DateTime.truncate(:second)
      expect(Holter.Monitoring.MonitorClientMock, :get_ssl_expiration, fn _ -> {:ok, expiry} end)

      :ok = perform_job(SSLCheck, %{"id" => monitor.id})
      :ok
    end

    test "opens an SSL expiry incident", %{monitor: monitor} do
      assert %{type: :ssl_expiry} = Monitoring.get_open_incident(monitor.id, :ssl_expiry)
    end

    test "sets the root cause to critical", %{monitor: monitor} do
      assert %{root_cause: cause} = Monitoring.get_open_incident(monitor.id, :ssl_expiry)
      assert cause =~ "Critical"
    end

    test "sets health_status to :compromised", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :compromised
    end
  end

  describe "when a certificate is fixed after a failure" do
    setup %{monitor: monitor} do
      expect(Holter.Monitoring.MonitorClientMock, :get_ssl_expiration, fn _ ->
        {:error, :expired}
      end)

      import ExUnit.CaptureLog
      capture_log(fn -> :ok = perform_job(SSLCheck, %{"id" => monitor.id}) end)

      expiry = DateTime.utc_now() |> DateTime.add(60, :day) |> DateTime.truncate(:second)
      expect(Holter.Monitoring.MonitorClientMock, :get_ssl_expiration, fn _ -> {:ok, expiry} end)

      :ok = perform_job(SSLCheck, %{"id" => monitor.id})
      :ok
    end

    test "resolves the existing SSL incident", %{monitor: monitor} do
      assert is_nil(Monitoring.get_open_incident(monitor.id, :ssl_expiry))
    end

    test "restores health_status to :up", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :up
    end
  end
end

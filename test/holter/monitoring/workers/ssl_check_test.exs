defmodule Holter.Monitoring.Workers.SSLCheckTest do
  use Holter.DataCase, async: true
  import Mox

  alias Holter.Monitoring
  alias Holter.Monitoring.Workers.SSLCheck

  setup :verify_on_exit!

  setup do
    {:ok, monitor} =
      Monitoring.create_monitor(%{
        url: "https://secure.example.com",
        method: :GET,
        interval_seconds: 60,
        timeout_seconds: 30
      })

    %{monitor: monitor}
  end

  describe "when SSL check is successful" do
    setup %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second)

      expect(Holter.Monitoring.MonitorClientMock, :get_ssl_expiration, fn _url ->
        {:ok, expiry}
      end)

      :ok = perform_job(SSLCheck, %{"id" => monitor.id})
      %{expiry: expiry}
    end

    test "updates the monitor ssl_expires_at field", %{monitor: monitor, expiry: expiry} do
      assert Monitoring.get_monitor!(monitor.id).ssl_expires_at == expiry
    end
  end

  describe "when SSL check fails" do
    setup %{monitor: monitor} do
      expect(Holter.Monitoring.MonitorClientMock, :get_ssl_expiration, fn _url ->
        {:error, :connection_failed}
      end)

      import ExUnit.CaptureLog

      capture_log(fn ->
        :ok = perform_job(SSLCheck, %{"id" => monitor.id})
      end)

      :ok
    end

    test "does not update the monitor ssl_expires_at field", %{monitor: monitor} do
      assert is_nil(Monitoring.get_monitor!(monitor.id).ssl_expires_at)
    end
  end

  describe "when monitor URL is not https" do
    setup do
      {:ok, plain_monitor} =
        Monitoring.create_monitor(%{
          url: "http://plain.example.com",
          method: :GET,
          interval_seconds: 60,
          timeout_seconds: 30
        })

      # No expectation for get_ssl_expiration means it shouldn't be called
      :ok = perform_job(SSLCheck, %{"id" => plain_monitor.id})
      %{plain_monitor: plain_monitor}
    end

    test "skips the SSL check logic", %{plain_monitor: plain_monitor} do
      assert is_nil(Monitoring.get_monitor!(plain_monitor.id).ssl_expires_at)
    end
  end
end

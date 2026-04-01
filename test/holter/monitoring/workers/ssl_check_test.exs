defmodule Holter.Monitoring.Workers.SSLCheckTest do
  use Holter.DataCase, async: true
  import Mox

  alias Holter.Monitoring
  alias Holter.Monitoring.Workers.SSLCheck

  setup :verify_on_exit!

  describe "perform/1" do
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

    test "successfully processes SSL expiration", %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second)

      expect(
        Holter.Monitoring.MonitorClientMock,
        :get_ssl_expiration,
        fn "https://secure.example.com" ->
          {:ok, expiry}
        end
      )

      assert :ok = SSLCheck.perform(%Oban.Job{args: %{"id" => monitor.id}})

      updated = Monitoring.get_monitor!(monitor.id)
      assert updated.ssl_expires_at == expiry
    end

    test "handles SSL check failure gracefully", %{monitor: monitor} do
      expect(Holter.Monitoring.MonitorClientMock, :get_ssl_expiration, fn _ ->
        {:error, :connection_failed}
      end)

      import ExUnit.CaptureLog

      capture_log(fn ->
        assert :ok = SSLCheck.perform(%Oban.Job{args: %{"id" => monitor.id}})
      end)

      # Should not update expiry
      updated = Monitoring.get_monitor!(monitor.id)
      assert is_nil(updated.ssl_expires_at)
    end

    test "skips non-https URLs", %{monitor: _monitor} do
      {:ok, plain_monitor} =
        Monitoring.create_monitor(%{
          url: "http://plain.example.com",
          method: :GET,
          interval_seconds: 60,
          timeout_seconds: 30
        })

      # No expectation for get_ssl_expiration means it shouldn't be called
      assert :ok = SSLCheck.perform(%Oban.Job{args: %{"id" => plain_monitor.id}})
    end
  end
end

defmodule Holter.Monitoring.SecurityScannerTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring
  alias Holter.Monitoring.SecurityScanner

  setup do
    {:ok, monitor} =
      Monitoring.create_monitor(%{
        url: "https://example.com",
        method: :GET,
        interval_seconds: 60,
        timeout_seconds: 30
      })

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
  end

  describe "when a pending SSL incident is resolved" do
    setup %{monitor: monitor} do
      expiry_bad = DateTime.utc_now() |> DateTime.add(5, :day)
      SecurityScanner.process_ssl(monitor, expiry_bad)

      expiry_good = DateTime.utc_now() |> DateTime.add(20, :day)
      SecurityScanner.process_ssl(monitor, expiry_good)
      :ok
    end

    test "closes the open incident", %{monitor: monitor} do
      assert is_nil(Monitoring.get_open_incident(monitor.id))
    end
  end
end

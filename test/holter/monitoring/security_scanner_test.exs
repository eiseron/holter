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

  describe "process_ssl/2" do
    test "updates monitor with expiration date", %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(30, :day)
      SecurityScanner.process_ssl(monitor, expiry)

      updated = Monitoring.get_monitor!(monitor.id)
      assert updated.ssl_expires_at == expiry |> DateTime.truncate(:second)
    end

    test "creates warning incident when expiry is < 15 days", %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(10, :day)
      SecurityScanner.process_ssl(monitor, expiry)

      incident = Monitoring.get_open_incident(monitor.id)
      assert incident.type == :ssl_expiry
      assert incident.root_cause =~ "Warning"
    end

    test "creates critical incident when expiry is < 7 days", %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(5, :day)
      SecurityScanner.process_ssl(monitor, expiry)

      incident = Monitoring.get_open_incident(monitor.id)
      assert incident.type == :ssl_expiry
      assert incident.root_cause =~ "Critical"
    end

    test "updates root cause of an existing open incident", %{monitor: monitor} do
      # Create initial warning
      expiry_warning = DateTime.utc_now() |> DateTime.add(10, :day)
      SecurityScanner.process_ssl(monitor, expiry_warning)

      incident = Monitoring.get_open_incident(monitor.id)
      assert incident.root_cause =~ "Warning"

      # Transition to critical
      expiry_critical = DateTime.utc_now() |> DateTime.add(5, :day)
      SecurityScanner.process_ssl(monitor, expiry_critical)

      updated_incident = Monitoring.get_open_incident(monitor.id)
      assert updated_incident.id == incident.id
      assert updated_incident.root_cause =~ "Critical"
    end

    test "resolves incident when expiry is > 15 days", %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(5, :day)
      SecurityScanner.process_ssl(monitor, expiry)
      assert Monitoring.get_open_incident(monitor.id)

      safe_expiry = DateTime.utc_now() |> DateTime.add(20, :day)
      SecurityScanner.process_ssl(monitor, safe_expiry)

      assert is_nil(Monitoring.get_open_incident(monitor.id))
    end
  end
end

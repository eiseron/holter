defmodule Holter.Monitoring.Workers.DomainCheckTest do
  use Holter.DataCase, async: true
  use Oban.Testing, repo: Holter.Repo
  import Mox

  alias Holter.Monitoring
  alias Holter.Monitoring.Workers.DomainCheck

  setup :verify_on_exit!

  setup do
    monitor =
      monitor_fixture(%{
        url: "https://example.com",
        method: "get",
        interval_seconds: 60,
        timeout_seconds: 30
      })

    %{monitor: monitor}
  end

  describe "when domain check is successful" do
    setup %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(60, :day) |> DateTime.truncate(:second)

      expect(Holter.Monitoring.MonitorClientMock, :get_domain_expiration, fn _host ->
        {:ok, expiry}
      end)

      :ok = perform_job(DomainCheck, %{"id" => monitor.id})
      %{expiry: expiry}
    end

    test "updates the monitor domain_expires_at field", %{monitor: monitor, expiry: expiry} do
      assert Monitoring.get_monitor!(monitor.id).domain_expires_at == expiry
    end

    test "stamps last_domain_check_at on success", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).last_domain_check_at != nil
    end
  end

  describe "when domain check fails" do
    setup %{monitor: monitor} do
      expect(Holter.Monitoring.MonitorClientMock, :get_domain_expiration, fn _host ->
        {:error, :rdap_unavailable}
      end)

      import ExUnit.CaptureLog

      capture_log(fn ->
        :ok = perform_job(DomainCheck, %{"id" => monitor.id})
      end)

      :ok
    end

    test "does not update domain_expires_at", %{monitor: monitor} do
      assert is_nil(Monitoring.get_monitor!(monitor.id).domain_expires_at)
    end

    test "still stamps last_domain_check_at to honour cadence gating", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).last_domain_check_at != nil
    end

    test "does not open a :domain_expiry incident on transient lookup error", %{monitor: monitor} do
      assert is_nil(Monitoring.get_open_incident(monitor.id, :domain_expiry))
    end
  end

  describe "when domain_check_ignore is true" do
    setup %{monitor: monitor} do
      Monitoring.create_incident(%{
        monitor_id: monitor.id,
        type: :domain_expiry,
        started_at: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
      })

      {:ok, monitor} = Monitoring.update_monitor(monitor, %{domain_check_ignore: true})

      :ok = perform_job(DomainCheck, %{"id" => monitor.id})
      %{monitor: monitor}
    end

    test "resolves any open :domain_expiry incident", %{monitor: monitor} do
      assert is_nil(Monitoring.get_open_incident(monitor.id, :domain_expiry))
    end

    test "does not perform the RDAP lookup", %{monitor: monitor} do
      assert is_nil(Monitoring.get_monitor!(monitor.id).domain_expires_at)
    end
  end

  describe "expiry classification" do
    test "opens a :domain_expiry incident when expiry is within 7 days", %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(3, :day) |> DateTime.truncate(:second)

      expect(Holter.Monitoring.MonitorClientMock, :get_domain_expiration, fn _ ->
        {:ok, expiry}
      end)

      :ok = perform_job(DomainCheck, %{"id" => monitor.id})

      assert Monitoring.get_open_incident(monitor.id, :domain_expiry) != nil
    end

    test "opens a :domain_expiry incident when expiry is within 30 days", %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(20, :day) |> DateTime.truncate(:second)

      expect(Holter.Monitoring.MonitorClientMock, :get_domain_expiration, fn _ ->
        {:ok, expiry}
      end)

      :ok = perform_job(DomainCheck, %{"id" => monitor.id})

      assert Monitoring.get_open_incident(monitor.id, :domain_expiry) != nil
    end

    test "does not open an incident when expiry is far away", %{monitor: monitor} do
      expiry = DateTime.utc_now() |> DateTime.add(180, :day) |> DateTime.truncate(:second)

      expect(Holter.Monitoring.MonitorClientMock, :get_domain_expiration, fn _ ->
        {:ok, expiry}
      end)

      :ok = perform_job(DomainCheck, %{"id" => monitor.id})

      assert is_nil(Monitoring.get_open_incident(monitor.id, :domain_expiry))
    end

    test "resolves an open incident when expiry moves outside the warning window", %{
      monitor: monitor
    } do
      Monitoring.create_incident(%{
        monitor_id: monitor.id,
        type: :domain_expiry,
        started_at: DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
      })

      expiry = DateTime.utc_now() |> DateTime.add(180, :day) |> DateTime.truncate(:second)

      expect(Holter.Monitoring.MonitorClientMock, :get_domain_expiration, fn _ ->
        {:ok, expiry}
      end)

      :ok = perform_job(DomainCheck, %{"id" => monitor.id})

      assert is_nil(Monitoring.get_open_incident(monitor.id, :domain_expiry))
    end
  end
end

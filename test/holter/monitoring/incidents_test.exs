defmodule Holter.Monitoring.IncidentsTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring.Incidents

  setup do
    monitor = monitor_fixture()
    %{monitor: monitor}
  end

  defp incident_attrs(monitor_id, overrides \\ %{}) do
    Map.merge(
      %{
        monitor_id: monitor_id,
        type: :downtime,
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      },
      overrides
    )
  end

  describe "create_incident/1" do
    test "creates an incident with given attrs", %{monitor: monitor} do
      {:ok, incident} = Incidents.create_incident(incident_attrs(monitor.id))
      assert incident.monitor_id == monitor.id
      assert incident.type == :downtime
      assert is_nil(incident.resolved_at)
    end

    test "returns error on invalid attrs" do
      assert {:error, %Ecto.Changeset{}} = Incidents.create_incident(%{})
    end
  end

  describe "list_incidents/1" do
    test "returns all incidents for the monitor ordered by started_at desc", %{monitor: monitor} do
      t1 = ~U[2026-01-01 00:00:00Z]
      t2 = ~U[2026-01-02 00:00:00Z]

      {:ok, i1} =
        Incidents.create_incident(incident_attrs(monitor.id, %{started_at: t1, type: :downtime}))

      Incidents.resolve_incident(i1, ~U[2026-01-01 01:00:00Z])

      {:ok, _} =
        Incidents.create_incident(incident_attrs(monitor.id, %{started_at: t2, type: :downtime}))

      [first | _] = Incidents.list_incidents(monitor.id)
      assert DateTime.compare(first.started_at, t2) == :eq
    end

    test "returns empty list for monitor with no incidents", %{monitor: monitor} do
      assert Incidents.list_incidents(monitor.id) == []
    end

    test "does not return incidents from other monitors", %{monitor: monitor} do
      other = monitor_fixture()
      Incidents.create_incident(incident_attrs(other.id))

      assert Incidents.list_incidents(monitor.id) == []
    end
  end

  describe "get_open_incident/1" do
    test "returns the open incident for the monitor", %{monitor: monitor} do
      {:ok, incident} = Incidents.create_incident(incident_attrs(monitor.id))

      found = Incidents.get_open_incident(monitor.id)
      assert found.id == incident.id
    end

    test "returns nil when no open incident exists", %{monitor: monitor} do
      assert Incidents.get_open_incident(monitor.id) == nil
    end

    test "returns nil when the incident is resolved", %{monitor: monitor} do
      {:ok, incident} = Incidents.create_incident(incident_attrs(monitor.id))
      Incidents.resolve_incident(incident, DateTime.utc_now() |> DateTime.truncate(:second))

      assert Incidents.get_open_incident(monitor.id) == nil
    end
  end

  describe "get_open_incident/2 (with type)" do
    test "returns open incident of the given type", %{monitor: monitor} do
      {:ok, incident} =
        Incidents.create_incident(incident_attrs(monitor.id, %{type: :ssl_expiry}))

      found = Incidents.get_open_incident(monitor.id, :ssl_expiry)
      assert found.id == incident.id
    end

    test "returns nil when no open incident of that type exists", %{monitor: monitor} do
      Incidents.create_incident(incident_attrs(monitor.id, %{type: :downtime}))

      assert Incidents.get_open_incident(monitor.id, :ssl_expiry) == nil
    end
  end

  describe "list_open_incidents/1" do
    test "returns all open incidents for the monitor", %{monitor: monitor} do
      Incidents.create_incident(incident_attrs(monitor.id, %{type: :downtime}))
      Incidents.create_incident(incident_attrs(monitor.id, %{type: :ssl_expiry}))

      open = Incidents.list_open_incidents(monitor.id)
      assert length(open) == 2
    end

    test "excludes resolved incidents", %{monitor: monitor} do
      {:ok, incident} = Incidents.create_incident(incident_attrs(monitor.id))
      Incidents.resolve_incident(incident, DateTime.utc_now() |> DateTime.truncate(:second))

      assert Incidents.list_open_incidents(monitor.id) == []
    end
  end

  describe "update_incident/2" do
    test "updates incident fields", %{monitor: monitor} do
      {:ok, incident} = Incidents.create_incident(incident_attrs(monitor.id))
      {:ok, updated} = Incidents.update_incident(incident, %{type: :defacement})
      assert updated.type == :defacement
    end
  end

  describe "resolve_incident/2" do
    test "sets resolved_at on the incident", %{monitor: monitor} do
      {:ok, incident} = Incidents.create_incident(incident_attrs(monitor.id))
      resolved_at = DateTime.add(incident.started_at, 300, :second)

      {:ok, resolved} = Incidents.resolve_incident(incident, resolved_at)
      assert DateTime.compare(resolved.resolved_at, resolved_at) == :eq
    end

    test "calculates duration_seconds correctly", %{monitor: monitor} do
      started_at = ~U[2026-01-01 00:00:00Z]

      {:ok, incident} =
        Incidents.create_incident(incident_attrs(monitor.id, %{started_at: started_at}))

      resolved_at = ~U[2026-01-01 00:05:00Z]

      {:ok, resolved} = Incidents.resolve_incident(incident, resolved_at)
      assert resolved.duration_seconds == 300
    end

    test "incident is no longer returned by get_open_incident after resolution", %{
      monitor: monitor
    } do
      {:ok, incident} = Incidents.create_incident(incident_attrs(monitor.id))
      Incidents.resolve_incident(incident, DateTime.utc_now() |> DateTime.truncate(:second))

      assert Incidents.get_open_incident(monitor.id) == nil
    end
  end
end

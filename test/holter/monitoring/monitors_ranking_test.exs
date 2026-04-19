defmodule Holter.Monitoring.MonitorsRankingTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring

  setup do
    workspace = workspace_fixture()
    %{workspace: workspace}
  end

  defp incident_attrs(monitor_id, overrides) do
    Map.merge(
      %{
        monitor_id: monitor_id,
        type: :downtime,
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      },
      overrides
    )
  end

  describe "list_monitors_with_sparklines/2 open_incidents_count" do
    test "sets open_incidents_count to 2 for a monitor with 2 open incidents",
         %{workspace: workspace} do
      monitor = monitor_fixture(%{workspace_id: workspace.id})
      Monitoring.create_incident(incident_attrs(monitor.id, %{type: :downtime}))
      Monitoring.create_incident(incident_attrs(monitor.id, %{type: :ssl_expiry}))

      [result] = Monitoring.list_monitors_with_sparklines(workspace.id)
      assert result.open_incidents_count == 2
    end

    test "sets open_incidents_count to 0 for a monitor with no open incidents",
         %{workspace: workspace} do
      monitor_fixture(%{workspace_id: workspace.id})

      [result] = Monitoring.list_monitors_with_sparklines(workspace.id)
      assert result.open_incidents_count == 0
    end

    test "sets open_incidents_count to 0 for a monitor where all incidents are resolved",
         %{workspace: workspace} do
      monitor = monitor_fixture(%{workspace_id: workspace.id})
      {:ok, incident} = Monitoring.create_incident(incident_attrs(monitor.id, %{type: :downtime}))
      Monitoring.resolve_incident(incident, DateTime.utc_now() |> DateTime.truncate(:second))

      [result] = Monitoring.list_monitors_with_sparklines(workspace.id)
      assert result.open_incidents_count == 0
    end
  end

  describe "list_monitors_by_workspace/1 tactical ranking by open incident count" do
    test "monitor with 2 open incidents ranks above monitor with 1 open incident at the same health_status",
         %{workspace: workspace} do
      m1 = monitor_fixture(%{workspace_id: workspace.id, health_status: :down})
      m2 = monitor_fixture(%{workspace_id: workspace.id, health_status: :down})

      Monitoring.create_incident(incident_attrs(m1.id, %{type: :downtime}))
      Monitoring.create_incident(incident_attrs(m1.id, %{type: :ssl_expiry}))
      Monitoring.create_incident(incident_attrs(m2.id, %{type: :downtime}))

      [first | _] = Monitoring.list_monitors_by_workspace(workspace.id)
      assert first.id == m1.id
    end

    test "monitor with no open incidents ranks below monitor with 1 open incident at the same health_status",
         %{workspace: workspace} do
      m_with = monitor_fixture(%{workspace_id: workspace.id, health_status: :up})
      m_without = monitor_fixture(%{workspace_id: workspace.id, health_status: :up})

      Monitoring.create_incident(incident_attrs(m_with.id, %{type: :ssl_expiry}))

      monitors = Monitoring.list_monitors_by_workspace(workspace.id)
      ids = Enum.map(monitors, & &1.id)

      assert Enum.find_index(ids, &(&1 == m_with.id)) <
               Enum.find_index(ids, &(&1 == m_without.id))
    end

    test "resolved incidents do not affect ranking", %{workspace: workspace} do
      m_resolved = monitor_fixture(%{workspace_id: workspace.id, health_status: :up})
      m_open = monitor_fixture(%{workspace_id: workspace.id, health_status: :up})

      {:ok, incident} =
        Monitoring.create_incident(incident_attrs(m_resolved.id, %{type: :ssl_expiry}))

      Monitoring.resolve_incident(incident, DateTime.utc_now() |> DateTime.truncate(:second))
      Monitoring.create_incident(incident_attrs(m_open.id, %{type: :downtime}))

      monitors = Monitoring.list_monitors_by_workspace(workspace.id)
      ids = Enum.map(monitors, & &1.id)

      assert Enum.find_index(ids, &(&1 == m_open.id)) <
               Enum.find_index(ids, &(&1 == m_resolved.id))
    end
  end
end

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

  describe "get_incident!/1" do
    test "returns the incident when it exists", %{monitor: monitor} do
      {:ok, incident} = Incidents.create_incident(incident_attrs(monitor.id))
      found = Incidents.get_incident!(incident.id)
      assert found.id == incident.id
    end

    test "raises when incident does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Incidents.get_incident!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_incident/1" do
    test "returns {:ok, incident} when the incident exists", %{monitor: monitor} do
      {:ok, incident} = Incidents.create_incident(incident_attrs(monitor.id))
      assert {:ok, found} = Incidents.get_incident(incident.id)
      assert found.id == incident.id
    end

    test "returns {:error, :not_found} for an unknown id" do
      assert {:error, :not_found} = Incidents.get_incident(Ecto.UUID.generate())
    end
  end

  describe "list_incidents_filtered/1" do
    test "returns only incidents belonging to the given monitor", %{monitor: monitor} do
      other = monitor_fixture()
      {:ok, _} = Incidents.create_incident(incident_attrs(other.id))
      {:ok, own} = Incidents.create_incident(incident_attrs(monitor.id))
      %{data: [result]} = Incidents.list_incidents_filtered(%{monitor_id: monitor.id})
      assert result.id == own.id
    end

    test "filtering by type :downtime excludes ssl_expiry incidents", %{monitor: monitor} do
      {:ok, _ssl} =
        Incidents.create_incident(incident_attrs(monitor.id, %{type: :ssl_expiry}))

      {:ok, down} = Incidents.create_incident(incident_attrs(monitor.id, %{type: :downtime}))

      %{data: results} =
        Incidents.list_incidents_filtered(%{monitor_id: monitor.id, type: :downtime})

      assert length(results) == 1
      assert hd(results).id == down.id
    end

    test "filtering by state :open excludes resolved incidents", %{monitor: monitor} do
      {:ok, resolved} = Incidents.create_incident(incident_attrs(monitor.id))
      Incidents.resolve_incident(resolved, DateTime.utc_now() |> DateTime.truncate(:second))
      {:ok, open} = Incidents.create_incident(incident_attrs(monitor.id))

      %{data: results} =
        Incidents.list_incidents_filtered(%{monitor_id: monitor.id, state: :open})

      assert length(results) == 1
      assert hd(results).id == open.id
    end

    test "filtering by state :resolved excludes open incidents", %{monitor: monitor} do
      {:ok, to_resolve} = Incidents.create_incident(incident_attrs(monitor.id))
      Incidents.resolve_incident(to_resolve, DateTime.utc_now() |> DateTime.truncate(:second))
      {:ok, _open} = Incidents.create_incident(incident_attrs(monitor.id))

      %{data: results} =
        Incidents.list_incidents_filtered(%{monitor_id: monitor.id, state: :resolved})

      assert length(results) == 1
      assert hd(results).id == to_resolve.id
    end

    test "page 2 of size 1 returns the second most recent incident", %{monitor: monitor} do
      t1 = ~U[2026-01-01 00:00:00Z]
      t2 = ~U[2026-01-02 00:00:00Z]
      {:ok, i1} = Incidents.create_incident(incident_attrs(monitor.id, %{started_at: t1}))

      {:ok, _i2} =
        Incidents.create_incident(
          incident_attrs(monitor.id, %{started_at: t2, type: :ssl_expiry})
        )

      %{data: [result]} =
        Incidents.list_incidents_filtered(%{monitor_id: monitor.id, page: 2, page_size: 1})

      assert result.id == i1.id
    end

    test "filtering by date_from excludes incidents before that date", %{monitor: monitor} do
      old = ~U[2026-01-01 12:00:00Z]
      new = ~U[2026-02-01 12:00:00Z]
      {:ok, _} = Incidents.create_incident(incident_attrs(monitor.id, %{started_at: old}))

      {:ok, recent} =
        Incidents.create_incident(
          incident_attrs(monitor.id, %{started_at: new, type: :ssl_expiry})
        )

      %{data: results} =
        Incidents.list_incidents_filtered(%{monitor_id: monitor.id, date_from: ~D[2026-01-15]})

      assert length(results) == 1
      assert hd(results).id == recent.id
    end

    test "filtering by date_to excludes incidents after that date", %{monitor: monitor} do
      old = ~U[2026-01-01 12:00:00Z]
      new = ~U[2026-02-01 12:00:00Z]
      {:ok, early} = Incidents.create_incident(incident_attrs(monitor.id, %{started_at: old}))

      {:ok, _} =
        Incidents.create_incident(
          incident_attrs(monitor.id, %{started_at: new, type: :ssl_expiry})
        )

      %{data: results} =
        Incidents.list_incidents_filtered(%{monitor_id: monitor.id, date_to: ~D[2026-01-15]})

      assert length(results) == 1
      assert hd(results).id == early.id
    end

    test "combining date_from and date_to returns only incidents in range", %{monitor: monitor} do
      t_before = ~U[2025-12-31 12:00:00Z]
      t_inside = ~U[2026-01-10 12:00:00Z]
      t_after = ~U[2026-01-20 12:00:00Z]
      {:ok, _} = Incidents.create_incident(incident_attrs(monitor.id, %{started_at: t_before}))

      {:ok, inside} =
        Incidents.create_incident(
          incident_attrs(monitor.id, %{started_at: t_inside, type: :ssl_expiry})
        )

      {:ok, _} =
        Incidents.create_incident(
          incident_attrs(monitor.id, %{started_at: t_after, type: :defacement})
        )

      %{data: results} =
        Incidents.list_incidents_filtered(%{
          monitor_id: monitor.id,
          date_from: ~D[2026-01-05],
          date_to: ~D[2026-01-15]
        })

      assert length(results) == 1
      assert hd(results).id == inside.id
    end

    test "meta contains correct total count", %{monitor: monitor} do
      Incidents.create_incident(incident_attrs(monitor.id, %{type: :downtime}))
      Incidents.create_incident(incident_attrs(monitor.id, %{type: :ssl_expiry}))

      %{meta: meta} = Incidents.list_incidents_filtered(%{monitor_id: monitor.id})
      assert meta.total == 2
    end
  end

  describe "incident_to_health/1" do
    test "maps :downtime incident to :down" do
      assert Incidents.incident_to_health(%{type: :downtime, root_cause: nil}) == :down
    end

    test "maps :defacement incident to :compromised" do
      assert Incidents.incident_to_health(%{type: :defacement, root_cause: nil}) == :compromised
    end

    test "maps :ssl_expiry with nil root_cause to :degraded" do
      assert Incidents.incident_to_health(%{type: :ssl_expiry, root_cause: nil}) == :degraded
    end

    test "maps :ssl_expiry with 'Critical' in root_cause to :compromised" do
      assert Incidents.incident_to_health(%{
               type: :ssl_expiry,
               root_cause: "Certificate expires in 3 days (Critical)"
             }) == :compromised
    end

    test "maps :ssl_expiry with 'expired' in root_cause to :compromised" do
      assert Incidents.incident_to_health(%{type: :ssl_expiry, root_cause: "Certificate expired"}) ==
               :compromised
    end

    test "maps :ssl_expiry with warning root_cause to :degraded" do
      assert Incidents.incident_to_health(%{
               type: :ssl_expiry,
               root_cause: "Certificate expires in 10 days (Warning)"
             }) == :degraded
    end
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

    test "resolving an already-resolved incident is a safe no-op", %{monitor: monitor} do
      {:ok, incident} = Incidents.create_incident(incident_attrs(monitor.id))
      t1 = ~U[2026-01-01 00:05:00Z]
      t2 = ~U[2026-01-01 00:10:00Z]

      {:ok, _} = Incidents.resolve_incident(incident, t1)
      {:ok, _} = Incidents.resolve_incident(incident, t2)

      reloaded = Incidents.get_incident!(incident.id)
      assert DateTime.compare(reloaded.resolved_at, t1) == :eq
    end

    test "resolving an already-resolved incident does not broadcast a second event", %{
      monitor: monitor
    } do
      {:ok, incident} = Incidents.create_incident(incident_attrs(monitor.id))
      topic = "monitoring:monitor:#{monitor.id}"
      Phoenix.PubSub.subscribe(Holter.PubSub, topic)

      Incidents.resolve_incident(incident, ~U[2026-01-01 00:05:00Z])
      Incidents.resolve_incident(incident, ~U[2026-01-01 00:10:00Z])

      assert_receive {:incident_resolved, _}
      refute_receive {:incident_resolved, _}, 100
    end
  end

  describe "list_incidents_for_gantt/1" do
    test "returns incidents that started before range_end", %{monitor: monitor} do
      range_start = ~U[2026-01-01 00:00:00Z]
      range_end = ~U[2026-01-31 23:59:59Z]

      {:ok, inc} =
        Incidents.create_incident(
          incident_attrs(monitor.id, %{started_at: ~U[2026-01-15 00:00:00Z]})
        )

      results =
        Incidents.list_incidents_for_gantt(%{
          monitor_id: monitor.id,
          range_start: range_start,
          range_end: range_end
        })

      assert Enum.any?(results, &(&1.id == inc.id))
    end

    test "excludes incidents that ended before range_start", %{monitor: monitor} do
      range_start = ~U[2026-02-01 00:00:00Z]
      range_end = ~U[2026-02-28 23:59:59Z]

      {:ok, inc} =
        Incidents.create_incident(
          incident_attrs(monitor.id, %{started_at: ~U[2026-01-01 00:00:00Z]})
        )

      Incidents.resolve_incident(inc, ~U[2026-01-10 00:00:00Z])

      results =
        Incidents.list_incidents_for_gantt(%{
          monitor_id: monitor.id,
          range_start: range_start,
          range_end: range_end
        })

      refute Enum.any?(results, &(&1.id == inc.id))
    end

    test "excludes incidents from other monitors", %{monitor: monitor} do
      other = monitor_fixture()
      range_start = ~U[2026-01-01 00:00:00Z]
      range_end = ~U[2026-01-31 23:59:59Z]

      {:ok, other_inc} =
        Incidents.create_incident(
          incident_attrs(other.id, %{started_at: ~U[2026-01-15 00:00:00Z]})
        )

      results =
        Incidents.list_incidents_for_gantt(%{
          monitor_id: monitor.id,
          range_start: range_start,
          range_end: range_end
        })

      refute Enum.any?(results, &(&1.id == other_inc.id))
    end

    test "includes open incidents (resolved_at IS NULL) started before range_end", %{
      monitor: monitor
    } do
      range_start = ~U[2026-01-01 00:00:00Z]
      range_end = ~U[2026-01-31 23:59:59Z]

      {:ok, inc} =
        Incidents.create_incident(
          incident_attrs(monitor.id, %{started_at: ~U[2026-01-20 00:00:00Z]})
        )

      results =
        Incidents.list_incidents_for_gantt(%{
          monitor_id: monitor.id,
          range_start: range_start,
          range_end: range_end
        })

      assert Enum.any?(results, &(&1.id == inc.id and is_nil(&1.resolved_at)))
    end

    test "respects type filter", %{monitor: monitor} do
      range_start = ~U[2026-01-01 00:00:00Z]
      range_end = ~U[2026-01-31 23:59:59Z]

      {:ok, down} =
        Incidents.create_incident(
          incident_attrs(monitor.id, %{started_at: ~U[2026-01-05 00:00:00Z], type: :downtime})
        )

      {:ok, ssl} =
        Incidents.create_incident(
          incident_attrs(monitor.id, %{started_at: ~U[2026-01-06 00:00:00Z], type: :ssl_expiry})
        )

      results =
        Incidents.list_incidents_for_gantt(%{
          monitor_id: monitor.id,
          range_start: range_start,
          range_end: range_end,
          type: :downtime
        })

      assert Enum.any?(results, &(&1.id == down.id))
      refute Enum.any?(results, &(&1.id == ssl.id))
    end

    test "respects state filter", %{monitor: monitor} do
      range_start = ~U[2026-01-01 00:00:00Z]
      range_end = ~U[2026-01-31 23:59:59Z]

      {:ok, open} =
        Incidents.create_incident(
          incident_attrs(monitor.id, %{started_at: ~U[2026-01-05 00:00:00Z]})
        )

      {:ok, resolved} =
        Incidents.create_incident(
          incident_attrs(monitor.id, %{started_at: ~U[2026-01-06 00:00:00Z], type: :ssl_expiry})
        )

      Incidents.resolve_incident(resolved, ~U[2026-01-07 00:00:00Z])

      results =
        Incidents.list_incidents_for_gantt(%{
          monitor_id: monitor.id,
          range_start: range_start,
          range_end: range_end,
          state: :open
        })

      assert Enum.any?(results, &(&1.id == open.id))
      refute Enum.any?(results, &(&1.id == resolved.id))
    end
  end

  describe "build_gantt_chart_data/3" do
    @range_start ~U[2026-01-01 00:00:00Z]
    @range_end ~U[2026-01-31 23:59:59Z]
    @now ~U[2026-01-31 12:00:00Z]

    test "returns has_incidents: false for empty list" do
      result = Incidents.build_gantt_chart_data([], {@range_start, @range_end}, @now)
      assert result.has_incidents == false
    end

    test "returns has_incidents: true for non-empty list" do
      inc = %{
        id: "abc",
        type: :downtime,
        started_at: ~U[2026-01-10 00:00:00Z],
        resolved_at: ~U[2026-01-11 00:00:00Z]
      }

      result = Incidents.build_gantt_chart_data([inc], {@range_start, @range_end}, @now)
      assert result.has_incidents == true
    end

    test "downtime incident lands in lane 0" do
      inc = %{
        id: "a",
        type: :downtime,
        started_at: ~U[2026-01-10 00:00:00Z],
        resolved_at: ~U[2026-01-11 00:00:00Z]
      }

      %{bars: [bar]} = Incidents.build_gantt_chart_data([inc], {@range_start, @range_end}, @now)
      assert bar.lane == 0
    end

    test "defacement incident lands in lane 1" do
      inc = %{
        id: "b",
        type: :defacement,
        started_at: ~U[2026-01-10 00:00:00Z],
        resolved_at: ~U[2026-01-11 00:00:00Z]
      }

      %{bars: [bar]} = Incidents.build_gantt_chart_data([inc], {@range_start, @range_end}, @now)
      assert bar.lane == 1
    end

    test "ssl_expiry incident lands in lane 2" do
      inc = %{
        id: "c",
        type: :ssl_expiry,
        started_at: ~U[2026-01-10 00:00:00Z],
        resolved_at: ~U[2026-01-11 00:00:00Z]
      }

      %{bars: [bar]} = Incidents.build_gantt_chart_data([inc], {@range_start, @range_end}, @now)
      assert bar.lane == 2
    end

    test "open incident sets open?: true" do
      inc = %{id: "d", type: :downtime, started_at: ~U[2026-01-10 00:00:00Z], resolved_at: nil}
      %{bars: [bar]} = Incidents.build_gantt_chart_data([inc], {@range_start, @range_end}, @now)
      assert bar.open? == true
    end

    test "resolved incident sets open?: false" do
      inc = %{
        id: "e",
        type: :downtime,
        started_at: ~U[2026-01-10 00:00:00Z],
        resolved_at: ~U[2026-01-11 00:00:00Z]
      }

      %{bars: [bar]} = Incidents.build_gantt_chart_data([inc], {@range_start, @range_end}, @now)
      assert bar.open? == false
    end

    test "bar has positive width" do
      inc = %{
        id: "f",
        type: :downtime,
        started_at: ~U[2026-01-10 00:00:00Z],
        resolved_at: ~U[2026-01-11 00:00:00Z]
      }

      %{bars: [bar]} = Incidents.build_gantt_chart_data([inc], {@range_start, @range_end}, @now)
      assert bar.width > 0
    end

    test "x_labels contains approximately 6 entries for a 30-day range" do
      inc = %{
        id: "g",
        type: :downtime,
        started_at: ~U[2026-01-10 00:00:00Z],
        resolved_at: ~U[2026-01-11 00:00:00Z]
      }

      %{x_labels: labels} =
        Incidents.build_gantt_chart_data([inc], {@range_start, @range_end}, @now)

      assert length(labels) >= 5 and length(labels) <= 7
    end
  end

  describe "create_incident/1 concurrent safety" do
    test "creating a duplicate open incident of the same type returns a changeset error", %{
      monitor: monitor
    } do
      {:ok, _} = Incidents.create_incident(incident_attrs(monitor.id, %{type: :downtime}))

      assert {:error, %Ecto.Changeset{}} =
               Incidents.create_incident(incident_attrs(monitor.id, %{type: :downtime}))
    end

    test "creating a duplicate open incident does not raise an unhandled exception", %{
      monitor: monitor
    } do
      {:ok, _} = Incidents.create_incident(incident_attrs(monitor.id, %{type: :ssl_expiry}))

      result = Incidents.create_incident(incident_attrs(monitor.id, %{type: :ssl_expiry}))
      assert match?({:error, %Ecto.Changeset{}}, result)
    end
  end
end

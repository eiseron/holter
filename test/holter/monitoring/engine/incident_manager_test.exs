defmodule Holter.Monitoring.Engine.IncidentManagerTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring
  alias Holter.Monitoring.Engine.IncidentManager

  describe "determine_incident_ops/1" do
    test "returns resolve both on :up status" do
      ops = IncidentManager.determine_incident_ops(%{check_status: :up})
      assert ops == [{:resolve, :downtime}, {:resolve, :defacement}]
    end

    test "down without defacement resolves defacement and opens downtime" do
      ctx = %{check_status: :down, defacement_in_body: false, error_msg: "conn refused"}

      assert IncidentManager.determine_incident_ops(ctx) ==
               [{:resolve, :defacement}, {:open, :downtime, "conn refused"}]
    end

    test "down with defacement_in_body includes resolve defacement op" do
      ctx = %{check_status: :down, defacement_in_body: true, error_msg: "down"}
      ops = IncidentManager.determine_incident_ops(ctx)
      assert {:resolve, :defacement} in ops
    end

    test "down with defacement_in_body includes open downtime op" do
      ctx = %{check_status: :down, defacement_in_body: true, error_msg: "down"}
      ops = IncidentManager.determine_incident_ops(ctx)
      assert {:open, :downtime, "down"} in ops
    end

    test "down with defacement_in_body includes open defacement op" do
      ctx = %{check_status: :down, defacement_in_body: true, error_msg: "down"}
      ops = IncidentManager.determine_incident_ops(ctx)
      assert {:open, :defacement, "down"} in ops
    end

    test "compromised with positive_ok false opens downtime" do
      ctx = %{
        check_status: :compromised,
        positive_ok: false,
        downtime_error_msg: "missing kw",
        defacement_error_msg: "found kw"
      }

      ops = IncidentManager.determine_incident_ops(ctx)
      assert {:open, :downtime, "missing kw"} in ops
    end

    test "compromised with positive_ok false opens defacement" do
      ctx = %{
        check_status: :compromised,
        positive_ok: false,
        downtime_error_msg: "missing kw",
        defacement_error_msg: "found kw"
      }

      ops = IncidentManager.determine_incident_ops(ctx)
      assert {:open, :defacement, "found kw"} in ops
    end

    test "compromised with positive_ok true resolves downtime and opens defacement" do
      ctx = %{check_status: :compromised, positive_ok: true, error_msg: "defaced"}

      assert IncidentManager.determine_incident_ops(ctx) ==
               [{:resolve, :downtime}, {:open, :defacement, "defaced"}]
    end
  end

  describe "pick_active_incident/1" do
    test "returns {nil, :unknown} for empty list" do
      assert IncidentManager.pick_active_incident([]) == {nil, :unknown}
    end

    test "returns the incident id for a single downtime incident" do
      incident = %{id: "abc", type: :downtime, root_cause: nil}
      {id, _status} = IncidentManager.pick_active_incident([incident])
      assert id == "abc"
    end

    test "returns :down health for a downtime incident" do
      incident = %{id: "abc", type: :downtime, root_cause: nil}
      {_id, status} = IncidentManager.pick_active_incident([incident])
      assert status == :down
    end

    test "returns :compromised health for a defacement incident" do
      incident = %{id: "xyz", type: :defacement, root_cause: nil}
      {_id, status} = IncidentManager.pick_active_incident([incident])
      assert status == :compromised
    end

    test "picks the highest severity incident when multiple exist" do
      downtime = %{id: "a", type: :downtime, root_cause: nil}
      defacement = %{id: "b", type: :defacement, root_cause: nil}
      {_id, status} = IncidentManager.pick_active_incident([defacement, downtime])
      assert status == :down
    end

    test "returns the id of the highest severity incident" do
      downtime = %{id: "a", type: :downtime, root_cause: nil}
      defacement = %{id: "b", type: :defacement, root_cause: nil}
      {id, _status} = IncidentManager.pick_active_incident([defacement, downtime])
      assert id == "a"
    end
  end

  describe "resolve_if_open/3" do
    test "resolves the open incident" do
      monitor = monitor_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} =
        Monitoring.create_incident(%{monitor_id: monitor.id, type: :downtime, started_at: now})

      IncidentManager.resolve_if_open(monitor, :downtime, DateTime.add(now, 60, :second))

      assert is_nil(Monitoring.get_open_incident(monitor.id, :downtime))
    end

    test "returns :ok when no open incident exists" do
      monitor = monitor_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      assert IncidentManager.resolve_if_open(monitor, :downtime, now) == :ok
    end
  end

  describe "open_if_missing/3" do
    test "creates an incident when none exists" do
      monitor = monitor_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      ctx = %{now: now, error_msg: "down", snapshot: nil}

      IncidentManager.open_if_missing(monitor, :downtime, ctx)

      assert %{type: :downtime} = Monitoring.get_open_incident(monitor.id, :downtime)
    end

    test "returns :ok without creating duplicate when incident already exists" do
      monitor = monitor_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      ctx = %{now: now, error_msg: "down", snapshot: nil}

      IncidentManager.open_if_missing(monitor, :downtime, ctx)

      assert IncidentManager.open_if_missing(monitor, :downtime, ctx) == :ok
    end

    test "does not open a second incident when one already exists" do
      monitor = monitor_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      ctx = %{now: now, error_msg: "down", snapshot: nil}

      IncidentManager.open_if_missing(monitor, :downtime, ctx)
      IncidentManager.open_if_missing(monitor, :downtime, ctx)

      assert length(Monitoring.list_open_incidents(monitor.id)) == 1
    end
  end

  describe "create_incident_idempotent/3" do
    test "creates an incident when none exists" do
      monitor = monitor_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      meta = %{now: now, error_msg: "test", snapshot: nil}

      assert {:ok, _} = IncidentManager.create_incident_idempotent(monitor, :downtime, meta)
    end

    test "returns :ok instead of constraint error when incident already open" do
      monitor = monitor_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      meta = %{now: now, error_msg: "test", snapshot: nil}

      IncidentManager.create_incident_idempotent(monitor, :downtime, meta)

      assert IncidentManager.create_incident_idempotent(monitor, :downtime, meta) == :ok
    end
  end

  describe "apply_incident_ops/3" do
    test "opens a downtime incident when op list contains {:open, :downtime, msg}" do
      monitor = monitor_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      ctx = %{now: now, error_msg: "down", snapshot: nil}

      IncidentManager.apply_incident_ops(monitor, [{:open, :downtime, "down"}], ctx)

      assert %{type: :downtime} = Monitoring.get_open_incident(monitor.id, :downtime)
    end

    test "resolves a downtime incident when op list contains {:resolve, :downtime}" do
      monitor = monitor_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} =
        Monitoring.create_incident(%{monitor_id: monitor.id, type: :downtime, started_at: now})

      ctx = %{now: DateTime.add(now, 60, :second), error_msg: nil, snapshot: nil}

      IncidentManager.apply_incident_ops(monitor, [{:resolve, :downtime}], ctx)

      assert is_nil(Monitoring.get_open_incident(monitor.id, :downtime))
    end
  end
end

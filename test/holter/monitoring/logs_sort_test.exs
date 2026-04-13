defmodule Holter.Monitoring.LogsSortTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring

  setup do
    monitor = monitor_fixture()
    %{monitor: monitor}
  end

  describe "list_monitor_logs/2 — sort_by: checked_at" do
    setup %{monitor: monitor} do
      old = log_fixture(%{monitor_id: monitor.id, checked_at: ~U[2026-04-01 10:00:00Z]})
      new = log_fixture(%{monitor_id: monitor.id, checked_at: ~U[2026-04-10 10:00:00Z]})
      %{old: old, new: new}
    end

    test "desc returns logs newest-first (default)", %{monitor: monitor, old: _old, new: new} do
      %{logs: [first | _]} =
        Monitoring.list_monitor_logs(monitor, %{sort_by: "checked_at", sort_dir: "desc"})

      assert first.id == new.id
    end

    test "asc returns logs oldest-first", %{monitor: monitor, old: old, new: _new} do
      %{logs: [first | _]} =
        Monitoring.list_monitor_logs(monitor, %{sort_by: "checked_at", sort_dir: "asc"})

      assert first.id == old.id
    end

    test "defaults to checked_at desc when sort_by is nil", %{monitor: monitor, new: new} do
      %{logs: [first | _]} = Monitoring.list_monitor_logs(monitor, %{sort_by: nil, sort_dir: nil})
      assert first.id == new.id
    end
  end

  describe "list_monitor_logs/2 — sort_by: latency_ms" do
    setup %{monitor: monitor} do
      slow =
        log_fixture(%{
          monitor_id: monitor.id,
          latency_ms: 900,
          checked_at: ~U[2026-04-05 10:00:00Z]
        })

      fast =
        log_fixture(%{
          monitor_id: monitor.id,
          latency_ms: 50,
          checked_at: ~U[2026-04-05 11:00:00Z]
        })

      %{slow: slow, fast: fast}
    end

    test "desc returns highest latency first", %{monitor: monitor, slow: slow} do
      %{logs: [first | _]} =
        Monitoring.list_monitor_logs(monitor, %{sort_by: "latency_ms", sort_dir: "desc"})

      assert first.id == slow.id
    end

    test "asc returns lowest latency first", %{monitor: monitor, fast: fast} do
      %{logs: [first | _]} =
        Monitoring.list_monitor_logs(monitor, %{sort_by: "latency_ms", sort_dir: "asc"})

      assert first.id == fast.id
    end

    test "nil latency_ms rows fall last on asc", %{monitor: monitor} do
      nil_latency =
        log_fixture(%{
          monitor_id: monitor.id,
          latency_ms: nil,
          checked_at: ~U[2026-04-05 12:00:00Z]
        })

      %{logs: logs} =
        Monitoring.list_monitor_logs(monitor, %{sort_by: "latency_ms", sort_dir: "asc"})

      last = List.last(logs)
      assert last.id == nil_latency.id
    end
  end

  describe "list_monitor_logs/2 — sort_by: status" do
    setup %{monitor: monitor} do
      up =
        log_fixture(%{monitor_id: monitor.id, status: :up, checked_at: ~U[2026-04-05 10:00:00Z]})

      down =
        log_fixture(%{
          monitor_id: monitor.id,
          status: :down,
          checked_at: ~U[2026-04-05 11:00:00Z]
        })

      %{up: up, down: down}
    end

    test "asc: 'down' comes before 'up' alphabetically", %{monitor: monitor, down: down} do
      %{logs: [first | _]} =
        Monitoring.list_monitor_logs(monitor, %{sort_by: "status", sort_dir: "asc"})

      assert first.id == down.id
    end

    test "desc: 'up' comes before 'down' reverse-alphabetically", %{monitor: monitor, up: up} do
      %{logs: [first | _]} =
        Monitoring.list_monitor_logs(monitor, %{sort_by: "status", sort_dir: "desc"})

      assert first.id == up.id
    end
  end

  describe "list_monitor_logs/2 — invalid sort params fallback" do
    setup %{monitor: monitor} do
      old = log_fixture(%{monitor_id: monitor.id, checked_at: ~U[2026-04-01 10:00:00Z]})
      new = log_fixture(%{monitor_id: monitor.id, checked_at: ~U[2026-04-10 10:00:00Z]})
      %{old: old, new: new}
    end

    test "unknown sort_by falls back to checked_at, keeping sort_dir", %{
      monitor: monitor,
      old: _old,
      new: new
    } do
      %{logs: [first | _]} =
        Monitoring.list_monitor_logs(monitor, %{sort_by: "nonexistent_column", sort_dir: "desc"})

      assert first.id == new.id
    end

    test "unknown sort_by with unknown sort_dir falls back to checked_at desc", %{
      monitor: monitor,
      new: new
    } do
      %{logs: [first | _]} =
        Monitoring.list_monitor_logs(monitor, %{
          sort_by: "nonexistent_column",
          sort_dir: "invalid_dir"
        })

      assert first.id == new.id
    end

    test "unknown sort_dir falls back to desc", %{monitor: monitor, new: new} do
      %{logs: [first | _]} =
        Monitoring.list_monitor_logs(monitor, %{sort_by: "checked_at", sort_dir: "invalid"})

      assert first.id == new.id
    end

    test "both nil falls back to checked_at desc", %{monitor: monitor, new: new} do
      %{logs: [first | _]} = Monitoring.list_monitor_logs(monitor, %{})
      assert first.id == new.id
    end
  end
end

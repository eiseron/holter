defmodule Holter.Monitoring.LogsTest do
  use Holter.DataCase, async: true

  alias Holter.Monitoring.Logs

  setup do
    monitor = monitor_fixture()
    %{monitor: monitor}
  end

  describe "list_monitor_logs/2 — pagination" do
    test "returns page 1 by default", %{monitor: monitor} do
      log_fixture(%{monitor_id: monitor.id})
      result = Logs.list_monitor_logs(monitor, %{})
      assert result.page_number == 1
    end

    test "total_pages is 1 when logs fit in one page", %{monitor: monitor} do
      log_fixture(%{monitor_id: monitor.id})
      result = Logs.list_monitor_logs(monitor, %{page_size: 50})
      assert result.total_pages == 1
    end

    test "clamps page to 1 when requested page is 0", %{monitor: monitor} do
      log_fixture(%{monitor_id: monitor.id})
      result = Logs.list_monitor_logs(monitor, %{page: 0})
      assert result.page_number == 1
    end

    test "clamps page to total_pages when requested page exceeds total", %{monitor: monitor} do
      log_fixture(%{monitor_id: monitor.id})
      result = Logs.list_monitor_logs(monitor, %{page: 9999, page_size: 50})
      assert result.page_number == result.total_pages
    end

    test "respects page_size", %{monitor: monitor} do
      for _ <- 1..5, do: log_fixture(%{monitor_id: monitor.id})
      result = Logs.list_monitor_logs(monitor, %{page_size: 2})
      assert length(result.logs) == 2
    end

    test "returns empty list for monitor with no logs", %{monitor: monitor} do
      result = Logs.list_monitor_logs(monitor, %{})
      assert result.logs == []
    end
  end

  describe "list_monitor_logs/2 — status filter" do
    test "returns only logs matching the given status", %{monitor: monitor} do
      log_fixture(%{monitor_id: monitor.id, status: :up})
      log_fixture(%{monitor_id: monitor.id, status: :down})

      result = Logs.list_monitor_logs(monitor, %{status: "up"})
      assert Enum.all?(result.logs, &(&1.status == :up))
    end

    test "ignores invalid status and returns all logs", %{monitor: monitor} do
      log_fixture(%{monitor_id: monitor.id, status: :up})
      log_fixture(%{monitor_id: monitor.id, status: :down})

      result = Logs.list_monitor_logs(monitor, %{status: "not_a_status"})
      assert length(result.logs) == 2
    end

    test "returns all logs when status is nil", %{monitor: monitor} do
      log_fixture(%{monitor_id: monitor.id, status: :up})
      log_fixture(%{monitor_id: monitor.id, status: :down})

      result = Logs.list_monitor_logs(monitor, %{status: nil})
      assert length(result.logs) == 2
    end

    test "returns all logs when status is empty string", %{monitor: monitor} do
      log_fixture(%{monitor_id: monitor.id})

      result = Logs.list_monitor_logs(monitor, %{status: ""})
      assert length(result.logs) == 1
    end
  end

  describe "list_monitor_logs/2 — sorting" do
    test "sorts by checked_at desc by default", %{monitor: monitor} do
      older = log_fixture(%{monitor_id: monitor.id, checked_at: ~U[2026-01-01 00:00:00Z]})
      newer = log_fixture(%{monitor_id: monitor.id, checked_at: ~U[2026-01-02 00:00:00Z]})

      result = Logs.list_monitor_logs(monitor, %{})
      assert List.first(result.logs).id == newer.id
      assert List.last(result.logs).id == older.id
    end

    test "sorts by latency_ms asc when requested", %{monitor: monitor} do
      log_fixture(%{monitor_id: monitor.id, latency_ms: 500})
      log_fixture(%{monitor_id: monitor.id, latency_ms: 100})

      result = Logs.list_monitor_logs(monitor, %{sort_by: "latency_ms", sort_dir: "asc"})
      assert List.first(result.logs).latency_ms == 100
    end

    test "sorts by latency_ms desc when requested", %{monitor: monitor} do
      log_fixture(%{monitor_id: monitor.id, latency_ms: 100})
      log_fixture(%{monitor_id: monitor.id, latency_ms: 500})

      result = Logs.list_monitor_logs(monitor, %{sort_by: "latency_ms", sort_dir: "desc"})
      assert List.first(result.logs).latency_ms == 500
    end

    test "falls back to checked_at desc for unrecognised sort_by", %{monitor: monitor} do
      older = log_fixture(%{monitor_id: monitor.id, checked_at: ~U[2026-01-01 00:00:00Z]})
      newer = log_fixture(%{monitor_id: monitor.id, checked_at: ~U[2026-01-02 00:00:00Z]})

      result = Logs.list_monitor_logs(monitor, %{sort_by: "not_a_column"})
      assert List.first(result.logs).id == newer.id
      assert List.last(result.logs).id == older.id
    end
  end

  describe "list_monitor_logs/2 — date range filter" do
    test "filters logs on or after start_date", %{monitor: monitor} do
      log_fixture(%{monitor_id: monitor.id, checked_at: ~U[2026-01-01 12:00:00Z]})
      log_fixture(%{monitor_id: monitor.id, checked_at: ~U[2026-01-03 12:00:00Z]})

      result = Logs.list_monitor_logs(monitor, %{start_date: "2026-01-02"})
      assert length(result.logs) == 1
    end

    test "filters logs on or before end_date", %{monitor: monitor} do
      log_fixture(%{monitor_id: monitor.id, checked_at: ~U[2026-01-01 12:00:00Z]})
      log_fixture(%{monitor_id: monitor.id, checked_at: ~U[2026-01-03 12:00:00Z]})

      result = Logs.list_monitor_logs(monitor, %{end_date: "2026-01-02"})
      assert length(result.logs) == 1
    end

    test "filters logs within a date range", %{monitor: monitor} do
      log_fixture(%{monitor_id: monitor.id, checked_at: ~U[2026-01-01 12:00:00Z]})
      log_fixture(%{monitor_id: monitor.id, checked_at: ~U[2026-01-05 12:00:00Z]})
      log_fixture(%{monitor_id: monitor.id, checked_at: ~U[2026-01-10 12:00:00Z]})

      result =
        Logs.list_monitor_logs(monitor, %{start_date: "2026-01-03", end_date: "2026-01-07"})

      assert length(result.logs) == 1
    end

    test "ignores invalid date strings and returns all logs", %{monitor: monitor} do
      log_fixture(%{monitor_id: monitor.id})

      result = Logs.list_monitor_logs(monitor, %{start_date: "not-a-date"})
      assert length(result.logs) == 1
    end
  end

  describe "find_nearest_technical_log/2" do
    test "returns a prior log with response headers", %{monitor: monitor} do
      source =
        log_fixture(%{
          monitor_id: monitor.id,
          status: :up,
          response_headers: %{"server" => "nginx"},
          checked_at: ~U[2026-01-01 00:00:00Z]
        })

      later =
        log_fixture(%{
          monitor_id: monitor.id,
          status: :up,
          response_headers: nil,
          checked_at: ~U[2026-01-02 00:00:00Z]
        })

      found = Logs.find_nearest_technical_log(monitor.id, later)
      assert found.id == source.id
    end

    test "returns a prior log with response snippet", %{monitor: monitor} do
      source =
        log_fixture(%{
          monitor_id: monitor.id,
          status: :up,
          response_snippet: "Hello",
          checked_at: ~U[2026-01-01 00:00:00Z]
        })

      later =
        log_fixture(%{
          monitor_id: monitor.id,
          status: :up,
          response_snippet: nil,
          checked_at: ~U[2026-01-02 00:00:00Z]
        })

      found = Logs.find_nearest_technical_log(monitor.id, later)
      assert found.id == source.id
    end

    test "returns nil when no prior technical log exists", %{monitor: monitor} do
      log =
        log_fixture(%{
          monitor_id: monitor.id,
          status: :up,
          response_snippet: nil,
          response_headers: nil
        })

      assert Logs.find_nearest_technical_log(monitor.id, log) == nil
    end

    test "does not return the log itself", %{monitor: monitor} do
      log =
        log_fixture(%{
          monitor_id: monitor.id,
          status: :up,
          response_snippet: "content",
          response_headers: %{"server" => "nginx"}
        })

      result = Logs.find_nearest_technical_log(monitor.id, log)
      refute result != nil and result.id == log.id
    end
  end

  describe "prune_logs_chunk/3" do
    test "deletes logs older than the retention window", %{monitor: monitor} do
      old_checked_at = DateTime.add(DateTime.utc_now(), -10, :day)
      log_fixture(%{monitor_id: monitor.id, checked_at: old_checked_at})

      deleted = Logs.prune_logs_chunk(monitor.id, 3, 500)
      assert deleted == 1
      assert Logs.list_monitor_logs(monitor, %{}).logs == []
    end

    test "does not delete logs within the retention window", %{monitor: monitor} do
      log_fixture(%{monitor_id: monitor.id, checked_at: DateTime.utc_now()})

      deleted = Logs.prune_logs_chunk(monitor.id, 3, 500)
      assert deleted == 0
      assert length(Logs.list_monitor_logs(monitor, %{}).logs) == 1
    end

    test "deletes at most chunk_size logs per call", %{monitor: monitor} do
      old_checked_at = DateTime.add(DateTime.utc_now(), -10, :day)
      for _ <- 1..5, do: log_fixture(%{monitor_id: monitor.id, checked_at: old_checked_at})

      deleted = Logs.prune_logs_chunk(monitor.id, 3, 3)
      assert deleted == 3
      assert length(Logs.list_monitor_logs(monitor, %{}).logs) == 2
    end
  end

  describe "list_recent_logs_for_chart/2" do
    test "returns logs within the last N hours", %{monitor: monitor} do
      recent = log_fixture(%{monitor_id: monitor.id, checked_at: DateTime.utc_now()})

      log_fixture(%{
        monitor_id: monitor.id,
        checked_at: DateTime.add(DateTime.utc_now(), -48, :hour)
      })

      logs = Logs.list_recent_logs_for_chart(monitor.id, 24)
      assert Enum.any?(logs, &(&1.id == recent.id))
      assert length(logs) == 1
    end

    test "returns logs ordered oldest first", %{monitor: monitor} do
      t1 = DateTime.add(DateTime.utc_now(), -2, :hour)
      t2 = DateTime.add(DateTime.utc_now(), -1, :hour)
      log_fixture(%{monitor_id: monitor.id, checked_at: t2})
      log_fixture(%{monitor_id: monitor.id, checked_at: t1})

      [first, second] = Logs.list_recent_logs_for_chart(monitor.id, 24)
      assert DateTime.compare(first.checked_at, second.checked_at) == :lt
    end
  end
end

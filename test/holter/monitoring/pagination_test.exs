defmodule Holter.Monitoring.PaginationTest do
  use Holter.DataCase, async: true

  import Ecto.Query
  alias Holter.Monitoring.{MonitorLog, Pagination}
  alias Holter.Repo

  describe "calculate/3" do
    test "returns total_pages=1 and current_page=1 when table is empty" do
      monitor = monitor_fixture()
      query = from(l in MonitorLog, where: l.monitor_id == ^monitor.id)
      assert {1, 1} = Pagination.calculate(query, 10, nil)
    end

    test "defaults current_page to 1 when requested_page is nil" do
      monitor = monitor_fixture()
      query = from(l in MonitorLog, where: l.monitor_id == ^monitor.id)
      {_total, current} = Pagination.calculate(query, 10, nil)
      assert current == 1
    end

    test "clamps requested_page to 1 when 0 is requested" do
      monitor = monitor_fixture()
      query = from(l in MonitorLog, where: l.monitor_id == ^monitor.id)
      {_total, current} = Pagination.calculate(query, 10, 0)
      assert current == 1
    end

    test "clamps requested_page to total_pages when exceeding" do
      monitor = monitor_fixture()
      query = from(l in MonitorLog, where: l.monitor_id == ^monitor.id)
      {total, current} = Pagination.calculate(query, 10, 999)
      assert current == total
    end

    test "calculates correct total_pages for record count" do
      monitor = monitor_fixture()

      for _ <- 1..25 do
        log_fixture(monitor_id: monitor.id)
      end

      query = from(l in MonitorLog, where: l.monitor_id == ^monitor.id)
      {total, _current} = Pagination.calculate(query, 10, 1)
      assert total == 3
    end

    test "returns exact page within bounds" do
      monitor = monitor_fixture()

      for _ <- 1..20 do
        log_fixture(monitor_id: monitor.id)
      end

      query = from(l in MonitorLog, where: l.monitor_id == ^monitor.id)
      {_total, current} = Pagination.calculate(query, 10, 2)
      assert current == 2
    end
  end

  describe "paginate_query/3" do
    test "limits results to page_size" do
      monitor = monitor_fixture()
      for _ <- 1..15, do: log_fixture(monitor_id: monitor.id)

      query = from(l in MonitorLog, where: l.monitor_id == ^monitor.id)
      results = query |> Pagination.paginate_query(1, 10) |> Repo.all()
      assert length(results) == 10
    end

    test "returns second page of results" do
      monitor = monitor_fixture()
      for _ <- 1..15, do: log_fixture(monitor_id: monitor.id)

      query = from(l in MonitorLog, where: l.monitor_id == ^monitor.id)
      results = query |> Pagination.paginate_query(2, 10) |> Repo.all()
      assert length(results) == 5
    end

    test "returns empty list when page exceeds available records" do
      monitor = monitor_fixture()
      for _ <- 1..5, do: log_fixture(monitor_id: monitor.id)

      query = from(l in MonitorLog, where: l.monitor_id == ^monitor.id)
      results = query |> Pagination.paginate_query(3, 5) |> Repo.all()
      assert results == []
    end

    test "pages are non-overlapping" do
      monitor = monitor_fixture()
      for _ <- 1..20, do: log_fixture(monitor_id: monitor.id)

      query = from(l in MonitorLog, where: l.monitor_id == ^monitor.id, order_by: l.inserted_at)
      page1 = query |> Pagination.paginate_query(1, 10) |> Repo.all()
      page2 = query |> Pagination.paginate_query(2, 10) |> Repo.all()
      ids1 = MapSet.new(page1, & &1.id)
      ids2 = MapSet.new(page2, & &1.id)
      assert MapSet.disjoint?(ids1, ids2)
    end
  end
end

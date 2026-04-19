defmodule Holter.Monitoring.PaginationTest do
  use Holter.DataCase, async: true

  import Ecto.Query
  alias Holter.Monitoring.{MonitorLog, Pagination}

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
end

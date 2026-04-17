defmodule HolterWeb.Api.DailyMetricControllerTest do
  use HolterWeb.ConnCase

  setup %{conn: conn} do
    monitor = monitor_fixture()
    {:ok, conn: put_req_header(conn, "accept", "application/json"), monitor: monitor}
  end

  describe "GET /api/v1/monitors/:monitor_id/daily_metrics" do
    test "returns paginated response with data and meta", %{conn: conn, monitor: monitor} do
      daily_metric_fixture(%{monitor_id: monitor.id})

      conn = get(conn, ~p"/api/v1/monitors/#{monitor.id}/daily_metrics")

      assert %{"data" => [_], "meta" => meta} = json_response(conn, 200)
      assert %{"page" => 1, "page_size" => 30, "total_pages" => 1} = meta
    end

    test "returns empty data when no metrics exist", %{conn: conn, monitor: monitor} do
      conn = get(conn, ~p"/api/v1/monitors/#{monitor.id}/daily_metrics")

      assert %{"data" => [], "meta" => %{"total_pages" => 1}} = json_response(conn, 200)
    end

    test "respects page_size param", %{conn: conn, monitor: monitor} do
      today = Date.utc_today()

      for i <- 0..4 do
        daily_metric_fixture(%{monitor_id: monitor.id, date: Date.add(today, -i)})
      end

      conn = get(conn, ~p"/api/v1/monitors/#{monitor.id}/daily_metrics?page_size=2")

      assert %{"data" => data, "meta" => %{"page_size" => 2, "total_pages" => 3}} =
               json_response(conn, 200)

      assert length(data) == 2
    end

    test "respects page param", %{conn: conn, monitor: monitor} do
      today = Date.utc_today()

      for i <- 0..4 do
        daily_metric_fixture(%{monitor_id: monitor.id, date: Date.add(today, -i)})
      end

      conn = get(conn, ~p"/api/v1/monitors/#{monitor.id}/daily_metrics?page_size=2&page=2")

      assert %{"data" => data, "meta" => %{"page" => 2}} = json_response(conn, 200)
      assert length(data) == 2
    end

    test "sorts by uptime_percent ascending", %{conn: conn, monitor: monitor} do
      today = Date.utc_today()

      daily_metric_fixture(%{monitor_id: monitor.id, date: today, uptime_percent: 90.0})

      daily_metric_fixture(%{
        monitor_id: monitor.id,
        date: Date.add(today, -1),
        uptime_percent: 99.5
      })

      conn =
        get(
          conn,
          ~p"/api/v1/monitors/#{monitor.id}/daily_metrics?sort_by=uptime_percent&sort_dir=asc"
        )

      assert %{"data" => [first | _]} = json_response(conn, 200)
      assert Decimal.compare(first["uptime_percent"], Decimal.new("90.0")) == :eq
    end

    test "returns 404 for unknown monitor", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/monitors/00000000-0000-0000-0000-000000000000/daily_metrics")

      assert json_response(conn, 404)
    end
  end
end

defmodule HolterWeb.Web.Monitoring.MonitorLiveIncidentsTest do
  use HolterWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Holter.Monitoring

  @monitor_attrs %{
    url: "https://example.local",
    method: :get,
    interval_seconds: 60,
    logical_state: :active
  }

  setup do
    monitor = monitor_fixture(@monitor_attrs)
    %{monitor: monitor}
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

  describe "incidents history page" do
    setup %{conn: conn, monitor: monitor} do
      Monitoring.create_incident(incident_attrs(monitor.id, %{type: :downtime}))

      {:ok, view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}/incidents")
      %{view: view, html: html}
    end

    test "renders the incidents table on the page", %{html: html} do
      assert html =~ "incidents-table"
    end

    test "renders the monitor URL in the subtitle", %{html: html} do
      assert html =~ "https://example.local"
    end

    test "renders 'Downtime' label for a downtime incident", %{html: html} do
      assert html =~ ~s(data-role="incident-type")
    end

    test "back link points to monitor details", %{view: view, monitor: monitor} do
      assert has_element?(view, "a.h-btn-back[href='/monitoring/monitor/#{monitor.id}']")
    end
  end

  describe "filtering by type" do
    setup %{conn: conn, monitor: monitor} do
      Monitoring.create_incident(incident_attrs(monitor.id, %{type: :downtime}))
      Monitoring.create_incident(incident_attrs(monitor.id, %{type: :ssl_expiry}))

      %{conn: conn, monitor: monitor}
    end

    test "filtering by type=ssl_expiry shows only the ssl_expiry incident in the table",
         %{conn: conn, monitor: monitor} do
      {:ok, _view, html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}/incidents?type=ssl_expiry")

      assert html =~ ~s(data-incident-type="ssl_expiry")
    end

    test "filtering by type=ssl_expiry excludes downtime incidents from the table",
         %{conn: conn, monitor: monitor} do
      {:ok, _view, html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}/incidents?type=ssl_expiry")

      refute html =~ ~s(data-incident-type="downtime")
    end

    test "filtering by type=downtime shows only the downtime incident in the table",
         %{conn: conn, monitor: monitor} do
      {:ok, _view, html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}/incidents?type=downtime")

      assert html =~ ~s(data-incident-type="downtime")
    end

    test "filtering by type=downtime excludes ssl_expiry incidents from the table",
         %{conn: conn, monitor: monitor} do
      {:ok, _view, html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}/incidents?type=downtime")

      refute html =~ ~s(data-incident-type="ssl_expiry")
    end
  end

  describe "filtering by state" do
    setup %{conn: conn, monitor: monitor} do
      {:ok, resolved} = Monitoring.create_incident(incident_attrs(monitor.id, %{type: :downtime}))
      Monitoring.resolve_incident(resolved, DateTime.utc_now() |> DateTime.truncate(:second))
      Monitoring.create_incident(incident_attrs(monitor.id, %{type: :ssl_expiry}))

      %{conn: conn, monitor: monitor}
    end

    test "filtering by state=open shows the open ssl_expiry incident in the table",
         %{conn: conn, monitor: monitor} do
      {:ok, _view, html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}/incidents?state=open")

      assert html =~ ~s(data-incident-type="ssl_expiry")
    end

    test "filtering by state=open excludes the resolved downtime incident from the table",
         %{conn: conn, monitor: monitor} do
      {:ok, _view, html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}/incidents?state=open")

      refute html =~ ~s(data-incident-type="downtime")
    end

    test "filtering by state=resolved shows the resolved downtime incident in the table",
         %{conn: conn, monitor: monitor} do
      {:ok, _view, html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}/incidents?state=resolved")

      assert html =~ ~s(data-incident-type="downtime")
    end

    test "filtering by state=resolved excludes the open ssl_expiry incident from the table",
         %{conn: conn, monitor: monitor} do
      {:ok, _view, html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}/incidents?state=resolved")

      refute html =~ ~s(data-incident-type="ssl_expiry")
    end
  end

  describe "pagination" do
    setup %{conn: conn, monitor: monitor} do
      t1 = ~U[2026-01-01 00:00:00Z]
      t2 = ~U[2026-01-02 00:00:00Z]

      {:ok, _} =
        Monitoring.create_incident(incident_attrs(monitor.id, %{type: :downtime, started_at: t1}))

      {:ok, _} =
        Monitoring.create_incident(
          incident_attrs(monitor.id, %{type: :ssl_expiry, started_at: t2})
        )

      %{conn: conn, monitor: monitor}
    end

    test "page 2 of size 1 does not include incidents from page 1",
         %{conn: conn, monitor: monitor} do
      {:ok, _view, html1} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}/incidents?page=1&page_size=1")

      {:ok, _view, html2} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}/incidents?page=2&page_size=1")

      refute html1 == html2
    end
  end
end

defmodule HolterWeb.Web.Monitoring.MonitorLiveIncidentDetailTest do
  use HolterWeb.ConnCase
  import Phoenix.LiveViewTest
  use Gettext, backend: HolterWeb.Gettext
  alias Holter.Monitoring

  setup do
    monitor = monitor_fixture(%{url: "https://detail.local"})

    {:ok, incident} =
      Monitoring.create_incident(%{
        monitor_id: monitor.id,
        type: :ssl_expiry,
        started_at: ~U[2026-01-01 10:00:00Z],
        root_cause: "Certificate expires in 3 days (Critical)",
        monitor_snapshot: %{url: "https://detail.local", interval_seconds: 60}
      })

    %{monitor: monitor, incident: incident}
  end

  describe "incident detail log links" do
    test "renders a link to each log associated with the incident",
         %{conn: conn, monitor: monitor, incident: incident} do
      log = log_fixture(%{monitor_id: monitor.id, status: :down, incident_id: incident.id})

      {:ok, lv, _html} = live(conn, ~p"/monitoring/incidents/#{incident.id}")

      assert has_element?(lv, "a[href='/monitoring/logs/#{log.id}']")
    end

    test "log link has the h-link CSS class for visual styling",
         %{conn: conn, monitor: monitor, incident: incident} do
      log = log_fixture(%{monitor_id: monitor.id, status: :down, incident_id: incident.id})

      {:ok, lv, _html} = live(conn, ~p"/monitoring/incidents/#{incident.id}")

      assert has_element?(lv, "a.h-link[href='/monitoring/logs/#{log.id}']")
    end

    test "log link label is translated",
         %{conn: conn, monitor: monitor, incident: incident} do
      log_fixture(%{monitor_id: monitor.id, status: :down, incident_id: incident.id})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/incidents/#{incident.id}")

      assert html =~ gettext("View log")
    end

    test "does not render the log section when the incident has no associated logs",
         %{conn: conn, incident: incident} do
      {:ok, _lv, html} = live(conn, ~p"/monitoring/incidents/#{incident.id}")

      refute html =~ gettext("View log")
    end

    test "does not show truncation notice when logs count is within the limit",
         %{conn: conn, monitor: monitor, incident: incident} do
      log_fixture(%{monitor_id: monitor.id, status: :down, incident_id: incident.id})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/incidents/#{incident.id}")

      refute html =~ "of 1 associated logs"
    end

    test "shows truncation notice when there are more than 10 associated logs",
         %{conn: conn, monitor: monitor, incident: incident} do
      for _ <- 1..11 do
        log_fixture(%{monitor_id: monitor.id, status: :down, incident_id: incident.id})
      end

      {:ok, _lv, html} = live(conn, ~p"/monitoring/incidents/#{incident.id}")

      assert html =~ gettext("Showing last 10 of %{total} associated logs.", total: 11)
    end

    test "renders at most 10 log links when there are more than 10 associated logs",
         %{conn: conn, monitor: monitor, incident: incident} do
      for _ <- 1..11 do
        log_fixture(%{monitor_id: monitor.id, status: :down, incident_id: incident.id})
      end

      {:ok, lv, _html} = live(conn, ~p"/monitoring/incidents/#{incident.id}")

      assert lv
             |> element(".h-incident-logs-list")
             |> render()
             |> then(fn html ->
               length(Regex.scan(~r/h-link/, html))
             end) == 10
    end
  end

  describe "incident detail page" do
    test "renders the incident root_cause on the page",
         %{conn: conn, incident: incident} do
      {:ok, _view, html} = live(conn, ~p"/monitoring/incidents/#{incident.id}")
      assert html =~ ~s(data-role="incident-root-cause")
    end

    test "renders the correct root_cause text for the incident",
         %{conn: conn, incident: incident} do
      {:ok, _view, html} = live(conn, ~p"/monitoring/incidents/#{incident.id}")
      assert html =~ "Certificate expires in 3 days (Critical)"
    end

    test "renders monitor snapshot fields on the page",
         %{conn: conn, incident: incident} do
      {:ok, _view, html} = live(conn, ~p"/monitoring/incidents/#{incident.id}")
      assert html =~ "Monitor Snapshot"
    end

    test "back link points to the incidents history URL for the monitor",
         %{conn: conn, incident: incident, monitor: monitor} do
      {:ok, _view, html} = live(conn, ~p"/monitoring/incidents/#{incident.id}")
      assert html =~ "/monitoring/monitor/#{monitor.id}/incidents"
    end
  end
end

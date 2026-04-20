defmodule HolterWeb.Web.Monitoring.MonitorLiveLogDetailTest do
  use HolterWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Log Detail mount" do
    setup do
      monitor = monitor_fixture(%{url: "https://detail.local"})
      %{monitor: monitor}
    end

    test "Given a valid log, when mounted, then the page renders with Log Details title",
         %{conn: conn, monitor: monitor} do
      log = log_fixture(%{monitor_id: monitor.id, status: :up, latency_ms: 150})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/logs/#{log.id}")

      assert html =~ "Log Details"
    end

    test "Given a log, when mounted, then the monitor URL is shown in the subtitle",
         %{conn: conn, monitor: monitor} do
      log = log_fixture(%{monitor_id: monitor.id})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/logs/#{log.id}")

      assert html =~ monitor.url
    end

    test "Given a log, when mounted, then the back link points to the logs page",
         %{conn: conn, monitor: monitor} do
      log = log_fixture(%{monitor_id: monitor.id})

      {:ok, lv, _html} = live(conn, ~p"/monitoring/logs/#{log.id}")

      assert has_element?(lv, "a[href='/monitoring/monitor/#{monitor.id}/logs']")
    end

    test "Given a log with status UP, when mounted, then the status pill is rendered",
         %{conn: conn, monitor: monitor} do
      log = log_fixture(%{monitor_id: monitor.id, status: :up, status_code: 200})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/logs/#{log.id}")

      assert html =~ "UP"
    end

    test "Given a log with status DOWN, when mounted, then the status pill shows DOWN",
         %{conn: conn, monitor: monitor} do
      log = log_fixture(%{monitor_id: monitor.id, status: :down, status_code: 503})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/logs/#{log.id}")

      assert html =~ "DOWN"
    end

    test "Given a log with latency, when mounted, then the latency in ms is displayed",
         %{conn: conn, monitor: monitor} do
      log = log_fixture(%{monitor_id: monitor.id, latency_ms: 342})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/logs/#{log.id}")

      assert html =~ "342ms"
    end

    test "Given a log with an error message, when mounted, then the error is displayed",
         %{conn: conn, monitor: monitor} do
      log =
        log_fixture(%{monitor_id: monitor.id, status: :down, error_message: "connection refused"})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/logs/#{log.id}")

      assert html =~ "connection refused"
    end

    test "Given a log with no error message, when mounted, then the error block is absent",
         %{conn: conn, monitor: monitor} do
      log = log_fixture(%{monitor_id: monitor.id, status: :up, error_message: nil})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/logs/#{log.id}")

      refute html =~ "Network Error"
      refute html =~ "Error Message"
    end

    test "Given a log with response headers, when mounted, then the headers block is rendered",
         %{conn: conn, monitor: monitor} do
      log =
        log_fixture(%{
          monitor_id: monitor.id,
          response_headers: %{"content-type" => "text/html"}
        })

      {:ok, _lv, html} = live(conn, ~p"/monitoring/logs/#{log.id}")

      assert html =~ "Response Headers"
      assert html =~ "content-type"
    end

    test "Given a log with a response snippet, when mounted, then the content block is rendered",
         %{conn: conn, monitor: monitor} do
      log =
        log_fixture(%{
          monitor_id: monitor.id,
          response_snippet: "Hello world"
        })

      {:ok, _lv, html} = live(conn, ~p"/monitoring/logs/#{log.id}")

      assert html =~ "Content Snippet"
      assert html =~ "Hello world"
    end

    test "Given a log with a redirect chain, when mounted, then the redirect chain is rendered",
         %{conn: conn, monitor: monitor} do
      log =
        log_fixture(%{
          monitor_id: monitor.id,
          redirect_count: 1,
          redirect_list: [
            %{"url" => "http://redir.local", "ip" => "1.2.3.4", "status_code" => 301},
            %{"url" => "https://redir.local", "ip" => "1.2.3.4", "status_code" => nil}
          ]
        })

      {:ok, _lv, html} = live(conn, ~p"/monitoring/logs/#{log.id}")

      assert html =~ "Redirect Chain"
      assert html =~ "http://redir.local"
    end

    test "Given a log with no redirects, when mounted, then the redirect chain block is absent",
         %{conn: conn, monitor: monitor} do
      log = log_fixture(%{monitor_id: monitor.id, redirect_count: 0})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/logs/#{log.id}")

      refute html =~ "Redirect Chain"
    end
  end

  describe "Log Detail incident link" do
    setup do
      %{monitor: monitor_fixture(%{url: "https://incident-link.local"})}
    end

    test "Given a log linked to an incident, when mounted, then a link to the incident detail is shown",
         %{conn: conn, monitor: monitor} do
      incident = incident_fixture(%{monitor_id: monitor.id, type: :downtime})
      log = log_fixture(%{monitor_id: monitor.id, status: :down, incident_id: incident.id})

      {:ok, lv, _html} = live(conn, ~p"/monitoring/logs/#{log.id}")

      assert has_element?(lv, "a[href='/monitoring/incidents/#{incident.id}']")
    end

    test "Given a log with no incident, when mounted, then no incident link is rendered",
         %{conn: conn, monitor: monitor} do
      log = log_fixture(%{monitor_id: monitor.id, status: :up, incident_id: nil})

      {:ok, _lv, html} = live(conn, ~p"/monitoring/logs/#{log.id}")

      refute html =~ "/monitoring/incidents/"
    end
  end

  describe "Log Detail inherited evidence" do
    test "Given a UP log with no payload and a prior log with payload, when mounted, then the inherited notice is shown",
         %{conn: conn} do
      monitor = monitor_fixture()

      source_log =
        log_fixture(%{
          monitor_id: monitor.id,
          status: :up,
          response_snippet: "original content",
          response_headers: %{"server" => "nginx"}
        })

      inherited_log =
        log_fixture(%{
          monitor_id: monitor.id,
          status: :up,
          response_snippet: nil,
          response_headers: nil,
          checked_at: DateTime.add(source_log.checked_at, 60, :second)
        })

      {:ok, _lv, html} = live(conn, ~p"/monitoring/logs/#{inherited_log.id}")

      assert html =~ "No new evidence was captured"
      assert html =~ "View original log"
    end

    test "Given a DOWN log, when mounted, then the inherited evidence notice is never shown",
         %{conn: conn} do
      monitor = monitor_fixture()

      log =
        log_fixture(%{
          monitor_id: monitor.id,
          status: :down,
          error_message: "timeout",
          response_snippet: nil,
          response_headers: nil
        })

      {:ok, _lv, html} = live(conn, ~p"/monitoring/logs/#{log.id}")

      refute html =~ "No new evidence was captured"
    end
  end
end

defmodule HolterWeb.Web.Monitoring.MonitorLiveShowTest do
  use HolterWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mox
  alias Holter.Monitoring
  alias Holter.Monitoring.Workers.{HTTPCheck, SSLCheck}
  use Oban.Testing, repo: Holter.Repo

  setup :verify_on_exit!

  describe "Monitor LiveView Show/Edit User Flow" do
    @valid_attrs %{
      url: "https://example.local",
      method: :get,
      interval_seconds: 300,
      timeout_seconds: 10,
      ssl_ignore: false,
      raw_keyword_positive: "success",
      raw_keyword_negative: "hacked"
    }

    setup do
      monitor = monitor_fixture(@valid_attrs)
      workspace = Monitoring.get_workspace!(monitor.workspace_id)
      %{monitor: monitor, workspace: workspace}
    end

    test "Given a monitor with follow redirects enabled (default), when page loads, then max redirects field is visible",
         %{conn: conn, monitor: monitor} do
      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert html =~ "Max Redirects"
    end

    test "Given follow redirects unchecked, when validate fires, then max redirects field is hidden",
         %{conn: conn, monitor: monitor} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      html =
        view
        |> form("#monitor-form", monitor: %{follow_redirects: "false"})
        |> render_change()

      refute html =~ "Max Redirects"
    end

    test "Given a GET monitor, when page loads, then body field is hidden", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      refute html =~ "Request Body"
    end

    test "Given a GET monitor, when method is changed to POST, then body field appears", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      html =
        view
        |> form("#monitor-form", monitor: %{method: "post"})
        |> render_change()

      assert html =~ "Request Body"
    end

    test "Given a monitor, when page loads, then it renders the title", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, _view, html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert html =~ "Monitor Settings"
    end

    test "Given a monitor, when page loads, then it displays the monitor URL", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, _view, html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert html =~ monitor.url
    end

    test "Given a user updating URL, when form submitted, then URL persists in database", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view
      |> form("#monitor-form", monitor: %{url: "https://updated.local"})
      |> render_submit()

      assert Monitoring.get_monitor!(monitor.id).url == "https://updated.local"
    end

    test "Given a user updating interval, when form submitted, then interval persists in database",
         %{
           conn: conn,
           monitor: monitor
         } do
      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view
      |> form("#monitor-form", monitor: %{interval_seconds: 60})
      |> render_submit()

      assert Monitoring.get_monitor!(monitor.id).interval_seconds == 60
    end

    test "Given malformed inputs, when the form validates, then it renders the validation output",
         %{
           conn: conn,
           monitor: monitor
         } do
      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert view
             |> form("#monitor-form", monitor: %{url: "not-a-url"})
             |> render_change() =~ "must be a valid http or https URL"
    end

    test "Given a user updating ssl_ignore, when submitted, then boolean persists", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view
      |> form("#monitor-form", monitor: %{ssl_ignore: true})
      |> render_submit()

      assert Monitoring.get_monitor!(monitor.id).ssl_ignore == true
    end

    test "Given a user updating positive keywords, when submitted, then it tracks as an array", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view
      |> form("#monitor-form",
        monitor: %{raw_keyword_positive: "checkout, authentication"}
      )
      |> render_submit()

      assert Monitoring.get_monitor!(monitor.id).keyword_positive == [
               "checkout",
               "authentication"
             ]
    end

    test "Given a user updating negative keywords, when submitted, then it strips and tracks as an array",
         %{
           conn: conn,
           monitor: monitor
         } do
      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view
      |> form("#monitor-form",
        monitor: %{raw_keyword_negative: "fatal_error ; timeout"}
      )
      |> render_submit()

      assert Monitoring.get_monitor!(monitor.id).keyword_negative == ["fatal_error", "timeout"]
    end

    test "Given a user updating raw headers, when submitted, then it decodes as JSON map", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view
      |> form("#monitor-form",
        monitor: %{raw_headers: "{\"x-api-key\": \"secret\"}"}
      )
      |> render_submit()

      assert Monitoring.get_monitor!(monitor.id).headers == %{"x-api-key" => "secret"}
    end

    test "Given a user clicking the modal deletion confirmation, when processed, then the UX redirects",
         %{
           conn: conn,
           monitor: monitor,
           workspace: workspace
         } do
      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view |> element("button[phx-click=\"delete\"]") |> render_click()
      assert_redirected(view, "/monitoring/workspaces/#{workspace.slug}/dashboard")
    end

    test "Given a user clicking the modal deletion confirmation, when processed, then the database destroys the record",
         %{
           conn: conn,
           monitor: monitor
         } do
      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view |> element("button[phx-click=\"delete\"]") |> render_click()
      assert_raise Ecto.NoResultsError, fn -> Monitoring.get_monitor!(monitor.id) end
    end

    test "Given a monitor, when user clicks Run Now, then it enqueues jobs and starts cooldown",
         %{
           conn: conn,
           monitor: monitor
         } do
      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view |> element("button[phx-click=\"run_now\"]") |> render_click()
      assert render(view) =~ "Wait 60s"
      assert_enqueued(worker: Holter.Monitoring.Workers.HTTPCheck, args: %{id: monitor.id})
    end

    test "Given a paused monitor, when page loads, then badge shows PAUSED label", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, monitor} = Monitoring.update_monitor(monitor, %{logical_state: :paused})
      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert html =~ "PAUSED"
    end

    test "Given a paused monitor, when page loads, then badge uses paused style class", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, monitor} = Monitoring.update_monitor(monitor, %{logical_state: :paused})
      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert html =~ "h-status-paused"
    end

    test "Given an active monitor, when page loads, then badge does not show PAUSED label", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      refute html =~ "PAUSED"
    end

    test "Given a monitor with an active downtime incident, when page loads, then active incidents section is visible",
         %{conn: conn, monitor: monitor} do
      Monitoring.create_incident(%{
        monitor_id: monitor.id,
        type: :downtime,
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")
      assert html =~ "Active Incidents"
    end

    test "Given a monitor with no active incidents, when page loads, then active incidents section is not rendered",
         %{conn: conn, monitor: monitor} do
      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")
      refute html =~ "Active Incidents"
    end

    test "Given a monitor with an active incident, when page loads, then incident type is shown",
         %{conn: conn, monitor: monitor} do
      Monitoring.create_incident(%{
        monitor_id: monitor.id,
        type: :ssl_expiry,
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      {:ok, _view, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")
      assert html =~ "SSL EXPIRY"
    end
  end

  describe "ssl_ignore: user disables SSL checks on a degraded monitor and triggers Run Now" do
    setup %{conn: conn} do
      monitor =
        monitor_fixture(%{
          url: "https://secure-service.local",
          method: "get",
          interval_seconds: 60,
          logical_state: :active
        })

      {:ok, _} =
        Monitoring.create_incident(%{
          monitor_id: monitor.id,
          type: :ssl_expiry,
          started_at: DateTime.utc_now() |> DateTime.truncate(:second),
          root_cause: "Certificate expires in 8 days (Warning)"
        })

      {:ok, monitor} = Monitoring.update_monitor(monitor, %{health_status: :degraded})

      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view
      |> form("#monitor-form", monitor: %{ssl_ignore: true})
      |> render_submit()

      view |> element("button[phx-click=\"run_now\"]") |> render_click()

      stub(Holter.Monitoring.MonitorClientMock, :request, fn _opts ->
        {:ok, %Req.Response{status: 200, body: "ok", headers: []}}
      end)

      :ok = perform_job(SSLCheck, %{"id" => monitor.id})
      :ok = perform_job(HTTPCheck, %{"id" => monitor.id})

      %{monitor: monitor, view: view}
    end

    test "the ssl_expiry incident is resolved", %{monitor: monitor} do
      assert is_nil(Monitoring.get_open_incident(monitor.id, :ssl_expiry))
    end

    test "the monitor health_status is restored to :up", %{monitor: monitor} do
      assert Monitoring.get_monitor!(monitor.id).health_status == :up
    end

    test "the UI reflects the restored status", %{view: view} do
      assert render(view) =~ "status-up"
    end
  end

  describe "Monitor LiveView Show/Edit User Flow (continued)" do
    @valid_attrs_2 %{
      url: "https://example.local",
      method: :get,
      interval_seconds: 300,
      timeout_seconds: 10,
      ssl_ignore: false,
      raw_keyword_positive: "success",
      raw_keyword_negative: "hacked"
    }

    setup do
      monitor = monitor_fixture(@valid_attrs_2)
      workspace = Monitoring.get_workspace!(monitor.workspace_id)
      %{monitor: monitor, workspace: workspace}
    end

    test "Given a down monitor, when user clicks Run Now and check succeeds, then UI updates to UP automatically",
         %{conn: conn, monitor: monitor} do
      {:ok, monitor} = Monitoring.update_monitor(monitor, %{health_status: :down})

      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert render(view) =~ "status-down"

      view |> element("button[phx-click=\"run_now\"]") |> render_click()

      expect(Holter.Monitoring.MonitorClientMock, :request, fn _opts ->
        {:ok, %Req.Response{status: 200, body: "success", headers: []}}
      end)

      assert_enqueued(worker: HTTPCheck, args: %{id: monitor.id})
      :ok = perform_job(HTTPCheck, %{"id" => monitor.id})

      assert render(view) =~ "status-up"
    end
  end
end

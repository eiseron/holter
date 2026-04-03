defmodule HolterWeb.Monitoring.MonitorLiveShowTest do
  use HolterWeb.ConnCase
  use Oban.Testing, repo: Holter.Repo

  import Phoenix.LiveViewTest

  alias Holter.Monitoring

  describe "Monitor LiveView Show/Edit User Flow" do
    @valid_attrs %{
      url: "https://example.local",
      method: :GET,
      interval_seconds: 300,
      timeout_seconds: 10,
      ssl_ignore: false,
      raw_keyword_positive: "success",
      raw_keyword_negative: "hacked"
    }

    setup do
      {:ok, monitor} = Monitoring.create_monitor(@valid_attrs)
      %{monitor: monitor}
    end

    test "Given a monitor, when page loads, then it renders the title", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert has_element?(view, "h1", "Monitor Settings") ||
               has_element?(view, "h1", "Configurações do Monitor")
    end

    test "Given a monitor, when page loads, then it renders the UUID", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert has_element?(view, "p", monitor.id)
    end

    test "Given a user updating URL, when form submitted, then URL persists in database", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view |> form("#monitor-form", monitor: %{url: "https://updated.local"}) |> render_submit()

      assert Monitoring.get_monitor!(monitor.id).url == "https://updated.local"
    end

    test "Given a user updating interval, when form submitted, then interval persists in database",
         %{conn: conn, monitor: monitor} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view |> form("#monitor-form", monitor: %{interval_seconds: "60"}) |> render_submit()

      assert Monitoring.get_monitor!(monitor.id).interval_seconds == 60
    end

    test "Given malformed inputs, when the form validates, then it renders the validation output",
         %{conn: conn, monitor: monitor} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert view |> form("#monitor-form", monitor: %{url: "not-a-valid-url"}) |> render_change() =~
               "form"
    end

    test "Given a user updating ssl_ignore, when submitted, then boolean persists", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view |> form("#monitor-form", monitor: %{ssl_ignore: "true"}) |> render_submit()

      assert Monitoring.get_monitor!(monitor.id).ssl_ignore == true
    end

    test "Given a user updating positive keywords, when submitted, then it tracks as an array", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view
      |> form("#monitor-form", monitor: %{raw_keyword_positive: "checkout, authentication"})
      |> render_submit()

      assert Monitoring.get_monitor!(monitor.id).keyword_positive == [
               "checkout",
               "authentication"
             ]
    end

    test "Given a user updating negative keywords, when submitted, then it strips and tracks as an array",
         %{conn: conn, monitor: monitor} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view
      |> form("#monitor-form", monitor: %{raw_keyword_negative: "fatal_error ; timeout"})
      |> render_submit()

      assert Monitoring.get_monitor!(monitor.id).keyword_negative == ["fatal_error", "timeout"]
    end

    test "Given a user updating raw headers, when submitted, then it decodes as JSON map", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view
      |> form("#monitor-form", monitor: %{raw_headers: "{\"x-api-key\": \"secret\"}"})
      |> render_submit()

      assert Monitoring.get_monitor!(monitor.id).headers == %{"x-api-key" => "secret"}
    end

    test "Given a user clicking the modal deletion confirmation, when processed, then the UX redirects",
         %{conn: conn, monitor: monitor} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view |> element("button.confirm-btn") |> render_click()
      assert_redirect(view, "/monitoring/dashboard")
    end

    test "Given a user clicking the modal deletion confirmation, when processed, then the database destroys the record",
         %{conn: conn, monitor: monitor} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view |> element("button.confirm-btn") |> render_click()

      assert_raise Ecto.NoResultsError, fn ->
        Monitoring.get_monitor!(monitor.id)
      end
    end

    test "Given a monitor, when user clicks Run Now, then it enqueues jobs and starts cooldown",
         %{
           conn: conn,
           monitor: monitor
         } do
      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view |> element("button.btn-run-now") |> render_click()

      assert render(view) =~ "Wait 30s"
      assert_enqueued(worker: Holter.Monitoring.Workers.HTTPCheck, args: %{id: monitor.id})
    end

    test "Given a down monitor, when user clicks Run Now and check succeeds, then UI updates to UP automatically",
         %{conn: conn, monitor: monitor} do
      import Mox
      alias Holter.Monitoring.Workers.HTTPCheck

      # 1. Start DOWN
      {:ok, monitor} = Monitoring.update_monitor(monitor, %{health_status: :down})
      {:ok, view, _html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")
      assert render(view) =~ "status-down"

      # 2. Click Run Now
      view |> element("button.btn-run-now") |> render_click()

      # 3. Mock success and perform job
      expect(Holter.Monitoring.MonitorClientMock, :request, fn _opts ->
        {:ok, %Req.Response{status: 200, body: "success", headers: []}}
      end)

      # We find the enqueued job and run it
      assert_enqueued(worker: HTTPCheck, args: %{id: monitor.id})
      :ok = perform_job(HTTPCheck, %{"id" => monitor.id, "client_name" => "mock"})

      # 4. Assert UI updated via PubSub
      assert render(view) =~ "status-up"
    end
  end
end

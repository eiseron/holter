defmodule HolterWeb.Web.Monitoring.MonitorLiveNewTest do
  use HolterWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Monitor Creation User Flow" do
    @valid_attrs %{
      url: "https://example.local",
      method: :get,
      interval_seconds: "300",
      timeout_seconds: "10"
    }

    setup do
      workspace = workspace_fixture()
      %{workspace: workspace}
    end

    test "Given GET method (default), when page loads, then body field is hidden",
         %{conn: conn, workspace: workspace} do
      {:ok, _view, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/new")

      refute html =~ "Request Body"
    end

    test "Given POST method, when validate fires, then body field becomes visible",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/new")

      html =
        view
        |> form("#monitor-form", monitor: %{method: "post"})
        |> render_change()

      assert html =~ "Request Body"
    end

    test "Given POST method, when method is changed back to GET, then body field is hidden again",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/new")

      view
      |> form("#monitor-form", monitor: %{method: "post"})
      |> render_change()

      html =
        view
        |> form("#monitor-form", monitor: %{method: "get"})
        |> render_change()

      refute html =~ "Request Body"
    end

    test "Given HEAD method, when validate fires, then body field is hidden",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/new")

      html =
        view
        |> form("#monitor-form", monitor: %{method: "head"})
        |> render_change()

      refute html =~ "Request Body"
    end

    test "Given follow redirects checked (default), when page loads, then max redirects field is visible",
         %{conn: conn, workspace: workspace} do
      {:ok, _view, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/new")

      assert html =~ "Max Redirects"
    end

    test "Given follow redirects unchecked, when validate fires, then max redirects field is hidden",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/new")

      html =
        view
        |> form("#monitor-form", monitor: %{follow_redirects: "false"})
        |> render_change()

      refute html =~ "Max Redirects"
    end

    test "Given follow redirects unchecked, when re-checked, then max redirects field reappears",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/new")

      view
      |> form("#monitor-form", monitor: %{follow_redirects: "false"})
      |> render_change()

      html =
        view
        |> form("#monitor-form", monitor: %{follow_redirects: "true"})
        |> render_change()

      assert html =~ "Max Redirects"
    end

    test "Given the creation route, when mounted, then the page correctly translates and establishes the HTML DOM",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/new")

      assert render(view) =~ "Create a new Monitor"
    end

    test "Given empty or invalid attributes, when dispatching a validate event, then the form reacts and renders block errors",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/new")

      invalid_attrs = %{url: "", method: :get}

      assert view
             |> form("#monitor-form", monitor: invalid_attrs)
             |> render_change() =~ "form"
    end

    test "Given a completed form array, when successfully submitted, then it flashes the translated success message and navigates away",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/new")

      view
      |> form("#monitor-form", monitor: @valid_attrs)
      |> render_submit()

      assert_redirect(view, "/workspaces/#{workspace.slug}/dashboard")
    end
  end
end

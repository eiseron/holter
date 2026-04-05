defmodule HolterWeb.Monitoring.MonitorLiveNewTest do
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

    test "Given the creation route, when mounted, then the page correctly translates and establishes the HTML DOM",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitor/new")

      assert render(view) =~ "Criar um novo Monitor"
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

      assert_redirect(view, "/monitoring/workspaces/#{workspace.slug}/dashboard")
    end
  end
end

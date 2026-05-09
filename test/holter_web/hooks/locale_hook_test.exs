defmodule HolterWeb.Hooks.LocaleHookTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Holter.I18n.Locale

  setup do
    on_exit(fn -> Gettext.put_locale(HolterWeb.Gettext, "en") end)
    :ok
  end

  describe "URL param tier" do
    test "?locale=pt_BR overrides every other source", %{
      conn: conn,
      current_user: user,
      current_workspace: workspace
    } do
      {:ok, _user} =
        Holter.Identity.update_user_preferences(user, %{preferred_locale: "en"})

      {:ok, lv, _html} =
        live(conn, "/monitoring/workspaces/#{workspace.slug}/monitors?locale=pt_BR")

      assert :sys.get_state(lv.pid).socket.assigns.current_locale == "pt_BR"
    end
  end

  describe "user preference tier" do
    test "uses users.preferred_locale when no URL override", %{
      conn: conn,
      current_user: user,
      current_workspace: workspace
    } do
      {:ok, _user} = Holter.Identity.update_user_preferences(user, %{preferred_locale: "en"})

      {:ok, lv, _html} = live(conn, "/monitoring/workspaces/#{workspace.slug}/monitors")

      assert :sys.get_state(lv.pid).socket.assigns.current_locale == "en"
    end
  end

  describe "workspace default tier" do
    test "uses workspace.default_locale when user has no preference", %{
      conn: conn,
      current_workspace: workspace
    } do
      {:ok, _ws} = Holter.Monitoring.update_workspace(workspace, %{default_locale: "en"})

      {:ok, lv, _html} = live(conn, "/monitoring/workspaces/#{workspace.slug}/monitors")

      assert :sys.get_state(lv.pid).socket.assigns.current_locale == "en"
    end

    test "two workspaces with distinct default_locale render their own UI when the user has none",
         %{conn: conn, current_user: user, current_workspace: workspace_a} do
      {:ok, _ws} = Holter.Monitoring.update_workspace(workspace_a, %{default_locale: "pt_BR"})
      workspace_b = Holter.MonitoringFixtures.workspace_fixture(owner: user, default_locale: "en")

      {:ok, lv_a, html_a} = live(conn, "/monitoring/workspaces/#{workspace_a.slug}/monitors")
      assert :sys.get_state(lv_a.pid).socket.assigns.current_locale == "pt_BR"
      assert html_a =~ "Monitores"
      refute html_a =~ ">Monitors<"

      {:ok, lv_b, html_b} = live(conn, "/monitoring/workspaces/#{workspace_b.slug}/monitors")
      assert :sys.get_state(lv_b.pid).socket.assigns.current_locale == "en"
      assert html_b =~ ">Monitors<"
      refute html_b =~ "Monitores"
    end
  end

  describe "fallback tier" do
    @tag :guest
    test "falls back to the configured default when no user, workspace, or header is present" do
      {:ok, lv, _html} =
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(%{})
        |> live("/identity/login")

      assert :sys.get_state(lv.pid).socket.assigns.current_locale == Locale.default()
    end
  end
end

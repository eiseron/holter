defmodule HolterWeb.Components.LocaleSwitcherTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Holter.Identity

  setup do
    on_exit(fn -> Gettext.put_locale(HolterWeb.Gettext, "en") end)
    :ok
  end

  describe "rendering" do
    test "renders the switcher inside the workspace sidebar", %{
      conn: conn,
      current_workspace: workspace
    } do
      {:ok, _lv, html} =
        live(conn, "/monitoring/workspaces/#{workspace.slug}/monitors")

      assert html =~ "h-sidebar-locale-select"
    end

    test "preselects the current locale", %{
      conn: conn,
      current_user: user,
      current_workspace: workspace
    } do
      {:ok, _user} = Identity.update_user_preferences(user, %{preferred_locale: "en"})

      {:ok, _lv, html} =
        live(conn, "/monitoring/workspaces/#{workspace.slug}/monitors")

      assert html =~ ~s(<option value="en" selected="">)
    end
  end

  describe "change_locale event" do
    test "writes the chosen locale to users.preferred_locale", %{
      conn: conn,
      current_user: user,
      current_workspace: workspace
    } do
      {:ok, lv, _html} =
        live(conn, "/monitoring/workspaces/#{workspace.slug}/monitors")

      lv
      |> element("#locale-switcher form")
      |> render_change(%{"locale" => "pt_BR"})

      assert Identity.get_user!(user.id).preferred_locale == "pt_BR"
    end

    test "navigates so the page re-mounts under the new locale", %{
      conn: conn,
      current_workspace: workspace
    } do
      path = "/monitoring/workspaces/#{workspace.slug}/monitors"
      {:ok, lv, _html} = live(conn, path)

      lv
      |> element("#locale-switcher form")
      |> render_change(%{"locale" => "pt_BR"})

      assert_redirect(lv, path, 1_000)
    end

    test "renders previously-English sidebar copy in Portuguese after the change", %{
      conn: conn,
      current_workspace: workspace
    } do
      path = "/monitoring/workspaces/#{workspace.slug}/monitors"
      {:ok, lv, html} = live(conn, path)

      assert html =~ "Monitors"

      lv
      |> element("#locale-switcher form")
      |> render_change(%{"locale" => "pt_BR"})

      {:ok, _lv, html_after} = live(conn, path)

      assert html_after =~ "Monitores"
    end

    test "ignores an unsupported locale and keeps the row unchanged", %{
      conn: conn,
      current_user: user,
      current_workspace: workspace
    } do
      {:ok, lv, _html} =
        live(conn, "/monitoring/workspaces/#{workspace.slug}/monitors")

      lv
      |> element("#locale-switcher form")
      |> render_change(%{"locale" => "klingon"})

      assert Identity.get_user!(user.id).preferred_locale == nil
    end
  end
end

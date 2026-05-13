defmodule HolterWeb.Web.Workspaces.ShowLiveTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Holter.Monitoring
  alias Holter.Repo

  setup do
    on_exit(fn -> Gettext.put_locale(HolterWeb.Gettext, "en") end)
    :ok
  end

  describe "auth gate" do
    test "lets an :owner reach the workspace page", %{conn: conn, current_workspace: workspace} do
      {:ok, _lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}")
    end

    test "redirects a :member-only user to /", %{
      conn: conn,
      current_user: user,
      current_workspace: workspace
    } do
      [m] = Repo.all(Holter.Identity.Models.WorkspaceMembership)
      assert m.user_id == user.id
      {:ok, _} = m |> Ecto.Changeset.change(role: :member) |> Repo.update()

      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/identity/workspaces/#{workspace.slug}")
    end

    test "redirects when the slug does not exist", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/identity/workspaces/no-such-slug")
    end
  end

  describe "general settings form" do
    test "preselects the current default_locale",
         %{conn: conn, current_workspace: workspace} do
      {:ok, _} = Monitoring.update_workspace(workspace, %{default_locale: "pt_BR"})

      {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}")

      selected_options =
        lv
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find("#workspace-settings-form select option[selected]")

      assert [{"option", attrs, _}] = selected_options
      assert {"value", "pt_BR"} in attrs
    end

    test "persists a valid locale choice", %{conn: conn, current_workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}")

      lv
      |> form("#workspace-settings-form", workspace: %{default_locale: "pt_BR"})
      |> render_submit()

      assert Monitoring.get_workspace!(workspace.id).default_locale == "pt_BR"
    end

    test "ignores an unrecognized locale value submitted out-of-band",
         %{conn: conn, current_workspace: workspace} do
      original = workspace.default_locale
      {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}")

      render_submit(
        element(lv, "#workspace-settings-form"),
        %{"workspace" => %{"default_locale" => "klingon"}}
      )

      assert Monitoring.get_workspace!(workspace.id).default_locale == original
    end
  end

  describe "plan limits panel" do
    test "renders the current max_monitors and max_channels as read-only",
         %{conn: conn, current_workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}")

      refute has_element?(lv, ~s|input[name="workspace[max_monitors]"]|)
      refute has_element?(lv, ~s|input[name="workspace[max_channels]"]|)
    end

    test "rejects out-of-band attempts to raise plan limits",
         %{conn: conn, current_workspace: workspace} do
      original_max = Monitoring.get_workspace_profile!(workspace.id).max_monitors

      {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}")

      render_submit(
        element(lv, "#workspace-settings-form"),
        %{"workspace" => %{"default_locale" => "en", "max_monitors" => "9999"}}
      )

      assert Monitoring.get_workspace_profile!(workspace.id).max_monitors == original_max
    end
  end

  describe "sidebar links" do
    test "marks the Workspace settings link as the active sidebar item",
         %{conn: conn, current_workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}")

      parsed = Floki.parse_fragment!(html)

      active =
        parsed
        |> Floki.find(".h-workspace-sidebar a.h-sidebar-link--active")
        |> Enum.flat_map(fn {"a", attrs, _} ->
          for {"href", h} <- attrs, do: h
        end)

      assert active == ["/identity/workspaces/#{workspace.slug}"]
    end

    test "exposes a My account shortcut to the signed-in user's settings",
         %{conn: conn, current_user: user, current_workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}")

      footer_links =
        html
        |> Floki.parse_fragment!()
        |> Floki.find(".h-sidebar-footer a")
        |> Enum.flat_map(fn {"a", attrs, _} ->
          for {"href", h} <- attrs, do: h
        end)

      assert "/identity/user/#{user.id}" in footer_links
    end
  end
end

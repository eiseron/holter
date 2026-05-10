defmodule HolterWeb.Web.Identity.UserLive.ShowTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Holter.Identity
  alias Holter.Repo

  setup do
    on_exit(fn -> Gettext.put_locale(HolterWeb.Gettext, "en") end)
    :ok
  end

  describe "auth gate" do
    test "redirects unauthenticated visitors to the sign-in page", %{current_user: user} do
      conn = Phoenix.ConnTest.build_conn() |> Plug.Test.init_test_session(%{})

      assert {:error, {:redirect, %{to: "/identity/login"}}} =
               live(conn, ~p"/identity/user/#{user.id}")
    end

    test "redirects when opening another user's settings", %{conn: conn} do
      other = Holter.IdentityFixtures.verified_user_fixture().user

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/identity/user/#{other.id}")
    end
  end

  describe "preferences form" do
    test "preselects the current preferred_locale", %{conn: conn, current_user: user} do
      {:ok, _} = Identity.update_user_preferences(user, %{preferred_locale: "en"})

      {:ok, lv, _html} = live(conn, ~p"/identity/user/#{user.id}")

      selected_options =
        lv
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find("#user-settings-form select option[selected]")

      assert [{"option", attrs, _}] = selected_options
      assert {"value", "en"} in attrs
    end

    test "persists a valid locale choice", %{conn: conn, current_user: user} do
      {:ok, lv, _html} = live(conn, ~p"/identity/user/#{user.id}")

      lv
      |> form("#user-settings-form", preferences: %{preferred_locale: "pt_BR"})
      |> render_submit()

      assert Identity.get_user!(user.id).preferred_locale == "pt_BR"
    end

    test "ignores an unrecognized locale value submitted out-of-band",
         %{conn: conn, current_user: user} do
      {:ok, lv, _html} = live(conn, ~p"/identity/user/#{user.id}")

      render_submit(
        element(lv, "#user-settings-form"),
        %{"preferences" => %{"preferred_locale" => "klingon"}}
      )

      assert Identity.get_user!(user.id).preferred_locale == nil
    end

    test "navigates so the page re-renders under the new locale", %{
      conn: conn,
      current_user: user
    } do
      path = "/identity/user/#{user.id}"
      {:ok, lv, _html} = live(conn, path)

      lv
      |> form("#user-settings-form", preferences: %{preferred_locale: "pt_BR"})
      |> render_submit()

      assert_redirect(lv, path, 1_000)
    end
  end

  describe "sidebar my-account link" do
    test "renders My account in the sidebar footer (same slot as workspace shell)",
         %{conn: conn, current_user: user} do
      {:ok, _lv, html} = live(conn, ~p"/identity/user/#{user.id}")

      footer_links =
        html
        |> Floki.parse_fragment!()
        |> Floki.find(".h-sidebar-footer a")
        |> Enum.flat_map(fn {"a", attrs, _} ->
          for {"href", h} <- attrs, do: h
        end)

      assert footer_links == ["/identity/user/#{user.id}"]
    end

    test "marks the footer link as the active sidebar item",
         %{conn: conn, current_user: user} do
      {:ok, _lv, html} = live(conn, ~p"/identity/user/#{user.id}")

      active_in_footer =
        html
        |> Floki.parse_fragment!()
        |> Floki.find(".h-sidebar-footer a.h-sidebar-link--active")

      assert length(active_in_footer) == 1
    end
  end

  describe "sidebar workspaces list" do
    test "lists every workspace the user belongs to with a clickable link for admin roles",
         %{conn: conn, current_user: user, current_workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/identity/user/#{user.id}")

      sidebar = html |> Floki.parse_fragment!() |> Floki.find(".h-workspace-sidebar")

      assert sidebar |> Floki.text() =~ workspace.name

      hrefs =
        sidebar
        |> Floki.find("a")
        |> Enum.flat_map(fn {"a", attrs, _} ->
          for {"href", h} <- attrs, do: h
        end)

      assert "/identity/workspaces/#{workspace.slug}" in hrefs
    end

    test "renders the workspace name without a link when the user is only a :member",
         %{conn: conn, current_user: user, current_workspace: workspace} do
      [m] = Repo.all(Holter.Identity.Models.WorkspaceMembership)
      {:ok, _} = m |> Ecto.Changeset.change(role: :member) |> Repo.update()

      {:ok, _lv, html} = live(conn, ~p"/identity/user/#{user.id}")

      sidebar = html |> Floki.parse_fragment!() |> Floki.find(".h-workspace-sidebar")

      assert sidebar |> Floki.text() =~ workspace.name

      hrefs =
        sidebar
        |> Floki.find("a")
        |> Enum.flat_map(fn {"a", attrs, _} ->
          for {"href", h} <- attrs, do: h
        end)

      refute "/identity/workspaces/#{workspace.slug}" in hrefs
    end
  end
end

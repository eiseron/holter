defmodule HolterWeb.Web.Workspaces.ApiTokensLiveTest do
  use HolterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Eiseron.Identity.Scopes
  alias Holter.Identity.ApiTokens
  alias Holter.Identity.Models.WorkspaceMembership
  alias Holter.Repo

  setup do
    on_exit(fn -> Gettext.put_locale(HolterWeb.Gettext, "en") end)
    :ok
  end

  defp set_role(user_id, role) do
    [m] = Repo.all(WorkspaceMembership)
    assert m.user_id == user_id
    {:ok, _} = m |> Ecto.Changeset.change(role: role) |> Repo.update()
    :ok
  end

  describe "auth gate" do
    test "redirects a :member to /", %{
      conn: conn,
      current_user: user,
      current_workspace: workspace
    } do
      :ok = set_role(user.id, :member)

      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")
    end

    test "redirects when the slug does not exist", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/identity/workspaces/no-such-slug/api-tokens")
    end
  end

  describe "owner view" do
    test "renders the page title", %{conn: conn, current_workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

      assert html =~ "API tokens"
    end

    test "exposes the create form", %{conn: conn, current_workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

      assert has_element?(lv, "form#new-api-token-form")
    end

    test "lists every advertised scope as a checkbox", %{
      conn: conn,
      current_workspace: workspace
    } do
      {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

      Enum.each(Scopes.all(), fn scope ->
        assert has_element?(
                 lv,
                 ~s(input[type=checkbox][name="api_token[scopes][]"][value="#{scope}"])
               )
      end)
    end
  end

  describe "create_token form" do
    test "reveals the plaintext exactly once after a successful create",
         %{conn: conn, current_workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

      lv
      |> form("#new-api-token-form", api_token: %{name: "CI", scopes: ["read:monitors"]})
      |> render_submit()

      assert has_element?(lv, "[data-testid=new-token-panel]")
    end

    test "the revealed plaintext starts with the `hk_` prefix",
         %{conn: conn, current_workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

      lv
      |> form("#new-api-token-form", api_token: %{name: "CI", scopes: ["read:monitors"]})
      |> render_submit()

      revealed =
        lv
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find("[data-testid=new-token-value] code")
        |> Floki.text()
        |> String.trim()

      assert String.starts_with?(revealed, "hk_")
    end

    test "the new token appears in the active tokens table",
         %{conn: conn, current_workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

      lv
      |> form("#new-api-token-form", api_token: %{name: "Listed token", scopes: ["read:logs"]})
      |> render_submit()

      assert has_element?(lv, "tbody#api-tokens-tbody", "Listed token")
    end

    test "dismissing the plaintext panel hides it on the next render",
         %{conn: conn, current_workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

      lv
      |> form("#new-api-token-form", api_token: %{name: "CI", scopes: ["read:monitors"]})
      |> render_submit()

      render_click(lv, "dismiss_plaintext")

      refute has_element?(lv, "[data-testid=new-token-panel]")
    end

    test "clears the name input after a successful create",
         %{conn: conn, current_workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

      lv
      |> form("#new-api-token-form", api_token: %{name: "CI", scopes: ["read:monitors"]})
      |> render_submit()

      refute has_element?(lv, ~s(#new-api-token-form input[name="api_token[name]"][value="CI"]))
    end

    test "clears every scope checkbox after a successful create",
         %{conn: conn, current_workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

      lv
      |> form("#new-api-token-form",
        api_token: %{name: "CI", scopes: ["read:monitors", "read:logs"]}
      )
      |> render_submit()

      refute has_element?(
               lv,
               ~s(#new-api-token-form input[type=checkbox][name="api_token[scopes][]"][checked])
             )
    end
  end

  describe "humanized scope labels" do
    test "renders a localized label for every advertised scope",
         %{conn: conn, current_workspace: workspace} do
      alias HolterWeb.Web.Workspaces.ApiTokensLive

      {:ok, _lv, html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

      Enum.each(Scopes.all(), fn scope ->
        assert html =~ ApiTokensLive.scope_label(scope)
        assert html =~ ApiTokensLive.scope_description(scope)
      end)
    end

    test "translates the scope labels under pt_BR",
         %{conn: conn, current_user: user, current_workspace: workspace} do
      {:ok, _} = Holter.Identity.update_user_preferences(user, %{preferred_locale: "pt_BR"})

      {:ok, _lv, html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

      assert html =~ "Ver workspace"
      assert html =~ "Gerenciar monitores"
    end
  end

  describe "revoke" do
    test "revoking marks the token as revoked in the listing",
         %{conn: conn, current_user: user, current_workspace: workspace} do
      {:ok, token, _plaintext} =
        ApiTokens.create_token(user, workspace, %{name: "doomed", scopes: Scopes.all()})

      {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

      render_click(lv, "revoke", %{"id" => token.id})

      assert has_element?(lv, "[data-testid=token-status-revoked]")
    end
  end

  describe "admin (non-owner) view" do
    test "hides the form and shows the non-owner notice", %{
      conn: conn,
      current_user: user,
      current_workspace: workspace
    } do
      :ok = set_role(user.id, :admin)

      {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

      assert has_element?(
               lv,
               "section.h-empty-state[data-testid=non-owner-notice] h2",
               "Only workspace owners can manage API tokens"
             )

      refute has_element?(lv, "form#new-api-token-form")
    end
  end

  describe "sidebar links" do
    test "marks the API tokens link as the active sidebar item",
         %{conn: conn, current_workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

      active =
        html
        |> Floki.parse_fragment!()
        |> Floki.find(".h-workspace-sidebar a.h-sidebar-link--active")
        |> Enum.flat_map(fn {"a", attrs, _} ->
          for {"href", h} <- attrs, do: h
        end)

      assert active == ["/identity/workspaces/#{workspace.slug}/api-tokens"]
    end

    test "exposes the API tokens link to admins on other workspace pages",
         %{conn: conn, current_workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}")

      hrefs =
        html
        |> Floki.parse_fragment!()
        |> Floki.find(".h-workspace-sidebar a")
        |> Enum.flat_map(fn {"a", attrs, _} ->
          for {"href", h} <- attrs, do: h
        end)

      assert "/identity/workspaces/#{workspace.slug}/api-tokens" in hrefs
    end

    test "keeps Settings + API tokens visible to admins on a monitor page",
         %{conn: conn, current_workspace: workspace} do
      monitor =
        Holter.MonitoringFixtures.monitor_fixture(
          workspace_id: workspace.id,
          interval_seconds: workspace.monitoring_profile.min_interval_seconds
        )

      {:ok, _lv, html} = live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      hrefs =
        html
        |> Floki.parse_fragment!()
        |> Floki.find(".h-workspace-sidebar a")
        |> Enum.flat_map(fn {"a", attrs, _} ->
          for {"href", h} <- attrs, do: h
        end)

      assert "/identity/workspaces/#{workspace.slug}" in hrefs
      assert "/identity/workspaces/#{workspace.slug}/api-tokens" in hrefs
    end
  end
end

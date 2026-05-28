defmodule HolterWeb.Web.Workspaces.ApiTokensLiveRLSTest do
  @moduledoc """
  Mounts the API tokens LiveView under the `holter_app` Postgres role
  with RLS enforced. The default `ApiTokensLiveTest` runs under the
  superuser sandbox (BYPASSRLS), so a regression that drops the tenant
  stamp from `Holter.Identity.ApiTokens` would not be caught there —
  the queries would silently succeed in test and silently return zero
  rows in production.

  These tests cover the three runtime entry points the LiveView calls:
  `list_tokens_for_workspace/1` (mount), `create_token/3` and
  `revoke_token/1` (handle_event). They rely on the `LiveTenancy`
  boundary stamping `app.current_workspace_id` for the whole callback;
  if the boundary is removed or the route is detached from
  `:workspace_live_view`, every assertion below blows up.
  """

  use HolterWeb.RLSConnCase

  import Phoenix.LiveViewTest

  alias Eiseron.Identity.Scopes
  alias Holter.Identity.ApiTokens

  setup %{current_user: user, current_workspace: workspace} do
    {:ok, existing, _plaintext} =
      ApiTokens.create_token(user, workspace, %{
        name: "Pre-existing",
        scopes: ["read:monitors"]
      })

    setup_app_role()

    %{existing_token: existing}
  end

  test "mount lists pre-existing tokens under RLS",
       %{conn: conn, current_workspace: workspace} do
    {:ok, _lv, html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

    assert html =~ "Pre-existing"
  end

  test "create_token persists and reveals plaintext under RLS",
       %{conn: conn, current_workspace: workspace} do
    {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

    lv
    |> form("#new-api-token-form",
      api_token: %{name: "Created under RLS", scopes: Scopes.all()}
    )
    |> render_submit()

    assert has_element?(lv, "[data-testid=new-token-panel]")
    assert has_element?(lv, "tbody#api-tokens-tbody", "Created under RLS")
  end

  test "revoke_token marks the token as revoked under RLS",
       %{conn: conn, current_workspace: workspace, existing_token: token} do
    {:ok, lv, _html} = live(conn, ~p"/identity/workspaces/#{workspace.slug}/api-tokens")

    render_click(lv, "revoke", %{"id" => token.id})

    assert has_element?(lv, "[data-testid=token-status-revoked]")
  end
end

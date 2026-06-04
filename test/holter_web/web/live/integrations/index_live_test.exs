defmodule HolterWeb.Web.Integrations.IndexLiveTest do
  use HolterWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Holter.Repo.Tenant

  setup %{current_user: user} do
    workspace = workspace_fixture_for(user)
    %{workspace: workspace}
  end

  describe "mount" do
    test "Given no integrations, when mounted, then an empty state is rendered",
         %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}")

      assert has_element?(lv, ".h-empty-state")
    end

    test "Given a connected integration, when mounted, then it appears in the list",
         %{conn: conn, workspace: workspace, current_user: user} do
      integration =
        Tenant.with_user!(user, fn ->
          integration_fixture(%{
            workspace_id: workspace.id,
            provider: :google_ads,
            status: :active,
            name: "GAds — Black Friday"
          })
        end)

      {:ok, _lv, html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}")

      assert html =~ "GAds — Black Friday"
      assert html =~ integration.id
    end

    test "Given any state, when mounted, then an Add integration link is present",
         %{conn: conn, workspace: workspace} do
      {:ok, lv, _html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}")

      assert has_element?(lv, "[data-role='add-integration-button']")
    end
  end

  describe "status badges" do
    test "Given an active integration, when mounted, then Connected is shown",
         %{conn: conn, workspace: workspace, current_user: user} do
      Tenant.with_user!(user, fn ->
        integration_fixture(%{workspace_id: workspace.id, provider: :google_ads, status: :active})
      end)

      {:ok, _lv, html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}")

      assert html =~ "Connected"
    end

    test "Given a reauth_required integration, when mounted, then Reconnect needed is shown",
         %{conn: conn, workspace: workspace, current_user: user} do
      Tenant.with_user!(user, fn ->
        integration_fixture(%{
          workspace_id: workspace.id,
          provider: :google_ads,
          status: :reauth_required
        })
      end)

      {:ok, _lv, html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}")

      assert html =~ "Reconnect needed"
    end

    test "Given a rate_limited integration, when mounted, then Rate limited is shown",
         %{conn: conn, workspace: workspace, current_user: user} do
      Tenant.with_user!(user, fn ->
        integration_fixture(%{
          workspace_id: workspace.id,
          provider: :slack,
          status: :rate_limited
        })
      end)

      {:ok, _lv, html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}")

      assert html =~ "Rate limited"
    end

    test "Given a disabled integration, when mounted, then Disabled is shown",
         %{conn: conn, workspace: workspace, current_user: user} do
      Tenant.with_user!(user, fn ->
        integration_fixture(%{
          workspace_id: workspace.id,
          provider: :pagerduty,
          status: :disabled
        })
      end)

      {:ok, _lv, html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}")

      assert html =~ "Disabled"
    end

    test "Given a provider_down integration, when mounted, then Provider down is shown",
         %{conn: conn, workspace: workspace, current_user: user} do
      Tenant.with_user!(user, fn ->
        integration_fixture(%{
          workspace_id: workspace.id,
          provider: :linear,
          status: :provider_down
        })
      end)

      {:ok, _lv, html} = live(conn, ~p"/integrations/workspaces/#{workspace.slug}")

      assert html =~ "Provider down"
    end
  end

  describe "access control" do
    test "Given an unauthenticated user, when accessing the page, then they are redirected",
         %{workspace: workspace} do
      conn = build_conn()

      assert {:error, {:redirect, %{to: "/identity/login"}}} =
               live(conn, ~p"/integrations/workspaces/#{workspace.slug}")
    end
  end
end

defmodule HolterWeb.Components.WorkspaceSidebarLiveRLSTest do
  @moduledoc """
  Regression coverage for the bug where sidebar count badges showed `0`
  on the preview deploy of !70 ("trust the boundary"). The component is
  a `Phoenix.LiveComponent`, whose `update/2` runs during the parent's
  render diff — *after* the `LiveTenancy` callback wrap has returned
  and the `Repo.checkout` connection has been released. Without an
  explicit `Tenant.with_workspace!/2` inside `update/2`, the count
  queries hit RLS with no tenant stamped and return zero.

  These tests run under the `holter_app` Postgres role with RLS
  enforced and assert the rendered badge values match the workspace's
  actual counts.
  """

  use HolterWeb.RLSConnCase

  import Phoenix.LiveViewTest

  alias Holter.Delivery.{EmailChannels, WebhookChannels}

  setup %{current_user: user} do
    workspace = workspace_fixture_for(user)

    monitor_fixture(%{workspace_id: workspace.id, url: "https://one.local"})
    monitor_fixture(%{workspace_id: workspace.id, url: "https://two.local"})
    monitor_fixture(%{workspace_id: workspace.id, url: "https://three.local"})

    {:ok, _} =
      WebhookChannels.create(%{
        workspace_id: workspace.id,
        name: "Hook",
        url: "https://hooks.example/h"
      })

    {:ok, _} =
      EmailChannels.create(%{workspace_id: workspace.id, name: "Email"})

    integration_fixture(%{workspace_id: workspace.id, provider: :google_ads})
    integration_fixture(%{workspace_id: workspace.id, provider: :meta_ads})

    stranger = user_fixture()
    stranger_workspace = workspace_fixture(%{owner: stranger})
    monitor_fixture(%{workspace_id: stranger_workspace.id, url: "https://stranger.local"})

    setup_app_role()

    %{workspace: workspace}
  end

  test "sidebar renders the monitor count/max badge when at quota under RLS",
       %{conn: conn, workspace: workspace} do
    {:ok, _view, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

    assert html =~ ~r{<span class="h-sidebar-badge">\s*3/3\s*</span>}
  end

  test "sidebar renders the combined channel count/max badge when at quota under RLS",
       %{conn: conn, workspace: workspace} do
    {:ok, _view, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

    assert html =~ ~r{<span class="h-sidebar-badge">\s*2/2\s*</span>}
  end

  test "sidebar renders the integration count badge under RLS",
       %{conn: conn, workspace: workspace} do
    {:ok, _view, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

    assert html =~ ~r{<span class="h-sidebar-badge">\s*2\s*</span>}
  end

  test "sidebar counts do not leak across workspaces", %{conn: conn, workspace: workspace} do
    {:ok, _view, html} = live(conn, ~p"/monitoring/workspaces/#{workspace.slug}/monitors")

    refute html =~ "stranger.local"
  end
end

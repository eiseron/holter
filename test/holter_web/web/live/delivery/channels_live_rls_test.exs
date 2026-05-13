defmodule HolterWeb.Web.Delivery.ChannelsLiveRLSTest do
  @moduledoc """
  Mounts the delivery channels list under the `holter_app` Postgres
  role with RLS enforced. Catches two classes of regression in one
  test:

    * The list LiveView's `mount/3` data fetches (`WebhookChannels.list/1`,
      `EmailChannels.list/1`) — without the `LiveTenancy` callback wrap,
      RLS would return empty and the test would see no channels.
    * The sidebar component (`WorkspaceSidebarLive`) — its `update/2`
      runs during render diff outside the parent's wrap; without an
      explicit stamp the badge counts would be `0`.

  Together these guarantee that `/delivery/workspaces/:slug/channels`
  works end-to-end under the role production actually uses.
  """

  use HolterWeb.RLSConnCase

  import Phoenix.LiveViewTest

  alias Holter.Delivery.{EmailChannels, WebhookChannels}

  setup %{current_user: user} do
    workspace = workspace_fixture_for(user)

    {:ok, _} =
      WebhookChannels.create(%{
        workspace_id: workspace.id,
        name: "Ops Hook",
        url: "https://hooks.example/ops"
      })

    {:ok, _} =
      EmailChannels.create(%{workspace_id: workspace.id, name: "Ops Email"})

    setup_app_role()

    %{workspace: workspace}
  end

  test "channels list renders both subtypes under RLS",
       %{conn: conn, workspace: workspace} do
    {:ok, _view, html} = live(conn, ~p"/delivery/workspaces/#{workspace.slug}/channels")

    assert html =~ "Ops Hook"
    assert html =~ "Ops Email"
  end

  test "sidebar badge on the channels page shows the workspace's combined count",
       %{conn: conn, workspace: workspace} do
    {:ok, _view, html} = live(conn, ~p"/delivery/workspaces/#{workspace.slug}/channels")

    assert html =~ ~r{<span class="h-sidebar-badge">\s*2/2\s*</span>}
  end
end

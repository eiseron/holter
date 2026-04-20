defmodule HolterWeb.Web.WorkspaceDashboard.ChannelsLiveTest do
  use HolterWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Holter.Delivery

  setup do
    workspace = workspace_fixture()
    %{workspace: workspace}
  end

  defp channel_fixture(workspace_id, attrs \\ %{}) do
    {:ok, channel} =
      Delivery.create_channel(
        Map.merge(
          %{
            workspace_id: workspace_id,
            name: "Test Hook",
            type: :webhook,
            target: "https://example.com/hook"
          },
          attrs
        )
      )

    channel
  end

  describe "mount" do
    test "Given a valid workspace slug, when mounted, then the page renders",
         %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/workspaces/#{workspace.slug}/channels")

      assert html =~ "Notification Channels"
    end

    test "Given an invalid workspace slug, when mounted, then it redirects with an error",
         %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/"}}} =
               live(conn, ~p"/workspaces/nonexistent-slug/channels")
    end

    test "Given a workspace with no channels, when mounted, then the empty state is shown",
         %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/workspaces/#{workspace.slug}/channels")

      assert html =~ "No notification channels yet"
    end

    test "Given a workspace with channels, when mounted, then channels are listed",
         %{conn: conn, workspace: workspace} do
      channel_fixture(workspace.id, %{name: "My Webhook"})

      {:ok, _lv, html} = live(conn, ~p"/workspaces/#{workspace.slug}/channels")

      assert html =~ "My Webhook"
    end
  end

  describe "sidebar counts" do
    test "sidebar shows monitor count and channel count",
         %{conn: conn, workspace: workspace} do
      monitor_fixture(%{workspace_id: workspace.id})
      channel_fixture(workspace.id)

      {:ok, _lv, html} = live(conn, ~p"/workspaces/#{workspace.slug}/channels")

      assert html =~ "Monitors"
      assert html =~ "Channels"
    end
  end
end

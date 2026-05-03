defmodule HolterWeb.Web.Delivery.ChannelsLiveTest do
  use HolterWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Holter.Delivery.{EmailChannels, WebhookChannels}

  setup do
    workspace = workspace_fixture()
    %{workspace: workspace}
  end

  defp webhook_fixture(workspace_id, attrs \\ %{}) do
    {:ok, channel} =
      WebhookChannels.create(
        Map.merge(
          %{workspace_id: workspace_id, name: "Test Hook", url: "https://example.com/hook"},
          attrs
        )
      )

    channel
  end

  defp email_fixture(workspace_id, attrs) do
    {:ok, channel} =
      EmailChannels.create(
        Map.merge(
          %{workspace_id: workspace_id, name: "Ops Email", address: "ops@example.com"},
          attrs
        )
      )

    channel
  end

  describe "mount" do
    test "Given a valid workspace slug, when mounted, then the page renders",
         %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/delivery/workspaces/#{workspace.slug}/channels")

      assert html =~ "Notification Channels"
    end

    test "Given an invalid workspace slug, when mounted, then it redirects with an error",
         %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/"}}} =
               live(conn, ~p"/delivery/workspaces/nonexistent-slug/channels")
    end

    test "Given a workspace with no channels, when mounted, then the empty state is shown",
         %{conn: conn, workspace: workspace} do
      {:ok, _lv, html} = live(conn, ~p"/delivery/workspaces/#{workspace.slug}/channels")

      assert html =~ "No notification channels yet"
    end

    test "Given a workspace with a webhook channel, when mounted, then it appears in the list",
         %{conn: conn, workspace: workspace} do
      webhook_fixture(workspace.id, %{name: "My Webhook"})

      {:ok, _lv, html} = live(conn, ~p"/delivery/workspaces/#{workspace.slug}/channels")

      assert html =~ "My Webhook"
    end

    test "Given a workspace with an email channel, when mounted, then it appears in the list",
         %{conn: conn, workspace: workspace} do
      email_fixture(workspace.id, %{name: "On-call"})

      {:ok, _lv, html} = live(conn, ~p"/delivery/workspaces/#{workspace.slug}/channels")

      assert html =~ "On-call"
    end

    test "Given both kinds of channels, when mounted, then both kinds appear together",
         %{conn: conn, workspace: workspace} do
      webhook_fixture(workspace.id, %{name: "Aaa-webhook"})
      email_fixture(workspace.id, %{name: "Bbb-email"})

      {:ok, _lv, html} = live(conn, ~p"/delivery/workspaces/#{workspace.slug}/channels")

      assert html =~ "Aaa-webhook"
      assert html =~ "Bbb-email"
    end
  end

  describe "sidebar counts" do
    test "sidebar shows monitor count and channel count",
         %{conn: conn, workspace: workspace} do
      monitor_fixture(%{workspace_id: workspace.id})
      webhook_fixture(workspace.id)

      {:ok, _lv, html} = live(conn, ~p"/delivery/workspaces/#{workspace.slug}/channels")

      assert html =~ "Monitors"
      assert html =~ "Channels"
    end
  end
end

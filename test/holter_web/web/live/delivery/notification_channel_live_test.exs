defmodule HolterWeb.Web.Delivery.NotificationChannelLiveTest do
  use HolterWeb.ConnCase
  use Oban.Testing, repo: Holter.Repo

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

  describe "New" do
    test "renders creation form", %{conn: conn, workspace: workspace} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      assert html =~ "New Notification Channel"
      assert html =~ "notification-channel-form"
    end

    test "validates required fields on change", %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      html =
        view
        |> form("#notification-channel-form", notification_channel: %{name: ""})
        |> render_change()

      assert html =~ "notification-channel-form"
    end

    test "creates channel and redirects to workspace channels on valid submit", %{
      conn: conn,
      workspace: workspace
    } do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/new")

      view
      |> form("#notification-channel-form",
        notification_channel: %{
          name: "My Hook",
          type: "webhook",
          target: "https://hooks.example.com/notify"
        }
      )
      |> render_submit()

      assert_redirect(view, "/workspaces/#{workspace.slug}/channels")
    end
  end

  describe "Show" do
    test "renders channel edit form", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert html =~ channel.name
      assert html =~ "notification-channel-form"
    end

    test "updates channel name on valid submit", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      view
      |> form("#notification-channel-form", notification_channel: %{name: "Renamed"})
      |> render_submit()

      assert render(view) =~ "Channel updated successfully"
      assert Delivery.get_channel!(channel.id).name == "Renamed"
    end

    test "enqueues test notification on test event", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      view
      |> element("button[phx-click='test']")
      |> render_click()

      assert_enqueued(
        worker: Holter.Delivery.Workers.WebhookDispatcher,
        args: %{"test" => true, "channel_id" => channel.id}
      )
    end

    test "links monitors to channel on save", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      view
      |> form("#notification-channel-form", notification_channel: %{name: channel.name})
      |> render_submit(%{"monitor_ids" => [monitor.id]})

      assert monitor.id in Delivery.list_monitor_ids_for_channel(channel.id)
    end

    test "unlinks monitors from channel when unchecked on save", %{
      conn: conn,
      workspace: workspace
    } do
      channel = channel_fixture(workspace.id)
      monitor = monitor_fixture(%{workspace_id: workspace.id})
      Delivery.link_monitor(monitor.id, channel.id)

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      view
      |> form("#notification-channel-form", notification_channel: %{name: channel.name})
      |> render_submit(%{"monitor_ids" => []})

      refute monitor.id in Delivery.list_monitor_ids_for_channel(channel.id)
    end

    test "renders linked monitors as checked checkboxes", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)
      monitor = monitor_fixture(%{workspace_id: workspace.id})
      Delivery.link_monitor(monitor.id, channel.id)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert html =~ "value=\"#{monitor.id}\" checked"
    end
  end
end

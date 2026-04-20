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

  describe "Index" do
    test "lists channels for workspace", %{conn: conn, workspace: workspace} do
      channel_fixture(workspace.id)

      {:ok, _view, html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels")

      assert html =~ "Test Hook"
    end

    test "shows empty state when no channels", %{conn: conn, workspace: workspace} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels")

      assert html =~ "No notification channels yet"
    end

    test "deletes a channel on delete event", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)

      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels")

      view
      |> element("button[phx-click='delete'][phx-value-id='#{channel.id}']")
      |> render_click()

      assert {:error, :not_found} = Delivery.get_channel(channel.id)
    end

    test "shows link to create new channel", %{conn: conn, workspace: workspace} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/notification-channels")

      assert html =~ "New Channel"
    end
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

    test "creates channel and redirects on valid submit", %{conn: conn, workspace: workspace} do
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

      assert_redirect(
        view,
        "/delivery/workspaces/#{workspace.slug}/notification-channels"
      )
    end
  end

  describe "Show" do
    test "renders channel edit form", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)

      {:ok, _view, html} =
        live(
          conn,
          ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/#{channel.id}"
        )

      assert html =~ channel.name
      assert html =~ "notification-channel-form"
    end

    test "updates channel name on valid submit", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)

      {:ok, view, _html} =
        live(
          conn,
          ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/#{channel.id}"
        )

      view
      |> form("#notification-channel-form", notification_channel: %{name: "Renamed"})
      |> render_submit()

      assert render(view) =~ "Channel updated successfully"
      assert Delivery.get_channel!(channel.id).name == "Renamed"
    end

    test "enqueues test notification on test event", %{conn: conn, workspace: workspace} do
      channel = channel_fixture(workspace.id)

      {:ok, view, _html} =
        live(
          conn,
          ~p"/delivery/workspaces/#{workspace.slug}/notification-channels/#{channel.id}"
        )

      view
      |> element("button[phx-click='test']")
      |> render_click()

      assert_enqueued(
        worker: Holter.Delivery.Workers.WebhookDispatcher,
        args: %{"test" => true, "channel_id" => channel.id}
      )
    end
  end
end

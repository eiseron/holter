defmodule HolterWeb.Web.Delivery.WebhookChannelLive.ShowTest do
  use HolterWeb.ConnCase
  use Oban.Testing, repo: Holter.Repo

  import Phoenix.LiveViewTest

  alias Holter.Delivery.WebhookChannels

  setup do
    workspace = workspace_fixture()

    {:ok, channel} =
      WebhookChannels.create(%{
        workspace_id: workspace.id,
        name: "Test Hook",
        url: "https://example.com/hook"
      })

    %{workspace: workspace, channel: channel}
  end

  describe "mount" do
    test "renders the channel name in the page header",
         %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/delivery/webhook-channels/#{channel.id}")

      assert html =~ channel.name
    end

    test "renders the edit form", %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/delivery/webhook-channels/#{channel.id}")

      assert html =~ "webhook-channel-form"
    end

    test "renders the View Logs link", %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/delivery/webhook-channels/#{channel.id}")

      assert html =~ "/delivery/webhook-channels/#{channel.id}/logs"
    end
  end

  describe "save event" do
    test "updates the channel name on valid submit",
         %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/delivery/webhook-channels/#{channel.id}")

      view
      |> form("#webhook-channel-form", webhook_channel: %{name: "Renamed"})
      |> render_submit()

      assert WebhookChannels.get!(channel.id).name == "Renamed"
    end

    test "links selected monitors", %{conn: conn, workspace: workspace, channel: channel} do
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      {:ok, view, _html} = live(conn, ~p"/delivery/webhook-channels/#{channel.id}")

      view
      |> form("#webhook-channel-form", webhook_channel: %{name: channel.name})
      |> render_submit(%{"monitor_ids" => [monitor.id]})

      assert monitor.id in WebhookChannels.list_monitor_ids_for(channel.id)
    end

    test "unlinks monitors when unchecked",
         %{conn: conn, workspace: workspace, channel: channel} do
      monitor = monitor_fixture(%{workspace_id: workspace.id})
      WebhookChannels.link_monitor(monitor.id, channel.id)

      {:ok, view, _html} = live(conn, ~p"/delivery/webhook-channels/#{channel.id}")

      view
      |> form("#webhook-channel-form", webhook_channel: %{name: channel.name})
      |> render_submit(%{"monitor_ids" => []})

      refute monitor.id in WebhookChannels.list_monitor_ids_for(channel.id)
    end
  end

  describe "test dispatch" do
    test "enqueues a webhook test job with the channel id",
         %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/delivery/webhook-channels/#{channel.id}")

      view |> element("button[phx-click='test']") |> render_click()

      assert_enqueued(
        worker: Holter.Delivery.Workers.WebhookDispatcher,
        args: %{"test" => true, "webhook_channel_id" => channel.id}
      )
    end

    test "Send Test button shows a wait countdown after a successful dispatch",
         %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/delivery/webhook-channels/#{channel.id}")

      view |> element("button[phx-click='test']") |> render_click()

      assert render(view) =~ ~r/Wait \d+s/
    end

    test "Send Test button shows the cooldown if the channel was pinged recently before mount",
         %{conn: conn, channel: channel} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      channel
      |> Ecto.Changeset.change(last_test_dispatched_at: now)
      |> Holter.Repo.update!()

      {:ok, _view, html} = live(conn, ~p"/delivery/webhook-channels/#{channel.id}")

      assert html =~ ~r/Wait \d+s/
    end
  end

  describe "regenerate signing token" do
    test "rotates the token on confirmation",
         %{conn: conn, channel: channel} do
      original = channel.signing_token

      {:ok, view, _html} = live(conn, ~p"/delivery/webhook-channels/#{channel.id}")

      render_click(view, "regenerate_secret", %{})

      assert WebhookChannels.get!(channel.id).signing_token != original
    end
  end

  describe "delete" do
    test "deletes the channel and redirects to the workspace channels list",
         %{conn: conn, workspace: workspace, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/delivery/webhook-channels/#{channel.id}")

      view |> element("button[phx-click='delete_channel']") |> render_click()

      assert_redirect(view, "/delivery/workspaces/#{workspace.slug}/channels")
      assert {:error, :not_found} = WebhookChannels.get(channel.id)
    end
  end
end

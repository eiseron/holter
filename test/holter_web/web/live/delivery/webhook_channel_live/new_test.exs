defmodule HolterWeb.Web.Delivery.WebhookChannelLive.NewTest do
  use HolterWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Holter.Delivery.WebhookChannels

  setup do
    workspace = workspace_fixture()
    %{workspace: workspace}
  end

  describe "mount" do
    test "renders the create form", %{conn: conn, workspace: workspace} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/webhook-channels/new")

      assert html =~ "New Webhook Channel"
      assert html =~ "webhook-channel-form"
    end
  end

  describe "validate event" do
    test "renders the form again on change", %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/webhook-channels/new")

      html =
        view
        |> form("#webhook-channel-form", webhook_channel: %{name: ""})
        |> render_change()

      assert html =~ "webhook-channel-form"
    end
  end

  describe "save event" do
    test "creates the channel and redirects to the workspace channels list",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/webhook-channels/new")

      view
      |> form("#webhook-channel-form",
        webhook_channel: %{name: "My Hook", url: "https://hooks.example.com/notify"}
      )
      |> render_submit()

      assert_redirect(view, "/delivery/workspaces/#{workspace.slug}/channels")
    end

    test "persists the channel under the given workspace",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/webhook-channels/new")

      view
      |> form("#webhook-channel-form",
        webhook_channel: %{name: "My Hook", url: "https://hooks.example.com/notify"}
      )
      |> render_submit()

      assert [%{name: "My Hook"}] = WebhookChannels.list(workspace.id)
    end

    test "links selected monitors on creation", %{conn: conn, workspace: workspace} do
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/webhook-channels/new")

      view
      |> form("#webhook-channel-form",
        webhook_channel: %{name: "My Hook", url: "https://hooks.example.com/notify"}
      )
      |> render_submit(%{"monitor_ids" => [monitor.id]})

      [channel] = WebhookChannels.list(workspace.id)
      assert monitor.id in WebhookChannels.list_monitor_ids_for(channel.id)
    end

    test "rejects invalid URLs with a 422-shape changeset error in the rendered form",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/webhook-channels/new")

      html =
        view
        |> form("#webhook-channel-form",
          webhook_channel: %{name: "My Hook", url: "http://localhost/h"}
        )
        |> render_submit()

      assert html =~ "must be a valid http or https URL"
    end
  end
end

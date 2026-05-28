defmodule HolterWeb.Web.Delivery.EmailChannelLive.LogsTest do
  use HolterWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Holter.Delivery.EmailChannels

  setup %{current_workspace: workspace} do
    {:ok, channel} = EmailChannels.create(%{workspace_id: workspace.id, name: "Ops Email"})
    %{channel: channel}
  end

  describe "mount" do
    test "renders the delivery logs page with channel name",
         %{conn: conn, channel: channel} do
      {:ok, _lv, html} =
        live(conn, ~p"/delivery/email-channels/#{channel.id}/logs")

      assert html =~ "Delivery Logs"
      assert html =~ channel.name
    end

    test "redirects when the channel does not exist",
         %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/delivery/email-channels/#{Ecto.UUID.generate()}/logs")
    end
  end

  describe "filter_updated event" do
    test "patches the URL with the submitted filter values",
         %{conn: conn, channel: channel} do
      {:ok, lv, _html} =
        live(conn, ~p"/delivery/email-channels/#{channel.id}/logs")

      render_change(lv, "filter_updated", %{"filters" => %{"status" => "completed"}})

      assert_patch(lv)
    end
  end
end

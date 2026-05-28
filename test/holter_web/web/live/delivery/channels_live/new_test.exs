defmodule HolterWeb.Web.Delivery.ChannelsLive.NewTest do
  use HolterWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "mount" do
    test "renders the channel type picker for a valid workspace",
         %{conn: conn, current_workspace: workspace} do
      {:ok, _lv, html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/channels/new")

      assert html =~ "New Channel"
      assert html =~ "Webhook channel"
      assert html =~ "Email channel"
    end

    test "includes links to webhook and email channel creation",
         %{conn: conn, current_workspace: workspace} do
      {:ok, lv, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/channels/new")

      assert has_element?(
               lv,
               ~s|a[href="/delivery/workspaces/#{workspace.slug}/webhook-channels/new"]|
             )

      assert has_element?(
               lv,
               ~s|a[href="/delivery/workspaces/#{workspace.slug}/email-channels/new"]|
             )
    end

    test "redirects when the workspace slug does not exist",
         %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/delivery/workspaces/no-such-workspace/channels/new")
    end
  end
end

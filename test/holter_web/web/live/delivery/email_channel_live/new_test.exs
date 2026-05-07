defmodule HolterWeb.Web.Delivery.EmailChannelLive.NewTest do
  use HolterWeb.ConnCase
  use Oban.Testing, repo: Holter.Repo

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Holter.Delivery.EmailChannels

  setup do
    workspace = workspace_fixture()
    %{workspace: workspace}
  end

  defp submit_recipient(view, email) do
    view
    |> form("#add-recipient-form", %{"recipient" => %{"email" => email}})
    |> render_submit()
  end

  describe "mount" do
    test "renders the create form", %{conn: conn, workspace: workspace} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      assert html =~ "New Email Channel"
      assert html =~ "email-channel-form"
    end

    test "shows the recipients section by default",
         %{conn: conn, workspace: workspace} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      assert html =~ "Recipients"
      assert html =~ "Add Recipient"
    end
  end

  describe "save event" do
    test "creates the email channel and redirects to the workspace channels list",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      view
      |> form("#email-channel-form", email_channel: %{name: "Ops"})
      |> render_submit()

      assert_redirect(view, "/delivery/workspaces/#{workspace.slug}/channels")
    end

    test "delivers verification emails to pending recipients on creation",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      submit_recipient(view, "extra@example.com")

      view
      |> form("#email-channel-form", email_channel: %{name: "Ops"})
      |> render_submit()

      assert_email_sent(to: "extra@example.com")
    end

    test "links selected monitors on creation",
         %{conn: conn, workspace: workspace} do
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      view
      |> form("#email-channel-form", email_channel: %{name: "Ops"})
      |> render_submit(%{"monitor_ids" => [monitor.id]})

      [channel] = EmailChannels.list(workspace.id)
      assert monitor.id in EmailChannels.list_monitor_ids_for(channel.id)
    end
  end

  describe "pending recipients list" do
    test "adds a valid email to the pending list",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      html = submit_recipient(view, "extra@example.com")
      assert html =~ "extra@example.com"
    end

    test "ignores invalid email entries",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      html = submit_recipient(view, "notanemail")
      refute html =~ "notanemail"
    end

    test "ignores duplicate entries",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      submit_recipient(view, "extra@example.com")
      html = submit_recipient(view, "extra@example.com")

      assert [_] = Regex.scan(~r/h-recipient-item/, html)
    end
  end
end

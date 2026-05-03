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

  describe "mount" do
    test "renders the create form", %{conn: conn, workspace: workspace} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      assert html =~ "New Email Channel"
      assert html =~ "email-channel-form"
    end

    test "shows the CC recipients section by default",
         %{conn: conn, workspace: workspace} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      assert html =~ "CC Recipients"
    end
  end

  describe "save event" do
    test "creates the email channel and redirects to the workspace channels list",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      view
      |> form("#email-channel-form",
        email_channel: %{name: "Ops", address: "ops@example.com"}
      )
      |> render_submit()

      assert_redirect(view, "/delivery/workspaces/#{workspace.slug}/channels")
    end

    test "sends a verification email to the primary address on creation",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      view
      |> form("#email-channel-form",
        email_channel: %{name: "Ops", address: "ops@example.com"}
      )
      |> render_submit()

      assert_email_sent(to: "ops@example.com")
    end

    test "delivers verification emails to pending CC recipients on creation",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      render_click(view, "add_pending_cc", %{"email" => "cc@example.com"})

      view
      |> form("#email-channel-form",
        email_channel: %{name: "Ops", address: "ops@example.com"}
      )
      |> render_submit()

      assert_email_sent(to: "cc@example.com")
    end

    test "links selected monitors on creation",
         %{conn: conn, workspace: workspace} do
      monitor = monitor_fixture(%{workspace_id: workspace.id})

      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      view
      |> form("#email-channel-form",
        email_channel: %{name: "Ops", address: "ops@example.com"}
      )
      |> render_submit(%{"monitor_ids" => [monitor.id]})

      [channel] = EmailChannels.list(workspace.id)
      assert monitor.id in EmailChannels.list_monitor_ids_for(channel.id)
    end
  end

  describe "pending CC list" do
    test "adds a valid email to the pending list",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      html = render_click(view, "add_pending_cc", %{"email" => "cc@example.com"})
      assert html =~ "cc@example.com"
    end

    test "ignores invalid email entries",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      html = render_click(view, "add_pending_cc", %{"email" => "notanemail"})
      refute html =~ "notanemail"
    end

    test "ignores duplicate entries",
         %{conn: conn, workspace: workspace} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/workspaces/#{workspace.slug}/email-channels/new")

      render_click(view, "add_pending_cc", %{"email" => "cc@example.com"})
      html = render_click(view, "add_pending_cc", %{"email" => "cc@example.com"})

      assert [_] = Regex.scan(~r/h-recipient-item/, html)
    end
  end
end

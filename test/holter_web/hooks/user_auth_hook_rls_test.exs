defmodule HolterWeb.Hooks.UserAuthHookRLSTest do
  @moduledoc """
  Regression coverage for the per-resource auth hooks
  (`:require_log_member`, `:require_incident_member`,
  `:require_webhook_channel_member`, `:require_email_channel_member`)
  under the `holter_app` Postgres role with RLS actually enforced.

  These routes do NOT carry `:workspace_slug` in the URL, so the hook
  cannot stamp a workspace before it fetches the resource. It must
  stamp the user (`Tenant.with_user!`) so that the membership-keyed
  branch on each table's USING clause lets the row through. Without
  that wrap (or without the user-keyed branch on the policy), every
  fetch returns `:not_found`, the hook halts and redirects to `/`,
  and the user lands on their first workspace's monitor list — which
  is exactly the bug we're regression-pinning.

  The default ConnCase sandbox runs as `postgres` (BYPASSRLS) and
  would silently pass even without the wrapping. `RLSConnCase` plus
  `setup_app_role/0` switches the connection to `holter_app`, so the
  policies actually fire and a missing `with_user!` would surface as
  the redirect under test, not in production only.
  """

  use HolterWeb.RLSConnCase
  use Oban.Testing, repo: Holter.Repo

  import Phoenix.LiveViewTest

  alias Holter.Delivery.{EmailChannels, WebhookChannels}

  describe "/monitoring/logs/:log_id under holter_app" do
    setup %{current_user: user} do
      workspace = workspace_fixture_for(user)
      monitor = monitor_fixture(%{workspace_id: workspace.id, url: "https://logs.local"})
      log = log_fixture(%{monitor_id: monitor.id})

      stranger = user_fixture()
      stranger_workspace = workspace_fixture(%{owner: stranger})
      stranger_monitor = monitor_fixture(%{workspace_id: stranger_workspace.id})
      stranger_log = log_fixture(%{monitor_id: stranger_monitor.id})

      setup_app_role()

      %{log: log, stranger_log: stranger_log}
    end

    test "the auth hook resolves the log for a workspace member", %{conn: conn, log: log} do
      {:ok, _view, html} = live(conn, ~p"/monitoring/logs/#{log.id}")

      assert html =~ "https://logs.local"
    end

    test "the auth hook redirects to / when the user is not a member of the log's workspace",
         %{conn: conn, stranger_log: stranger_log} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/monitoring/logs/#{stranger_log.id}")
    end
  end

  describe "/monitoring/incidents/:incident_id under holter_app" do
    setup %{current_user: user} do
      workspace = workspace_fixture_for(user)
      monitor = monitor_fixture(%{workspace_id: workspace.id, url: "https://incidents.local"})
      incident = incident_fixture(%{monitor_id: monitor.id})

      stranger = user_fixture()
      stranger_workspace = workspace_fixture(%{owner: stranger})
      stranger_monitor = monitor_fixture(%{workspace_id: stranger_workspace.id})
      stranger_incident = incident_fixture(%{monitor_id: stranger_monitor.id})

      setup_app_role()

      %{incident: incident, stranger_incident: stranger_incident}
    end

    test "the auth hook resolves the incident for a workspace member",
         %{conn: conn, incident: incident} do
      {:ok, _view, html} = live(conn, ~p"/monitoring/incidents/#{incident.id}")

      assert html =~ "https://incidents.local"
    end

    test "the auth hook redirects to / when the user is not a member of the incident's workspace",
         %{conn: conn, stranger_incident: stranger_incident} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/monitoring/incidents/#{stranger_incident.id}")
    end
  end

  describe "/delivery/webhook-channels/:id under holter_app" do
    setup %{current_user: user} do
      workspace = workspace_fixture_for(user)

      {:ok, channel} =
        WebhookChannels.create(%{
          workspace_id: workspace.id,
          name: "Test Hook",
          url: "https://hooks.local/in"
        })

      stranger = user_fixture()
      stranger_workspace = workspace_fixture(%{owner: stranger})

      {:ok, foreign_channel} =
        WebhookChannels.create(%{
          workspace_id: stranger_workspace.id,
          name: "Foreign Hook",
          url: "https://foreign.local"
        })

      setup_app_role()

      %{channel: channel, foreign_channel: foreign_channel}
    end

    test "the auth hook resolves the channel for a workspace member",
         %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/delivery/webhook-channels/#{channel.id}")

      assert html =~ channel.name
    end

    test "the auth hook redirects to / when the user is not a member of the channel's workspace",
         %{conn: conn, foreign_channel: foreign_channel} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/delivery/webhook-channels/#{foreign_channel.id}")
    end
  end

  describe "/delivery/email-channels/:id under holter_app" do
    setup %{current_user: user} do
      workspace = workspace_fixture_for(user)

      {:ok, channel} =
        EmailChannels.create(%{workspace_id: workspace.id, name: "Ops Email"})

      stranger = user_fixture()
      stranger_workspace = workspace_fixture(%{owner: stranger})

      {:ok, foreign_channel} =
        EmailChannels.create(%{workspace_id: stranger_workspace.id, name: "Foreign Email"})

      setup_app_role()

      %{channel: channel, foreign_channel: foreign_channel}
    end

    test "the auth hook resolves the channel for a workspace member",
         %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/delivery/email-channels/#{channel.id}")

      assert html =~ channel.name
    end

    test "the auth hook redirects to / when the user is not a member of the channel's workspace",
         %{conn: conn, foreign_channel: foreign_channel} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/delivery/email-channels/#{foreign_channel.id}")
    end
  end
end

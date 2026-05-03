defmodule HolterWeb.Hooks.UserAuthHook do
  @moduledoc """
  LiveView lifecycle hooks for identity-based access control.

  Centralising the gate at the LiveView lifecycle (rather than via a
  separate router pipeline plug) means the same check fires on the
  disconnected HTTP mount AND on every subsequent live_redirect, so a
  session expiring mid-navigation cannot leak past one extra click.

    * `:require_authenticated` — halts and redirects unauthenticated
      visitors to the sign-in page.
    * `:require_workspace_member` — chained after `:require_authenticated`
      on workspace-scoped routes (paths with `:workspace_slug`). Resolves
      the workspace, verifies membership, exposes `@current_workspace`,
      and redirects to `/` on miss — same response whether the slug
      doesn't exist or the user isn't a member, so an attacker cannot
      probe slug existence.
    * `:require_monitor_member` / `:require_incident_member` /
      `:require_log_member` / `:require_webhook_channel_member` /
      `:require_email_channel_member` — UUID-routed counterparts.
      Each loads the resource by id, walks to its workspace, verifies
      membership, exposes the resolved resource (`@current_monitor`,
      `@current_incident`, etc.) and `@current_workspace`, redirects
      to `/` on any miss. LiveView mounts read these from assigns —
      they do not import `Holter.Identity` themselves.
    * `:redirect_if_authenticated` — bounces signed-in users away from
      sign-up / sign-in screens to their first workspace dashboard.
    * `:assign_current_user` — exposes `@current_user` to the layout
      without gating; used by public token-verify links.
  """

  use HolterWeb, :verified_routes
  use Gettext, backend: HolterWeb.Gettext

  import Phoenix.Component, only: [assign: 3, assign_new: 3]
  import Phoenix.LiveView, only: [redirect: 2, put_flash: 3]

  alias Holter.Delivery.{EmailChannels, WebhookChannels}
  alias Holter.Identity
  alias Holter.Monitoring

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = assign_current_user(socket, session)

    case socket.assigns.current_user do
      nil ->
        {:halt,
         socket
         |> put_flash(:error, gettext("You must sign in to access this page."))
         |> redirect(to: ~p"/identity/login")}

      _user ->
        {:cont, socket}
    end
  end

  def on_mount(:require_workspace_member, %{"workspace_slug" => slug}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(slug),
         true <- Identity.workspace_member?(user, workspace) do
      {:cont, assign(socket, :current_workspace, workspace)}
    else
      _ -> {:halt, redirect(socket, to: ~p"/")}
    end
  end

  def on_mount(:require_monitor_member, %{"id" => id}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, monitor} <- Monitoring.get_monitor(id),
         {:ok, workspace} <- Identity.fetch_workspace_for_member(user, monitor.workspace_id) do
      {:cont,
       socket
       |> assign(:current_workspace, workspace)
       |> assign(:current_monitor, monitor)}
    else
      _ -> {:halt, redirect(socket, to: ~p"/")}
    end
  end

  def on_mount(:require_incident_member, %{"incident_id" => incident_id}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, incident} <- Monitoring.get_incident(incident_id),
         {:ok, monitor} <- Monitoring.get_monitor(incident.monitor_id),
         {:ok, workspace} <- Identity.fetch_workspace_for_member(user, monitor.workspace_id) do
      {:cont,
       socket
       |> assign(:current_workspace, workspace)
       |> assign(:current_monitor, monitor)
       |> assign(:current_incident, incident)}
    else
      _ -> {:halt, redirect(socket, to: ~p"/")}
    end
  end

  def on_mount(:require_log_member, %{"log_id" => log_id}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, log} <- Monitoring.get_monitor_log(log_id),
         {:ok, monitor} <- Monitoring.get_monitor(log.monitor_id),
         {:ok, workspace} <- Identity.fetch_workspace_for_member(user, monitor.workspace_id) do
      {:cont,
       socket
       |> assign(:current_workspace, workspace)
       |> assign(:current_monitor, monitor)
       |> assign(:current_log, log)}
    else
      _ -> {:halt, redirect(socket, to: ~p"/")}
    end
  end

  def on_mount(:require_webhook_channel_member, %{"id" => id}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, channel} <- WebhookChannels.get(id),
         {:ok, workspace} <- Identity.fetch_workspace_for_member(user, channel.workspace_id) do
      {:cont,
       socket
       |> assign(:current_workspace, workspace)
       |> assign(:current_channel, channel)}
    else
      _ -> {:halt, redirect(socket, to: ~p"/")}
    end
  end

  def on_mount(:require_email_channel_member, %{"id" => id}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, channel} <- EmailChannels.get(id),
         {:ok, workspace} <- Identity.fetch_workspace_for_member(user, channel.workspace_id) do
      {:cont,
       socket
       |> assign(:current_workspace, workspace)
       |> assign(:current_channel, channel)}
    else
      _ -> {:halt, redirect(socket, to: ~p"/")}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    socket = assign_current_user(socket, session)

    case socket.assigns.current_user do
      nil ->
        {:cont, socket}

      user ->
        {:halt, redirect(socket, to: signed_in_landing(user))}
    end
  end

  def on_mount(:assign_current_user, _params, session, socket) do
    {:cont, assign_current_user(socket, session)}
  end

  defp assign_current_user(socket, session) do
    assign_new(socket, :current_user, fn ->
      with token when is_binary(token) <- session["user_token"],
           user when not is_nil(user) <- Identity.fetch_user_by_session_token(token) do
        user
      else
        _ -> nil
      end
    end)
  end

  defp signed_in_landing(user) do
    case Identity.list_workspaces_for_user(user) do
      [%{slug: slug} | _] -> "/monitoring/workspaces/#{slug}/monitors"
      _ -> "/identity/login"
    end
  end
end

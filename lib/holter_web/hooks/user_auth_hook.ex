defmodule HolterWeb.Hooks.UserAuthHook do
  @moduledoc """
  LiveView lifecycle hooks for identity-based access control.

  Centralising the gate at the LiveView lifecycle (rather than via a
  separate router pipeline plug) means the same check fires on the
  disconnected HTTP mount AND on every subsequent live_redirect, so a
  session expiring mid-navigation cannot leak past one extra click.

    * `:require_authenticated` — halts and redirects unauthenticated
      visitors to the sign-in page.
    * `:redirect_if_authenticated` — bounces signed-in users away from
      sign-up / sign-in screens to their first workspace dashboard.
    * `:assign_current_user` — exposes `@current_user` to the layout
      without gating; used by public token-verify links.
  """

  use HolterWeb, :verified_routes
  use Gettext, backend: HolterWeb.Gettext

  import Phoenix.Component, only: [assign_new: 3]
  import Phoenix.LiveView, only: [redirect: 2, put_flash: 3]

  alias Holter.Identity

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

defmodule HolterWeb.Hooks.AdminAuthHook do
  @moduledoc """
  LiveView lifecycle hook that gates the admin panel.

  `:require_admin` composes `:require_authenticated` from
  `HolterWeb.Hooks.UserAuthHook` and then verifies the resolved user
  holds an active `Holter.System.Admin` row. Non-admins are redirected
  to `/` with no flash — same response whether the user is signed-out
  (the inner hook redirects to login first) or merely lacks the role,
  so an attacker cannot probe whether the gate is at the auth or authz
  layer.

  The admin queries are global (`admins` and `audit_logs` carry no
  `workspace_id`), so no `Holter.Repo.Tenant` wrap is required around
  `Holter.System.admin?/1`.
  """

  import Phoenix.LiveView, only: [redirect: 2]

  alias Holter.System
  alias HolterWeb.Hooks.UserAuthHook

  def on_mount(:require_admin, params, session, socket) do
    case UserAuthHook.on_mount(:require_authenticated, params, session, socket) do
      {:halt, _} = halted ->
        halted

      {:cont, socket} ->
        if System.admin?(socket.assigns.current_user) do
          {:cont, socket}
        else
          {:halt, redirect(socket, to: "/")}
        end
    end
  end
end

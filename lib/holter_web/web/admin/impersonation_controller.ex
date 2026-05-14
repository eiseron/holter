defmodule HolterWeb.Web.Admin.ImpersonationController do
  use HolterWeb, :controller

  alias Holter.Identity
  alias Holter.System
  alias Holter.System.Admins

  plug :require_admin

  def create(conn, %{"user_id" => target_id}) do
    admin = conn.assigns.current_admin
    target = Identity.get_user!(target_id)

    with :ok <- authorize(conn.assigns.current_user, :impersonate, target),
         {:ok, target_plaintext} <- System.start_impersonation(admin, target) do
      impersonator_token = get_session(conn, :user_token)

      conn
      |> put_session(:user_token, target_plaintext)
      |> put_session(:impersonator_token, impersonator_token)
      |> put_flash(:info, gettext("Signed in as %{email}.", email: target.email))
      |> redirect(to: ~p"/")
    else
      {:error, :cannot_impersonate_self} ->
        conn
        |> put_flash(:error, gettext("Cannot impersonate yourself."))
        |> redirect(to: ~p"/admin/users/#{target.id}")

      {:error, _} ->
        conn
        |> put_flash(:error, gettext("Could not start impersonation."))
        |> redirect(to: ~p"/admin/users/#{target.id}")
    end
  end

  def delete(conn, _params) do
    case get_session(conn, :impersonator_token) do
      nil ->
        conn |> put_flash(:error, gettext("Not impersonating.")) |> redirect(to: ~p"/")

      impersonator_plaintext ->
        admin_user = conn.assigns.current_user
        target_plaintext = get_session(conn, :user_token)
        target_user = Identity.fetch_user_by_session_token(target_plaintext)

        if target_user do
          {:ok, _} =
            System.stop_impersonation(target_user, admin_user, target_plaintext)

          conn
          |> put_session(:user_token, impersonator_plaintext)
          |> delete_session(:impersonator_token)
          |> put_flash(
            :info,
            gettext("Admin session restored. Signed out of %{email}.", email: target_user.email)
          )
          |> redirect(to: ~p"/admin/users/#{target_user.id}")
        else
          conn
          |> delete_session(:user_token)
          |> delete_session(:impersonator_token)
          |> redirect(to: ~p"/identity/login")
        end
    end
  end

  defp require_admin(conn, _opts) do
    token = get_session(conn, :impersonator_token) || get_session(conn, :user_token)
    user = token && Identity.fetch_user_by_session_token(token)
    admin_row = user && Admins.get_by_user_id(user.id)

    cond do
      is_nil(user) ->
        conn |> redirect(to: ~p"/identity/login") |> halt()

      is_nil(admin_row) ->
        conn |> put_flash(:error, gettext("Admin required.")) |> redirect(to: ~p"/") |> halt()

      true ->
        conn
        |> assign(:current_user, user)
        |> assign(:current_admin, admin_row)
    end
  end
end

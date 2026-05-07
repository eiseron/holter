defmodule HolterWeb.Web.Identity.UserSessionController do
  use HolterWeb, :controller

  alias Holter.I18n.Locale
  alias Holter.Identity

  def create(conn, %{"user" => params}) do
    %{"email" => email, "password" => password} = params

    case Identity.get_user_by_email_and_password(email, password) do
      nil ->
        conn
        |> put_flash(:error, gettext("Invalid email or password."))
        |> redirect(to: ~p"/identity/login")

      user ->
        sign_user_in(conn, user)
    end
  end

  def delete(conn, _params) do
    token = get_session(conn, :user_token)

    apply_user_locale(token && Identity.fetch_user_by_session_token(token))

    if token, do: Identity.delete_session_token(token)

    conn
    |> clear_session()
    |> configure_session(drop: true)
    |> put_flash(:info, gettext("You have been signed out."))
    |> redirect(to: ~p"/identity/login")
  end

  defp sign_user_in(conn, user) do
    {:ok, _token, plaintext} =
      Identity.create_session_token(user, %{
        "user_agent" => List.first(get_req_header(conn, "user-agent") || [""]),
        "ip" => to_ip_string(conn.remote_ip)
      })

    return_to = get_session(conn, :user_return_to) || default_landing(user)

    apply_user_locale(user)

    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> put_session(:user_token, plaintext)
    |> put_flash(:info, gettext("Welcome back."))
    |> redirect(to: return_to)
  end

  defp apply_user_locale(%{preferred_locale: locale}) when is_binary(locale) do
    if Locale.valid?(locale), do: Gettext.put_locale(HolterWeb.Gettext, locale)
  end

  defp apply_user_locale(_), do: :ok

  defp default_landing(user) do
    case Identity.list_workspaces_for_user(user) do
      [%{slug: slug} | _] -> "/monitoring/workspaces/#{slug}/monitors"
      _ -> ~p"/identity/login"
    end
  end

  defp to_ip_string({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"

  defp to_ip_string(tuple) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> Enum.map_join(":", &Integer.to_string/1)
  end

  defp to_ip_string(_), do: ""
end

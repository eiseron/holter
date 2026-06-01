defmodule HolterWeb.Plugs.FetchCurrentUserPlug do
  @moduledoc false

  use Gettext, backend: HolterWeb.Gettext
  use HolterWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]

  alias Holter.Identity

  def init(opts), do: opts

  def call(conn, _opts) do
    with token when is_binary(token) <- get_session(conn, "user_token"),
         user when not is_nil(user) <- Identity.fetch_user_by_session_token(token) do
      assign(conn, :current_user, user)
    else
      _ -> redirect_unauthenticated(conn)
    end
  end

  defp redirect_unauthenticated(conn) do
    conn
    |> put_flash(:error, dgettext("errors", "You must be logged in."))
    |> redirect(to: ~p"/identity/login")
    |> halt()
  end
end

defmodule HolterWeb.Web.RootController do
  use HolterWeb, :controller

  alias Holter.Identity

  def show(conn, _params) do
    redirect(conn, to: landing_for(current_user(conn)))
  end

  defp current_user(conn) do
    with token when is_binary(token) <- get_session(conn, :user_token),
         user when not is_nil(user) <- Identity.fetch_user_by_session_token(token) do
      user
    else
      _ -> nil
    end
  end

  defp landing_for(nil), do: ~p"/identity/login"

  defp landing_for(user) do
    case Identity.list_workspaces_for_user(user) do
      [%{slug: slug} | _] -> "/monitoring/workspaces/#{slug}/monitors"
      _ -> ~p"/identity/login"
    end
  end
end

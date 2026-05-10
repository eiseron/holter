defmodule HolterWeb.Plugs.FetchApiBearerPlug do
  @moduledoc """
  Resolves the API caller from the `Authorization: Bearer <plaintext>`
  header. On success, assigns:

    * `:current_api_token` — the loaded `%Holter.Identity.Models.ApiToken{}`
    * `:current_user`      — the user who issued it
    * `:current_workspace` — the workspace it is scoped to
    * `:token_scopes`      — the scope strings carried by the token

  All four 401 paths (missing header / wrong scheme / unknown digest /
  revoked or expired) respond with the same `{"error": "unauthorized"}`
  body so the surface doesn't leak which one tripped.

  This plug runs *before* tenant context is set; the lookup goes through
  the SECURITY DEFINER `auth_lookup_api_token` function so RLS doesn't
  block the bootstrap. Subsequent loads (`User`, `Workspace`) target
  tables with no RLS, so they too need no tenant.
  """

  import Plug.Conn

  alias Holter.Identity
  alias Holter.Identity.ApiTokens
  alias Holter.Identity.Models.ApiToken
  alias Holter.Monitoring
  alias Holter.Repo

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, plaintext} <- read_bearer(conn),
         %ApiToken{} = token <- ApiTokens.fetch_active_token_by_plaintext(plaintext),
         {:ok, user} <- load_user(token.user_id),
         {:ok, workspace} <- Monitoring.get_workspace(token.workspace_id) do
      ApiTokens.touch_last_used(token, DateTime.utc_now())

      conn
      |> assign(:current_api_token, token)
      |> assign(:current_user, user)
      |> assign(:current_workspace, workspace)
      |> assign(:token_scopes, token.scopes)
    else
      _ -> halt_unauthorized(conn)
    end
  end

  defp read_bearer(conn) do
    case get_req_header(conn, "authorization") do
      [value | _] -> parse_bearer(value)
      [] -> :error
    end
  end

  defp parse_bearer(value) when is_binary(value) do
    case String.split(value, " ", parts: 2) do
      [scheme, plaintext] ->
        if String.downcase(scheme) == "bearer" and plaintext != "" do
          {:ok, plaintext}
        else
          :error
        end

      _ ->
        :error
    end
  end

  defp load_user(user_id) do
    case Repo.get(Identity.Models.User, user_id) do
      nil -> :error
      user -> {:ok, user}
    end
  end

  defp halt_unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, ~s({"error":"unauthorized"}))
    |> halt()
  end
end

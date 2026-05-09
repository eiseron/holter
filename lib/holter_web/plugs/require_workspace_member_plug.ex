defmodule HolterWeb.Plugs.RequireWorkspaceMemberPlug do
  @moduledoc """
  Defensive slug-token agreement check.

  API tokens are workspace-scoped — `FetchApiBearerPlug` already loaded
  the workspace from the token's `workspace_id`. When the URL path
  *also* carries a `:workspace_slug` (e.g. `/api/v1/workspaces/:workspace_slug/monitors`),
  this plug asserts the slug resolves to the same workspace the token
  authorises.

    * Slug missing → no-op (resource-id routes lean on RLS to 404).
    * Slug resolves to a different workspace → 403 (token authenticated,
      just for the wrong tenant).
    * Slug doesn't resolve at all → 404.
    * Match → conn passes through.

  Membership cascades on `workspace_memberships` deletion (DB trigger
  revokes the user's tokens) close the membership-was-removed gap, so
  this plug doesn't need a separate membership lookup.
  """

  import Plug.Conn

  alias Holter.Monitoring

  def init(opts), do: opts

  def call(conn, _opts) do
    case slug_from(conn) do
      nil -> conn
      slug -> verify(conn, slug)
    end
  end

  defp slug_from(conn) do
    case conn.path_params do
      %{"workspace_slug" => slug} when is_binary(slug) and slug != "" -> slug
      _ -> nil
    end
  end

  defp verify(conn, slug) do
    current = conn.assigns[:current_workspace]

    case Monitoring.get_workspace_by_slug(slug) do
      {:ok, %{id: id}} when not is_nil(current) and current.id == id -> conn
      {:ok, _other} -> halt_with(conn, 403, "forbidden")
      {:error, :not_found} -> halt_with(conn, 404, "not_found")
    end
  end

  defp halt_with(conn, status, error) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, ~s({"error":"#{error}"}))
    |> halt()
  end
end

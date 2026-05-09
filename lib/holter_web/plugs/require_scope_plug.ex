defmodule HolterWeb.Plugs.RequireScopePlug do
  @moduledoc """
  Per-action scope assertion. Mounted in API controllers as

      plug HolterWeb.Plugs.RequireScopePlug, "read:monitors" when action in [:index, :show]

  Halts with 403 JSON `{"error": "forbidden", "required_scope": "<scope>"}`
  when the bearer token's scopes don't include the required one. The
  required scope is part of the documented public vocabulary, so leaking
  it in the response body is intentional — it tells SDK authors which
  scope to add to the token.

  Validates the scope string at compile-time via `Scopes.valid?/1` so a
  typo in the controller doesn't ship.
  """

  import Plug.Conn

  alias Holter.Identity.Scopes

  def init(scope) when is_binary(scope) do
    if Scopes.valid?(scope) do
      scope
    else
      raise ArgumentError,
            "RequireScopePlug: #{inspect(scope)} is not a known scope. " <>
              "Add it to Holter.Identity.Scopes or fix the typo."
    end
  end

  def call(conn, scope) do
    if scope in (conn.assigns[:token_scopes] || []) do
      conn
    else
      halt_forbidden(conn, scope)
    end
  end

  defp halt_forbidden(conn, scope) do
    body = ~s({"error":"forbidden","required_scope":"#{scope}"})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(403, body)
    |> halt()
  end
end

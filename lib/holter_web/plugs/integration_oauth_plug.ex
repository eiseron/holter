defmodule HolterWeb.Plugs.IntegrationOAuthPlug do
  @moduledoc false

  import Plug.Conn

  alias Holter.Integrations.OAuth

  def init(opts), do: opts

  def call(%Plug.Conn{params: %{"state" => state, "provider" => provider}} = conn, _opts) do
    case OAuth.verify_state_token(conn, state) do
      {:ok, %{provider: state_provider} = claims} when state_provider == provider ->
        assign(conn, :oauth_state_claims, claims)

      {:ok, _claims} ->
        conn |> send_resp(400, "provider mismatch") |> halt()

      {:error, :expired} ->
        conn |> send_resp(400, "state token expired") |> halt()

      {:error, :invalid} ->
        conn |> send_resp(400, "invalid state token") |> halt()
    end
  end

  def call(conn, _opts) do
    conn |> send_resp(400, "missing state or provider") |> halt()
  end
end

defmodule HolterWeb.Plugs.ImpersonationPlug do
  @moduledoc """
  Resolves the impersonator (if any) from the session and exposes their
  email as `@impersonator_email` on the conn. The root layout renders
  the warning banner when the assign is present.

  The session shape during an impersonation:

      %{
        "user_token" => target_plaintext,
        "impersonator_token" => admin_plaintext
      }

  Outside an impersonation, only `user_token` is present and the assign
  resolves to `nil`.
  """

  @behaviour Plug

  alias Holter.Identity

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case Plug.Conn.get_session(conn, :impersonator_token) do
      nil ->
        Plug.Conn.assign(conn, :impersonator_email, nil)

      plaintext ->
        impersonator = Identity.fetch_user_by_session_token(plaintext)
        Plug.Conn.assign(conn, :impersonator_email, impersonator && impersonator.email)
    end
  end
end

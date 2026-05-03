defmodule Holter.Identity do
  @moduledoc """
  The Identity context. Owns users, sessions, verification tokens, and
  the join to Monitoring workspaces.
  """

  alias Holter.Identity.{Memberships, Tokens, Users}

  defdelegate register_user(attrs), to: Users
  defdelegate get_user!(id), to: Users
  defdelegate get_user_by_email_and_password(email, password), to: Users
  defdelegate verify_email(token), to: Users

  defdelegate create_session_token(user, context \\ %{}), to: Tokens
  defdelegate fetch_user_by_session_token(token), to: Tokens
  defdelegate delete_session_token(token), to: Tokens

  defdelegate list_workspaces_for_user(user), to: Memberships
  defdelegate workspace_member?(user, workspace), to: Memberships, as: :member?
  defdelegate fetch_workspace_for_member(user, workspace_id), to: Memberships
end

defmodule Holter.Identity do
  @moduledoc """
  The Identity context. Owns users, sessions, verification tokens, and
  the join to Monitoring workspaces.
  """

  alias Holter.Identity.{ApiTokens, Memberships, Passwords, Tokens, Users}

  defdelegate register_user(attrs), to: Users
  defdelegate get_user!(id), to: Users
  defdelegate get_user_by_email_and_password(email, password), to: Users
  defdelegate verify_email(token), to: Users
  defdelegate update_user_preferences(user, attrs), to: Users

  defdelegate request_password_reset(email), to: Passwords, as: :request_reset
  defdelegate reset_password(token, new_password), to: Passwords

  defdelegate create_session_token(user, context \\ %{}), to: Tokens
  defdelegate fetch_user_by_session_token(token), to: Tokens
  defdelegate delete_session_token(token), to: Tokens
  defdelegate delete_user_sessions(user_id), to: Tokens

  defdelegate list_workspaces_for_user(user), to: Memberships
  defdelegate list_workspace_memberships_for_user(user), to: Memberships
  defdelegate workspace_member?(user, workspace), to: Memberships, as: :member?
  defdelegate workspace_admin?(user, workspace), to: Memberships, as: :admin?
  defdelegate workspace_owner?(user, workspace), to: Memberships, as: :owner?
  defdelegate get_workspace_membership(user, workspace), to: Memberships, as: :get_membership
  defdelegate fetch_workspace_for_member(user, workspace_id), to: Memberships

  defdelegate create_api_token(user, workspace, attrs), to: ApiTokens, as: :create_token
  defdelegate list_api_tokens(workspace), to: ApiTokens, as: :list_tokens_for_workspace
  defdelegate revoke_api_token(token), to: ApiTokens, as: :revoke_token

  defdelegate fetch_api_token_by_plaintext(plaintext),
    to: ApiTokens,
    as: :fetch_active_token_by_plaintext
end

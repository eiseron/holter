defmodule Holter.Identity.Tenant do
  @moduledoc """
  Pure transformer helpers for the database-level multi-tenancy
  context. The actual `SET` calls live in `Holter.Repo.Tenant`.
  """

  @workspace_session_var "app.current_workspace_id"
  @user_session_var "app.current_user_id"

  @spec workspace_session_var() :: String.t()
  def workspace_session_var, do: @workspace_session_var

  @spec user_session_var() :: String.t()
  def user_session_var, do: @user_session_var

  @spec parse_workspace_id(term()) :: {:ok, String.t()} | {:error, :invalid_workspace_id}
  def parse_workspace_id(value)

  def parse_workspace_id(value) when is_binary(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, :invalid_workspace_id}
    end
  end

  def parse_workspace_id(%{id: id}) when is_binary(id), do: parse_workspace_id(id)

  def parse_workspace_id(_), do: {:error, :invalid_workspace_id}

  @spec parse_user_id(term()) :: {:ok, String.t()} | {:error, :invalid_user_id}
  def parse_user_id(value)

  def parse_user_id(value) when is_binary(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, :invalid_user_id}
    end
  end

  def parse_user_id(%{id: id}) when is_binary(id), do: parse_user_id(id)

  def parse_user_id(_), do: {:error, :invalid_user_id}
end

defmodule Holter.System.Policies.User do
  @moduledoc """
  Authorization policy for admin-panel access to `Holter.Identity.Models.User`.
  Distinct from `Holter.Identity.Policies.*` — those gate per-workspace
  self-actions; this one gates cross-workspace inspection by an active admin.

  | action  | subject                       | who can act          |
  | ------- | ----------------------------- | -------------------- |
  | `:list` | `Holter.Identity.Models.User` | an active admin user |
  | `:read` | `%User{}`                     | an active admin user |
  """

  @behaviour Bodyguard.Policy

  alias Holter.Identity.Models.User
  alias Holter.System.Admins

  @impl true
  def authorize(_action, :system, _subject), do: :ok

  def authorize(action, %User{} = actor, subject) when action in [:list, :read] do
    if Admins.admin?(actor) and admin_subject?(subject),
      do: :ok,
      else: {:error, :unauthorized}
  end

  def authorize(:impersonate, %User{} = actor, %User{} = target) do
    cond do
      not Admins.admin?(actor) -> {:error, :unauthorized}
      actor.id == target.id -> {:error, :cannot_impersonate_self}
      true -> :ok
    end
  end

  def authorize(_action, _user, _subject), do: {:error, :unauthorized}

  defp admin_subject?(User), do: true
  defp admin_subject?(%User{}), do: true
  defp admin_subject?(_), do: false
end

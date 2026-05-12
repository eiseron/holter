defmodule Holter.System.Policies.Admin do
  @moduledoc """
  Authorization policy for `Holter.System.Models.Admin` and adjacent
  admin-panel actions. Every `:ok` requires the actor to hold an active
  admin row; `:demote` additionally refuses self-demotion so a sole
  admin cannot lock themselves out.

  | action            | subject                                     |
  | ----------------- | ------------------------------------------- |
  | `:enter_admin`    | `%User{}` (the actor; passed as subject)    |
  | `:list_admins`    | `Holter.System.Models.Admin` (module)       |
  | `:read_audit_log` | `Holter.System.Models.Admin` (module)       |
  | `:promote`        | `{Holter.System.Models.Admin, %User{}}`     |
  | `:demote`         | `%Holter.System.Models.Admin{}`             |
  """

  @behaviour Bodyguard.Policy

  alias Holter.Identity.Models.User
  alias Holter.System.Admins
  alias Holter.System.Models.Admin

  @impl true
  def authorize(_action, :system, _subject), do: :ok

  def authorize(:enter_admin, %User{} = actor, %User{id: actor_id}) do
    if actor.id == actor_id and Admins.admin?(actor), do: :ok, else: {:error, :unauthorized}
  end

  def authorize(action, %User{} = actor, Admin) when action in [:list_admins, :read_audit_log] do
    if Admins.admin?(actor), do: :ok, else: {:error, :unauthorized}
  end

  def authorize(:promote, %User{} = actor, %User{} = target) do
    cond do
      not Admins.admin?(actor) -> {:error, :unauthorized}
      Admins.admin?(target) -> {:error, :already_admin}
      true -> :ok
    end
  end

  def authorize(:demote, %User{} = actor, %Admin{} = target_admin) do
    cond do
      not Admins.admin?(actor) -> {:error, :unauthorized}
      actor.id == target_admin.user_id -> {:error, :cannot_self_demote}
      true -> :ok
    end
  end

  def authorize(_action, _user, _subject), do: {:error, :unauthorized}
end

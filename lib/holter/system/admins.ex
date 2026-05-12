defmodule Holter.System.Admins do
  @moduledoc """
  Coordinator for the `admins` table — the canonical "who at Eiseron has
  God Mode" list. Every mutation here goes through `Repo.transaction/1`
  paired with an `AuditLogs.log!` call so the trail and the row commit
  together.

  Mirrors the `Holter.Identity.Users` shape: pure helpers live in
  `Holter.System.AdminActions`; this module owns DB writes, the clock,
  and the bootstrap rules.
  """

  import Ecto.Query

  alias Holter.Identity.Models.User
  alias Holter.Repo
  alias Holter.System.AdminActions
  alias Holter.System.AuditLogs
  alias Holter.System.Models.Admin

  def admin?(nil), do: false

  def admin?(%User{id: user_id}) do
    Repo.exists?(from a in Admin, where: a.user_id == ^user_id and is_nil(a.revoked_at))
  end

  def list_admins do
    Admin
    |> where([a], is_nil(a.revoked_at))
    |> order_by([a], desc: a.promoted_at)
    |> preload(:user)
    |> Repo.all()
  end

  def promote_user(%User{} = target, %Admin{} = actor_admin) do
    actor_user = Repo.get!(User, actor_admin.user_id)

    run_promotion(target, %{
      actor_admin: actor_admin,
      actor_user: actor_user,
      actor_type: "admin",
      now: DateTime.utc_now()
    })
  end

  def bootstrap_promote!(%User{} = target) do
    if Repo.exists?(Admin) do
      raise RuntimeError,
            "Holter.System.Admins.bootstrap_promote!/1 called but admins already exist. " <>
              "Use promote_user/2 with an actor admin instead."
    end

    result =
      run_promotion(target, %{
        actor_admin: nil,
        actor_user: nil,
        actor_type: "system",
        now: DateTime.utc_now()
      })

    case result do
      {:ok, admin} -> admin
      {:error, reason} -> raise "bootstrap_promote!/1 failed: #{inspect(reason)}"
    end
  end

  def demote_admin(%Admin{} = admin, %Admin{} = actor_admin) do
    cond do
      admin.user_id == actor_admin.user_id ->
        {:error, :cannot_self_demote}

      not is_nil(admin.revoked_at) ->
        {:error, :already_revoked}

      true ->
        actor_user = Repo.get!(User, actor_admin.user_id)

        run_revocation(admin, %{
          actor_admin: actor_admin,
          actor_user: actor_user,
          now: DateTime.utc_now()
        })
    end
  end

  defp run_promotion(target, ctx) do
    if admin?(target) do
      {:error, :already_admin}
    else
      Repo.transaction(fn -> commit_promotion(target, ctx) end)
    end
  end

  defp commit_promotion(target, ctx) do
    attrs = AdminActions.build_promotion_attrs(target, ctx.actor_admin, ctx.now)
    diff = AdminActions.build_audit_diff(:promote, target, ctx.actor_admin)

    case insert_admin(attrs) do
      {:ok, admin} ->
        AuditLogs.log!(
          %{
            actor_user: ctx.actor_user,
            actor_type: ctx.actor_type,
            resource: "User:" <> target.id,
            action: "promote_admin",
            diff: diff
          },
          ctx.now
        )

        admin

      {:error, changeset} ->
        Repo.rollback(changeset)
    end
  end

  defp run_revocation(admin, ctx) do
    Repo.transaction(fn -> commit_revocation(admin, ctx) end)
  end

  defp commit_revocation(admin, ctx) do
    attrs = AdminActions.build_revocation_attrs(ctx.actor_admin, ctx.now)
    diff = AdminActions.build_audit_diff(:demote, admin, ctx.actor_admin)

    case update_admin(admin, attrs) do
      {:ok, revoked} ->
        AuditLogs.log!(
          %{
            actor_user: ctx.actor_user,
            actor_type: "admin",
            resource: "Admin:" <> admin.id,
            action: "demote_admin",
            diff: diff
          },
          ctx.now
        )

        revoked

      {:error, changeset} ->
        Repo.rollback(changeset)
    end
  end

  defp insert_admin(attrs) do
    %Admin{}
    |> Admin.promotion_changeset(attrs)
    |> Repo.insert()
  end

  defp update_admin(admin, attrs) do
    admin
    |> Admin.revocation_changeset(attrs)
    |> Repo.update()
  end
end

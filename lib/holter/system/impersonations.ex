defmodule Holter.System.Impersonations do
  @moduledoc """
  Coordinator for admin impersonation (BDD 64 cenário 64). An active
  admin starts a session as a target user; both sessions exist for the
  lifetime of the impersonation, and the admin can step out at any
  time to restore their own session.

  Returns plaintext session tokens — the caller (controller) is
  responsible for stamping them onto the browser session and never
  persists them in plaintext. Every transition emits an `audit_logs`
  row inside the same `Repo.transaction` as the token write.
  """

  alias Holter.Identity
  alias Holter.Identity.Models.User
  alias Holter.Repo
  alias Holter.System.AuditLogs
  alias Holter.System.Models.Admin

  def start(%Admin{} = actor_admin, %User{} = target) do
    actor_user = Repo.get!(User, actor_admin.user_id)

    if target.id == actor_user.id do
      {:error, :cannot_impersonate_self}
    else
      do_start(actor_user, target)
    end
  end

  def stop(%User{} = target, %User{} = actor_user, target_plaintext) do
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      diff = %{
        "target_user_id" => target.id,
        "target_email" => target.email,
        "actor_user_id" => actor_user.id
      }

      AuditLogs.log!(
        %{
          actor_user: actor_user,
          actor_type: "admin",
          resource: "User:" <> target.id,
          action: "impersonate_end",
          diff: diff
        },
        now
      )

      Identity.delete_session_token(target_plaintext)

      :ok
    end)
  end

  defp do_start(%User{} = actor_user, %User{} = target) do
    now = DateTime.utc_now()

    result =
      Repo.transaction(fn ->
        case Identity.create_session_token(target, %{context: "impersonation"}) do
          {:ok, _token_struct, target_plaintext} ->
            diff = %{
              "target_user_id" => target.id,
              "target_email" => target.email,
              "actor_user_id" => actor_user.id
            }

            AuditLogs.log!(
              %{
                actor_user: actor_user,
                actor_type: "admin",
                resource: "User:" <> target.id,
                action: "impersonate_start",
                diff: diff
              },
              now
            )

            target_plaintext

          {:error, reason} ->
            Repo.rollback(reason)
        end
      end)

    case result do
      {:ok, plaintext} -> {:ok, plaintext}
      {:error, reason} -> {:error, reason}
    end
  end
end

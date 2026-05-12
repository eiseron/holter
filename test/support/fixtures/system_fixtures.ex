defmodule Holter.SystemFixtures do
  @moduledoc """
  Test helpers for building entities in the `Holter.System` domain.
  """

  alias Holter.IdentityFixtures
  alias Holter.Repo
  alias Holter.System
  alias Holter.System.Models.Admin
  alias Holter.System.Models.AuditLog

  @doc """
  Inserts an active admin row for the given user. If no user is passed,
  creates a fresh one via `Holter.IdentityFixtures.user_fixture/1`.
  Bypasses the bootstrap rules and the audit-log side effect — use this
  when you just need an admin in the database, not when you're
  exercising the promotion path itself.
  """
  def admin_fixture(attrs \\ %{}) do
    user = Map.get(attrs, :user) || IdentityFixtures.user_fixture()

    promoted_at =
      Map.get(attrs, :promoted_at, DateTime.utc_now() |> DateTime.truncate(:second))

    %Admin{}
    |> Admin.promotion_changeset(%{
      user_id: user.id,
      promoted_by_admin_id: Map.get(attrs, :promoted_by_admin_id),
      promoted_at: promoted_at
    })
    |> Repo.insert!()
    |> Repo.preload(:user)
  end

  @doc """
  Inserts an admin via the coordinator's bootstrap path. Use when the
  test cares about audit-log emission or the `system` actor type.
  """
  def bootstrap_admin_fixture(attrs \\ %{}) do
    user = Map.get(attrs, :user) || IdentityFixtures.user_fixture()
    System.bootstrap_promote!(user)
  end

  @doc """
  Inserts an audit log row with sensible defaults. Override any field
  via `attrs`.
  """
  def audit_log_fixture(attrs \\ %{}) do
    now = Map.get(attrs, :occurred_at, DateTime.utc_now())

    base = %{
      actor_id: nil,
      actor_type: "system",
      resource: "User:test",
      action: "test_action",
      diff: %{},
      occurred_at: now
    }

    %AuditLog{}
    |> AuditLog.insert_changeset(
      Map.merge(base, Map.delete(attrs, :occurred_at))
      |> Map.put(:occurred_at, now)
    )
    |> Repo.insert!()
  end
end

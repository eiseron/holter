defmodule Holter.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def up do
    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :actor_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :actor_type, :string, null: false
      add :resource, :string, null: false
      add :action, :string, null: false
      add :diff, :map, null: false, default: %{}
      add :occurred_at, :utc_datetime_usec, null: false
      add :inserted_at, :utc_datetime_usec, null: false
    end

    create index(:audit_logs, [:actor_id])
    create index(:audit_logs, [:resource])
    create index(:audit_logs, [:occurred_at])

    create constraint(:audit_logs, :actor_type_known, check: "actor_type IN ('admin', 'system')")
  end

  def down do
    drop table(:audit_logs)
  end
end

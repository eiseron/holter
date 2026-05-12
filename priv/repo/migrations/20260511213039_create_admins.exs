defmodule Holter.Repo.Migrations.CreateAdmins do
  use Ecto.Migration

  def up do
    create table(:admins, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :promoted_by_admin_id, references(:admins, type: :binary_id, on_delete: :nilify_all)
      add :promoted_at, :utc_datetime, null: false
      add :revoked_at, :utc_datetime
      add :revoked_by_admin_id, references(:admins, type: :binary_id, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create unique_index(:admins, [:user_id],
             where: "revoked_at IS NULL",
             name: :admins_user_id_active_index
           )

    create index(:admins, [:revoked_at])
  end

  def down do
    drop table(:admins)
  end
end

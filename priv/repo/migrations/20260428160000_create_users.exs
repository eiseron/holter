defmodule Holter.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION IF EXISTS citext")

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :onboarding_status, :string, null: false, default: "pending_verification"
      add :email_verified_at, :utc_datetime
      add :terms_accepted_at, :utc_datetime
      add :terms_version, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
  end
end

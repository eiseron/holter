defmodule Holter.Repo.Migrations.CreateAuthTokens do
  use Ecto.Migration

  def change do
    create table(:auth_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :hashed_value, :bytea, null: false
      add :context, :map, null: false, default: %{}
      add :used_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:auth_tokens, [:hashed_value])
    create index(:auth_tokens, [:user_id, :type])
    create index(:auth_tokens, [:expires_at])
  end
end

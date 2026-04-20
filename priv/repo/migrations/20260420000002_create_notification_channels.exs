defmodule Holter.Repo.Migrations.CreateNotificationChannels do
  use Ecto.Migration

  def change do
    create table(:notification_channels, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :type, :string, null: false
      add :target, :string, null: false
      add :settings, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:notification_channels, [:workspace_id])
  end
end

defmodule Holter.Repo.Migrations.DropUserIdFromMonitors do
  use Ecto.Migration

  def change do
    drop_if_exists index(:monitors, [:user_id])

    alter table(:monitors) do
      remove :user_id, :binary_id
    end
  end
end

defmodule Holter.Repo.Migrations.AddRedirectFieldsToMonitors do
  use Ecto.Migration

  def change do
    alter table(:monitors) do
      add :follow_redirects, :boolean, default: true, null: false
      add :max_redirects, :integer, default: 5, null: false
    end
  end
end

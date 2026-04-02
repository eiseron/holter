defmodule Holter.Repo.Migrations.EnforceUniqueOpenIncidents do
  use Ecto.Migration

  def change do
    create unique_index(:incidents, [:monitor_id, :type],
             where: "resolved_at IS NULL",
             name: :unique_open_incident_per_type
           )
  end
end

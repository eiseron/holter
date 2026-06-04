defmodule Holter.Repo.Migrations.DropSubscribedEventsFromIntegrations do
  use Ecto.Migration

  def up do
    alter table(:integrations) do
      remove :subscribed_events
    end
  end

  def down do
    alter table(:integrations) do
      add :subscribed_events, {:array, :string}, default: [], null: false
    end
  end
end

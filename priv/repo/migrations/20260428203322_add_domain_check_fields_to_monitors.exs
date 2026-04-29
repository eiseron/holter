defmodule Holter.Repo.Migrations.AddDomainCheckFieldsToMonitors do
  use Ecto.Migration

  def change do
    alter table(:monitors) do
      add :domain_check_ignore, :boolean, default: false, null: false
      add :domain_expires_at, :utc_datetime
      add :last_domain_check_at, :utc_datetime
    end
  end
end

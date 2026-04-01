defmodule Holter.Repo.Migrations.AddSslExpiresAtToMonitors do
  use Ecto.Migration

  def change do
    alter table(:monitors) do
      add :ssl_expires_at, :utc_datetime
    end
  end
end

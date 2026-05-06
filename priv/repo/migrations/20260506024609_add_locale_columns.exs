defmodule Holter.Repo.Migrations.AddLocaleColumns do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      add :default_locale, :string, null: false
    end

    alter table(:users) do
      add :preferred_locale, :string
    end

    alter table(:email_channels) do
      add :locale, :string
    end

    alter table(:webhook_channels) do
      add :locale, :string
    end
  end
end

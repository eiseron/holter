defmodule Holter.Repo.Migrations.AddVerificationToEmailChannels do
  use Ecto.Migration

  def up do
    alter table(:email_channels) do
      add :verified_at, :utc_datetime, null: true
      add :verification_token, :string, null: true
      add :verification_token_expires_at, :utc_datetime, null: true
    end

    create unique_index(:email_channels, [:verification_token],
             where: "verification_token IS NOT NULL"
           )
  end

  def down do
    drop_if_exists index(:email_channels, [:verification_token])

    alter table(:email_channels) do
      remove :verification_token_expires_at
      remove :verification_token
      remove :verified_at
    end
  end
end

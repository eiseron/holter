defmodule Holter.Repo.Migrations.AddSigningTokenToWebhookChannels do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")

    alter table(:webhook_channels) do
      add :signing_token, :string
    end

    flush()

    execute("""
    UPDATE webhook_channels
    SET signing_token = translate(
      rtrim(encode(gen_random_bytes(32), 'base64'), '='),
      '+/',
      '-_'
    )
    WHERE signing_token IS NULL
    """)

    alter table(:webhook_channels) do
      modify :signing_token, :string, null: false
    end
  end

  def down do
    alter table(:webhook_channels) do
      remove :signing_token
    end
  end
end

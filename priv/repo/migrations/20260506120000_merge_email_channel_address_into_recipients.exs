defmodule Holter.Repo.Migrations.MergeEmailChannelAddressIntoRecipients do
  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO email_channel_recipients (
      id, email_channel_id, email, verified_at, inserted_at, updated_at
    )
    SELECT
      gen_random_uuid(),
      c.id,
      c.address,
      CASE
        WHEN c.verified_at IS NULL THEN NULL
        ELSE c.verified_at::timestamp(0)
      END,
      now(),
      now()
    FROM email_channels c
    WHERE c.address IS NOT NULL
    ON CONFLICT (email_channel_id, email) DO UPDATE
      SET verified_at = COALESCE(email_channel_recipients.verified_at, EXCLUDED.verified_at)
    """)

    alter table(:email_channels) do
      remove :address
      remove :verified_at
      remove :verification_token
      remove :verification_token_expires_at
    end
  end

  def down do
    alter table(:email_channels) do
      add :address, :string
      add :verified_at, :utc_datetime
      add :verification_token, :string
      add :verification_token_expires_at, :utc_datetime
    end

    flush()

    execute("""
    UPDATE email_channels c
    SET
      address = r.email,
      verified_at = CASE
        WHEN r.verified_at IS NULL THEN NULL
        ELSE (r.verified_at AT TIME ZONE 'UTC')
      END
    FROM (
      SELECT DISTINCT ON (email_channel_id)
        email_channel_id, email, verified_at
      FROM email_channel_recipients
      ORDER BY email_channel_id, inserted_at ASC
    ) r
    WHERE c.id = r.email_channel_id
    """)
  end
end

defmodule Holter.Repo.Migrations.RelaxSubtypeParentFk do
  @moduledoc """
  Step 2 of #29's split. Makes `notification_channel_id` nullable on both
  subtype tables so the new entity contexts (`WebhookChannels`,
  `EmailChannels`) can insert rows directly. The parent `NotificationChannel`
  changeset path keeps populating it during the transition. The FK column
  itself is dropped by the final cleanup migration once nothing references
  the parent.
  """
  use Ecto.Migration

  def up do
    execute("ALTER TABLE webhook_channels ALTER COLUMN notification_channel_id DROP NOT NULL")
    execute("ALTER TABLE email_channels ALTER COLUMN notification_channel_id DROP NOT NULL")
  end

  def down do
    execute("ALTER TABLE webhook_channels ALTER COLUMN notification_channel_id SET NOT NULL")
    execute("ALTER TABLE email_channels ALTER COLUMN notification_channel_id SET NOT NULL")
  end
end

# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Also runs on every per-MR preview deploy so reviewers land on a populated
# dashboard. Re-running is a no-op once any workspace exists. The actual
# seeding logic lives in priv/repo/seeds/ — split by Holter context
# (Monitoring, Identity, Delivery, ...) so each domain stays self-contained.

Code.require_file("seeds/time.exs", __DIR__)
Code.require_file("seeds/monitoring/workspaces.exs", __DIR__)
Code.require_file("seeds/monitoring/monitors.exs", __DIR__)
Code.require_file("seeds/monitoring/incidents.exs", __DIR__)
Code.require_file("seeds/monitoring/daily_metrics.exs", __DIR__)
Code.require_file("seeds/identity/users.exs", __DIR__)
Code.require_file("seeds/delivery/webhook_channels.exs", __DIR__)
Code.require_file("seeds/delivery/email_channels.exs", __DIR__)

alias Holter.Monitoring.Workspace
alias Holter.Repo
alias Holter.Seeds.Delivery.{EmailChannels, WebhookChannels}
alias Holter.Seeds.Identity.Users
alias Holter.Seeds.Monitoring.{DailyMetrics, Incidents, Monitors, Workspaces}

if Repo.aggregate(Workspace, :count) == 0 do
  workspace = Workspaces.create_default()
  monitors = Monitors.create_for(workspace)
  Incidents.create_for(monitors)
  DailyMetrics.create_for(monitors)
  Users.create_dev(workspace)
  WebhookChannels.create_for(workspace, monitors)
  EmailChannels.create_for(workspace, monitors)
end

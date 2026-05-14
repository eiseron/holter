Code.require_file("seeds/time.exs", __DIR__)
Code.require_file("seeds/monitoring/workspaces.exs", __DIR__)
Code.require_file("seeds/monitoring/monitors.exs", __DIR__)
Code.require_file("seeds/monitoring/incidents.exs", __DIR__)
Code.require_file("seeds/monitoring/daily_metrics.exs", __DIR__)
Code.require_file("seeds/identity/users.exs", __DIR__)
Code.require_file("seeds/identity/api_tokens.exs", __DIR__)
Code.require_file("seeds/delivery/webhook_channels.exs", __DIR__)
Code.require_file("seeds/delivery/email_channels.exs", __DIR__)
Code.require_file("seeds/system/admins.exs", __DIR__)

alias Holter.Monitoring.Models.Workspace
alias Holter.Repo
alias Holter.Seeds.Delivery.{EmailChannels, WebhookChannels}
alias Holter.Seeds.Identity.{ApiTokens, Users}
alias Holter.Seeds.Monitoring.{DailyMetrics, Incidents, Monitors, Workspaces}
alias Holter.Seeds.System, as: SeedsSystem

if Repo.aggregate(Workspace, :count) == 0 do
  workspace = Workspaces.create_default()
  secondary = Workspaces.create_secondary()
  monitors = Monitors.create_for(workspace)
  Incidents.create_for(monitors)
  DailyMetrics.create_for(monitors)
  user = Users.create_dev([workspace, secondary])
  Users.create_extra([workspace])
  ApiTokens.create_dev(user, workspace)
  WebhookChannels.create_for(workspace, monitors)
  EmailChannels.create_for(workspace, monitors)
  SeedsSystem.Admins.bootstrap_dev(user)
end

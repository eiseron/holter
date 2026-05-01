# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Also runs on every per-MR preview deploy so reviewers land on a populated
# dashboard. Re-running is a no-op once any workspace exists. The actual
# seeding logic lives in priv/repo/seeds/ — split by Holter context
# (Monitoring, Delivery, ...) so each domain stays self-contained.

Code.require_file("seeds/time.exs", __DIR__)
Code.require_file("seeds/monitoring/workspaces.exs", __DIR__)
Code.require_file("seeds/monitoring/monitors.exs", __DIR__)
Code.require_file("seeds/monitoring/incidents.exs", __DIR__)
Code.require_file("seeds/monitoring/daily_metrics.exs", __DIR__)

alias Holter.Monitoring.Workspace
alias Holter.Repo
alias Holter.Seeds.Monitoring.{DailyMetrics, Incidents, Monitors, Workspaces}

if Repo.aggregate(Workspace, :count) == 0 do
  workspace = Workspaces.create_default()
  monitors = Monitors.create_for(workspace)
  Incidents.create_for(monitors)
  DailyMetrics.create_for(monitors)
end

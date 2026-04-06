defmodule Holter.Repo.Migrations.MigrateLegacyMonitorStatus do
  use Ecto.Migration

  def up do
    # Update monitor_logs status strings to new atom-compatible strings
    execute "UPDATE monitor_logs SET status = 'up' WHERE status = 'success'"
    execute "UPDATE monitor_logs SET status = 'down' WHERE status = 'failure'"
    execute "UPDATE monitor_logs SET status = 'compromised' WHERE status = 'suspicious'"

    # Catch-all for any other legacy values
    execute """
    UPDATE monitor_logs 
    SET status = 'unknown' 
    WHERE status NOT IN ('up', 'down', 'degraded', 'compromised', 'unknown')
    """

    # Also update monitors health_status for consistency
    execute "UPDATE monitors SET health_status = 'up' WHERE health_status = 'success'"
    execute "UPDATE monitors SET health_status = 'down' WHERE health_status = 'failure'"
    execute "UPDATE monitors SET health_status = 'compromised' WHERE health_status = 'suspicious'"

    execute """
    UPDATE monitors 
    SET health_status = 'unknown' 
    WHERE health_status NOT IN ('up', 'down', 'degraded', 'compromised', 'unknown')
    """
  end

  def down do
    # Reverting is best-effort as many-to-one mapping is destructive
    execute "UPDATE monitor_logs SET status = 'success' WHERE status = 'up'"
    execute "UPDATE monitor_logs SET status = 'failure' WHERE status = 'down'"
    execute "UPDATE monitor_logs SET status = 'suspicious' WHERE status = 'compromised'"

    execute "UPDATE monitors SET health_status = 'success' WHERE health_status = 'up'"
    execute "UPDATE monitors SET health_status = 'failure' WHERE health_status = 'down'"
    execute "UPDATE monitors SET health_status = 'suspicious' WHERE health_status = 'compromised'"
  end
end

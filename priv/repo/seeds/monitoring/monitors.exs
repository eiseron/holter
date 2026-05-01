defmodule Holter.Seeds.Monitoring.Monitors do
  @moduledoc false

  alias Holter.Monitoring.Monitor
  alias Holter.Repo
  alias Holter.Seeds.Time

  @minute Time.minute()
  @day Time.day()

  def create_for(workspace) do
    monitors = %{
      healthy_example: insert(workspace, healthy_example_attrs()),
      healthy_github: insert(workspace, healthy_github_attrs()),
      down: insert(workspace, down_attrs()),
      degraded: insert(workspace, degraded_attrs()),
      ssl_expiring: insert(workspace, ssl_expiring_attrs()),
      domain_expiring: insert(workspace, domain_expiring_attrs()),
      paused: insert(workspace, paused_attrs())
    }

    IO.puts("[seeds] Created #{map_size(monitors)} monitors across mixed health states")
    monitors
  end

  defp insert(workspace, attrs) do
    %Monitor{}
    |> Monitor.changeset(Map.put(attrs, :workspace_id, workspace.id), workspace)
    |> Repo.insert!()
  end

  defp healthy_example_attrs do
    %{
      url: "https://example.com",
      method: :get,
      interval_seconds: 300,
      timeout_seconds: 15,
      health_status: :up,
      logical_state: :active,
      last_checked_at: Time.ago(2 * @minute),
      last_success_at: Time.ago(2 * @minute)
    }
  end

  defp healthy_github_attrs do
    %{
      url: "https://github.com",
      method: :get,
      interval_seconds: 600,
      timeout_seconds: 20,
      health_status: :up,
      logical_state: :active,
      last_checked_at: Time.ago(4 * @minute),
      last_success_at: Time.ago(4 * @minute)
    }
  end

  defp down_attrs do
    %{
      url: "https://this-domain-should-not-exist-93f8a.com",
      method: :get,
      interval_seconds: 60,
      timeout_seconds: 10,
      health_status: :down,
      logical_state: :active,
      last_checked_at: Time.ago(1 * @minute)
    }
  end

  defp degraded_attrs do
    %{
      url: "https://httpbin.org/delay/3",
      method: :get,
      interval_seconds: 300,
      timeout_seconds: 10,
      health_status: :degraded,
      logical_state: :active,
      last_checked_at: Time.ago(3 * @minute),
      last_success_at: Time.ago(3 * @minute)
    }
  end

  defp ssl_expiring_attrs do
    %{
      url: "https://staging.example.com",
      method: :get,
      interval_seconds: 900,
      timeout_seconds: 25,
      health_status: :degraded,
      logical_state: :active,
      last_checked_at: Time.ago(5 * @minute),
      last_success_at: Time.ago(5 * @minute),
      ssl_expires_at: Time.ahead(5 * @day)
    }
  end

  defp domain_expiring_attrs do
    %{
      url: "https://api.example.org",
      method: :get,
      interval_seconds: 1800,
      timeout_seconds: 30,
      health_status: :degraded,
      logical_state: :active,
      last_checked_at: Time.ago(6 * @minute),
      last_success_at: Time.ago(6 * @minute),
      domain_expires_at: Time.ahead(14 * @day),
      last_domain_check_at: Time.ago(1 * @day)
    }
  end

  defp paused_attrs do
    %{
      url: "https://docs.example.com",
      method: :get,
      interval_seconds: 3600,
      timeout_seconds: 30,
      health_status: :unknown,
      logical_state: :paused,
      last_checked_at: Time.ago(2 * @day)
    }
  end
end

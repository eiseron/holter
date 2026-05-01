defmodule Holter.Seeds.Monitoring.Incidents do
  @moduledoc false

  alias Holter.Monitoring.{Incident, Monitor}
  alias Holter.Repo
  alias Holter.Seeds.Time

  @hour Time.hour()
  @day Time.day()

  def create_for(monitors) do
    insert(monitors.down, %{
      type: :downtime,
      started_at: Time.ago(2 * @hour),
      resolved_at: nil,
      root_cause: "Connection refused: host could not be resolved"
    })

    insert(monitors.ssl_expiring, %{
      type: :ssl_expiry,
      started_at: Time.ago(1 * @day),
      resolved_at: nil,
      root_cause: "TLS certificate expires in less than 7 days"
    })

    insert(monitors.healthy_example, %{
      type: :downtime,
      started_at: Time.ago(3 * @day),
      resolved_at: Time.ago(div(5 * @day, 2)),
      duration_seconds: 1_800,
      root_cause: "Upstream provider timeout (resolved automatically)"
    })

    insert(monitors.healthy_github, %{
      type: :defacement,
      started_at: Time.ago(4 * @day),
      resolved_at: Time.ago(div(7 * @day, 2)),
      duration_seconds: 1_800,
      root_cause: "Negative keyword detected on response body"
    })

    IO.puts("[seeds] Created 4 incidents (2 open, 2 resolved)")
    :ok
  end

  defp insert(monitor, attrs) do
    base = %{
      monitor_id: monitor.id,
      monitor_snapshot: Monitor.capture_snapshot(monitor)
    }

    %Incident{}
    |> Incident.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end
end

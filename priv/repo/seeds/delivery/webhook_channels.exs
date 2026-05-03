defmodule Holter.Seeds.Delivery.WebhookChannels do
  @moduledoc false

  alias Holter.Delivery.WebhookChannels

  def create_for(workspace, monitors) do
    {:ok, ops_slack} =
      WebhookChannels.create(%{
        workspace_id: workspace.id,
        name: "Ops Slack",
        url: "https://hooks.slack.com/services/T000000/B000000/SEEDDATA"
      })

    {:ok, pagerduty} =
      WebhookChannels.create(%{
        workspace_id: workspace.id,
        name: "PagerDuty critical",
        url: "https://events.pagerduty.com/v2/enqueue"
      })

    Enum.each(active_monitors(monitors), fn monitor ->
      {:ok, _} = WebhookChannels.link_monitor(monitor.id, ops_slack.id)
    end)

    Enum.each(critical_monitors(monitors), fn monitor ->
      {:ok, _} = WebhookChannels.link_monitor(monitor.id, pagerduty.id)
    end)

    IO.puts("[seeds] Created 2 webhook channels (Ops Slack, PagerDuty)")
    %{ops_slack: ops_slack, pagerduty: pagerduty}
  end

  defp active_monitors(m) do
    [m.healthy_example, m.healthy_github, m.down, m.degraded, m.ssl_expiring, m.domain_expiring]
  end

  defp critical_monitors(m), do: [m.down, m.degraded]
end

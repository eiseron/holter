defmodule Holter.Seeds.Integrations.Integrations do
  @moduledoc false

  alias Holter.Integrations.IntegrationEventsContext
  alias Holter.Integrations.IntegrationsContext

  def create_for(workspace) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, google_ads} =
      IntegrationsContext.create(%{
        workspace_id: workspace.id,
        provider: :google_ads,
        name: "Google Ads — Main Account",
        status: :active,
        credentials_encrypted: %{
          "access_token" => "seed_google_access_token",
          "refresh_token" => "seed_google_refresh_token",
          "expires_at" => DateTime.to_iso8601(DateTime.add(now, 3600))
        },
        settings: %{"customer_id" => "1234567890"}
      })

    {:ok, meta_ads} =
      IntegrationsContext.create(%{
        workspace_id: workspace.id,
        provider: :meta_ads,
        name: "Meta Ads — Main Account",
        status: :active,
        credentials_encrypted: %{
          "access_token" => "seed_meta_access_token",
          "expires_at" => DateTime.to_iso8601(DateTime.add(now, 5_184_000))
        },
        settings: %{"ad_account_id" => "act_9876543210"}
      })

    IntegrationEventsContext.log_event!(%{
      integration_id: google_ads.id,
      direction: :outbound,
      action: "pause_campaign",
      target: "campaign:gads-11111",
      payload_redacted: %{"event" => "incident_opened", "incident_id" => "seed-incident-1"},
      status: :success,
      duration_ms: 234,
      occurred_at: DateTime.add(now, -300)
    })

    IntegrationEventsContext.log_event!(%{
      integration_id: google_ads.id,
      direction: :outbound,
      action: "resume_campaign",
      target: "campaign:gads-11111",
      payload_redacted: %{"event" => "incident_resolved", "incident_id" => "seed-incident-1"},
      status: :success,
      duration_ms: 187,
      occurred_at: DateTime.add(now, -60)
    })

    IntegrationEventsContext.log_event!(%{
      integration_id: meta_ads.id,
      direction: :outbound,
      action: "pause_campaign",
      target: "campaign:meta-33333",
      payload_redacted: %{"event" => "incident_opened", "incident_id" => "seed-incident-1"},
      status: :failed,
      duration_ms: 502,
      occurred_at: DateTime.add(now, -180)
    })

    IO.puts("[seeds] Created 2 integrations (Google Ads, Meta Ads) with sample events")
    %{google_ads: google_ads, meta_ads: meta_ads}
  end
end

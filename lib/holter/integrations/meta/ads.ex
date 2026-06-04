defmodule Holter.Integrations.Meta.Ads do
  @moduledoc false

  @behaviour Holter.Integrations.Provider

  use Gettext, backend: HolterWeb.Gettext

  alias Holter.Integrations.Meta.Ads.OAuth
  alias Holter.Integrations.Meta.Ads.RequestBuilder

  @action_labels %{
    pause_campaign: gettext_noop("Pause campaign"),
    resume_campaign: gettext_noop("Resume campaign"),
    pause_ad_set: gettext_noop("Pause ad set"),
    resume_ad_set: gettext_noop("Resume ad set")
  }

  @impl true
  def display_name, do: "Meta Ads"

  @impl true
  def category, do: :ads

  @impl true
  def icon, do: "meta_ads"

  @impl true
  def supported_events, do: ["incident_opened", "incident_resolved"]

  @impl true
  def supported_actions, do: Map.keys(@action_labels)

  @impl true
  def action_label(action) do
    Gettext.gettext(HolterWeb.Gettext, Map.fetch!(@action_labels, action))
  end

  @impl true
  def oauth_url(_workspace_id, state), do: OAuth.authorization_url(state)

  @impl true
  def handle_callback(params, state), do: OAuth.exchange_code(params, state)

  @impl true
  def refresh(credentials), do: OAuth.refresh_token(credentials)

  @impl true
  def encode("pause_campaign", %{"id" => id}, integration),
    do: RequestBuilder.build(id, "PAUSED", integration)

  def encode("resume_campaign", %{"id" => id}, integration),
    do: RequestBuilder.build(id, "ACTIVE", integration)

  def encode("pause_ad_set", %{"id" => id}, integration),
    do: RequestBuilder.build(id, "PAUSED", integration)

  def encode("resume_ad_set", %{"id" => id}, integration),
    do: RequestBuilder.build(id, "ACTIVE", integration)

  def encode(_action, _target, _integration), do: :unsupported

  @impl true
  def revoke(credentials), do: OAuth.revoke_token(credentials)
end

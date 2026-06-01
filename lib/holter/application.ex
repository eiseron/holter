defmodule Holter.Application do
  @moduledoc false

  use Application

  alias Eiseron.I18n.Locale
  alias Holter.Observability.ObanHandler

  @impl true
  def start(_type, _args) do
    Application.put_env(:holter, HolterWeb.Gettext, default_locale: Locale.default())
    ObanHandler.attach()

    children =
      [
        HolterWeb.Telemetry,
        Holter.Repo,
        {DNSCluster, query: Application.get_env(:holter, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Holter.PubSub},
        Holter.Integrations.Vault,
        {Oban, Application.fetch_env!(:holter, Oban)},
        HolterWeb.Endpoint
      ] ++ delivery_children() ++ integrations_children()

    opts = [strategy: :one_for_one, name: Holter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    HolterWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp delivery_children do
    if Application.get_env(:holter, :start_delivery_event_consumer, true) do
      [Holter.Delivery.EventConsumer]
    else
      []
    end
  end

  defp integrations_children do
    rate_limiter = [{Holter.Integrations.RateLimiter, clean_period: :timer.minutes(10)}]

    event_consumer =
      if Application.get_env(:holter, :start_integrations_event_consumer, true) do
        [Holter.Integrations.EventConsumer]
      else
        []
      end

    rate_limiter ++ event_consumer
  end
end

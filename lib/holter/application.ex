defmodule Holter.Application do
  @moduledoc false

  use Application

  alias Holter.Observability.ObanHandler

  @impl true
  def start(_type, _args) do
    ObanHandler.attach()

    children =
      [
        HolterWeb.Telemetry,
        Holter.Repo,
        {DNSCluster, query: Application.get_env(:holter, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Holter.PubSub},
        {Oban, Application.fetch_env!(:holter, Oban)},
        HolterWeb.Endpoint
      ] ++ delivery_children()

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
end

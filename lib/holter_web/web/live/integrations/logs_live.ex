defmodule HolterWeb.Web.Integrations.LogsLive do
  use HolterWeb, :workspace_live_view

  import HolterWeb.Components.Integrations.IntegrationStatusBadge
  import HolterWeb.Components.Integrations.IntegrationSubnav

  alias Holter.Integrations.IntegrationEventsContext

  @page_size 25

  @impl true
  def mount(%{"id" => _id}, _session, socket) do
    integration = socket.assigns.current_integration
    workspace = socket.assigns.current_workspace

    {total_pages, current_page} = calculate_pages(integration.id, 1)
    activity = load_activity(integration.id, current_page)

    {:ok,
     socket
     |> assign(:page_title, provider_display_name(integration.provider))
     |> assign(:integration, integration)
     |> assign(:workspace, workspace)
     |> assign(:activity, activity)
     |> assign(:page, current_page)
     |> assign(:total_pages, total_pages)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = parse_page(params["page"])
    integration = socket.assigns.integration
    {total_pages, page} = calculate_pages(integration.id, page)
    activity = load_activity(integration.id, page)

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:total_pages, total_pages)
     |> assign(:activity, activity)}
  end

  defp calculate_pages(integration_id, requested_page) do
    IntegrationEventsContext.events_page_info(integration_id, @page_size, requested_page)
  end

  defp load_activity(integration_id, page) do
    IntegrationEventsContext.list_events_paginated(integration_id, page, @page_size)
  end

  defp parse_page(nil), do: 1

  defp parse_page(p) when is_binary(p) do
    case Integer.parse(p) do
      {n, ""} -> max(n, 1)
      _ -> 1
    end
  end

  defp provider_display_name(provider) do
    provider
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp event_status_class(:success), do: "h-badge-success"
  defp event_status_class(:failed), do: "h-badge-danger"
  defp event_status_class(:rate_limited), do: "h-badge-warning"
  defp event_status_class(:retried), do: "h-badge-neutral"

  defp event_status_label(:success), do: gettext("Success")
  defp event_status_label(:failed), do: gettext("Failed")
  defp event_status_label(:rate_limited), do: gettext("Rate limited")
  defp event_status_label(:retried), do: gettext("Retried")
  defp event_status_label(_), do: gettext("Unknown")

  defp event_direction_label(:outbound), do: gettext("Outbound")
  defp event_direction_label(:inbound), do: gettext("Inbound")
  defp event_direction_label(_), do: gettext("Unknown")
end

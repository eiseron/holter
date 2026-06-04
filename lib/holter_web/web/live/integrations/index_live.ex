defmodule HolterWeb.Web.Integrations.IndexLive do
  @moduledoc false
  use HolterWeb, :workspace_live_view

  import HolterWeb.Components.Integrations.ProviderLogo
  import HolterWeb.Components.Monitoring.DashboardHeader

  alias Holter.Integrations

  @impl true
  def mount(%{"workspace_slug" => _slug}, _session, socket) do
    workspace = socket.assigns.current_workspace
    integrations = Integrations.list_integrations(workspace.id)

    {:ok,
     socket
     |> assign(:workspace, workspace)
     |> assign(:integrations, integrations)
     |> assign(:page_title, gettext("Integrations"))}
  end

  defp provider_display_name(provider) do
    provider
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp status_class(:active), do: "h-badge-success"
  defp status_class(:reauth_required), do: "h-badge-warning"
  defp status_class(_), do: "h-badge-neutral"

  defp status_label(:active), do: gettext("Connected")
  defp status_label(:reauth_required), do: gettext("Reconnect needed")
  defp status_label(:rate_limited), do: gettext("Rate limited")
  defp status_label(:disabled), do: gettext("Disabled")
  defp status_label(:provider_down), do: gettext("Provider down")
  defp status_label(_), do: gettext("Unknown")
end

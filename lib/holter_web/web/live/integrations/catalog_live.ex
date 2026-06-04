defmodule HolterWeb.Web.Integrations.CatalogLive do
  use HolterWeb, :workspace_live_view

  import HolterWeb.Components.Integrations.ProviderLogo

  alias Holter.Integrations.Catalog

  @impl true
  def mount(%{"workspace_slug" => _slug}, _session, socket) do
    workspace = socket.assigns.current_workspace
    registry = Application.get_env(:holter, :integration_providers, %{})
    catalog = Catalog.build_catalog(registry)

    {:ok,
     socket
     |> assign(:workspace, workspace)
     |> assign(:page_title, gettext("Add integration"))
     |> assign(:catalog, catalog)}
  end

  defp category_label(:ads), do: gettext("Ads")
  defp category_label(:notifications), do: gettext("Notifications")
  defp category_label(:issue_tracking), do: gettext("Issue Tracking")
  defp category_label(:status_page), do: gettext("Status Page")
  defp category_label(:calendar), do: gettext("Calendar")
  defp category_label(other), do: other |> to_string() |> String.capitalize()

  defp translate_description(:google_ads), do: gettext("Pause/resume campaigns during incidents")
  defp translate_description(:meta_ads), do: gettext("Pause/resume campaigns and ad sets")
  defp translate_description(_), do: ""
end

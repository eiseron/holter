defmodule HolterWeb.Web.Monitoring.MonitorLive.DailyMetrics do
  use HolterWeb, :monitoring_live_view

  import HolterWeb.LiveView.SortPagination

  alias Holter.Monitoring
  alias Holter.Monitoring.DailyMetric
  alias HolterWeb.LiveView.{FilterParams, PubSubSubscriptions}

  @sortable_cols ~w(date uptime_percent avg_latency_ms total_downtime_minutes)
  @valid_filter_keys ~w(page page_size sort_by sort_dir)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    PubSubSubscriptions.subscribe_to_monitor(socket, id)
    monitor = Monitoring.get_monitor!(id)
    workspace = Monitoring.get_workspace!(monitor.workspace_id)

    {:ok,
     socket
     |> assign(:monitor, monitor)
     |> assign(:workspace_slug, workspace.slug)
     |> assign(:page_title, gettext("Daily Metrics"))
     |> assign(:metrics, [])
     |> assign(:page_number, 1)
     |> assign(:total_pages, 1)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = parse_filters(params)
    pagination = Monitoring.list_daily_metrics(socket.assigns.monitor.id, filters)

    path = ~p"/monitoring/monitor/#{socket.assigns.monitor.id}/daily_metrics"

    {:noreply,
     socket
     |> assign(pagination)
     |> assign(:filters, filters)
     |> assign(:patch_path, path)
     |> assign_page_links(path, filters)
     |> assign_sort_info(%{path: path, sortable_cols: @sortable_cols, filters: filters})}
  end

  @impl true
  def handle_info({event, _data}, socket)
      when event in [
             :log_created,
             :metric_updated,
             :monitor_updated,
             :incident_created,
             :incident_resolved,
             :incident_updated
           ] do
    {:noreply, push_patch(socket, to: socket.assigns.patch_path)}
  end

  defp parse_filters(params) do
    %{
      page: 1,
      page_size: 30,
      sort_by: "date",
      sort_dir: "desc"
    }
    |> Map.merge(FilterParams.normalize(params, @valid_filter_keys))
    |> FilterParams.cast_integer(:page, 1)
    |> FilterParams.cast_integer(:page_size, 30)
    |> FilterParams.validate_sort(@sortable_cols, "date")
  end
end

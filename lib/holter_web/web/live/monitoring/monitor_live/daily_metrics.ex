defmodule HolterWeb.Web.Monitoring.MonitorLive.DailyMetrics do
  use HolterWeb, :monitoring_live_view

  import HolterWeb.LiveView.SortPagination

  alias Holter.Monitoring
  alias Holter.Monitoring.DailyMetric

  @sortable_cols ~w(date uptime_percent avg_latency_ms total_downtime_minutes)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:monitor:#{id}")
    end

    monitor = Monitoring.get_monitor!(id)

    {:ok,
     socket
     |> assign(:monitor, monitor)
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
     |> assign_sort_info(path, @sortable_cols, filters)}
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

  @valid_filter_keys ~w(page page_size sort_by sort_dir)

  defp parse_filters(params) do
    %{
      page: 1,
      page_size: 30,
      sort_by: "date",
      sort_dir: "desc"
    }
    |> Map.merge(normalize_params(params))
    |> cast_integer_param(:page, 1)
    |> cast_integer_param(:page_size, 30)
    |> validate_sort_params()
  end

  defp validate_sort_params(filters) do
    sort_by =
      if filters.sort_by in @sortable_cols, do: filters.sort_by, else: "date"

    sort_dir =
      if filters.sort_dir in ~w(asc desc), do: filters.sort_dir, else: "desc"

    %{filters | sort_by: sort_by, sort_dir: sort_dir}
  end

  defp normalize_params(params) do
    for {k, v} <- params, k in @valid_filter_keys, into: %{} do
      {String.to_existing_atom(k), v}
    end
  end

  defp cast_integer_param(filters, key, default) do
    value =
      case Map.get(filters, key) do
        v when is_binary(v) -> String.to_integer(v)
        v when is_integer(v) -> v
        _ -> default
      end

    Map.put(filters, key, value)
  end
end

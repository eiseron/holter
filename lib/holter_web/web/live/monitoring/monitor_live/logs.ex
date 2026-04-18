defmodule HolterWeb.Web.Monitoring.MonitorLive.Logs do
  use HolterWeb, :monitoring_live_view

  import HolterWeb.LiveView.SortPagination

  alias Holter.Monitoring

  @sortable_cols ~w(checked_at status latency_ms)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:monitor:#{id}")
    end

    monitor = Monitoring.get_monitor!(id)

    {:ok,
     socket
     |> assign(:monitor, monitor)
     |> assign(:page_title, gettext("Monitor Logs"))
     |> assign(:logs, [])
     |> assign(:filters, %{})
     |> assign(:page_number, 1)
     |> assign(:total_pages, 1)
     |> assign(:form, to_form(%{}, as: "filters"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = parse_filters(params, socket.assigns[:timezone] || "Etc/UTC")
    pagination = Monitoring.list_monitor_logs(socket.assigns.monitor, filters)
    form = to_form(Map.new(filters, fn {k, v} -> {Atom.to_string(k), v} end), as: "filters")

    path =
      ~p"/monitoring/monitor/#{socket.assigns.monitor.id}/logs"

    {:noreply,
     socket
     |> assign(pagination)
     |> assign(:filters, filters)
     |> assign(:form, form)
     |> assign(:patch_path, path)
     |> assign_page_links(path, filters)
     |> assign_sort_info(%{path: path, sortable_cols: @sortable_cols, filters: filters})}
  end

  @impl true
  def handle_event("filter_updated", %{"filters" => params}, socket) do
    form_filters =
      params
      |> Map.new(fn {k, v} -> {k, empty_to_nil(v)} end)
      |> Enum.reject(fn {k, v} -> is_nil(v) or k in ["sort_by", "sort_dir"] end)
      |> Map.new()

    current_sort = %{
      sort_by: socket.assigns.filters.sort_by,
      sort_dir: socket.assigns.filters.sort_dir
    }

    {:noreply,
     push_patch(socket,
       to:
         socket.assigns.patch_path <> "?" <> encode_filters(Map.merge(current_sort, form_filters))
     )}
  end

  @impl true
  def handle_info({event, _data}, socket)
      when event in [
             :log_created,
             :monitor_updated,
             :incident_created,
             :incident_resolved,
             :incident_updated
           ] do
    {:noreply, push_patch(socket, to: socket.assigns.patch_path)}
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  @valid_filter_keys ~w(status start_date end_date page page_size sort_by sort_dir)

  defp parse_filters(params, timezone) do
    %{
      status: nil,
      start_date: nil,
      end_date: nil,
      timezone: timezone,
      page: 1,
      page_size: 50,
      sort_by: "checked_at",
      sort_dir: "desc"
    }
    |> Map.merge(normalize_params(params))
    |> Map.put(:timezone, timezone)
    |> cast_integer_param(:page, 1)
    |> cast_integer_param(:page_size, 50)
    |> validate_sort_params()
  end

  defp validate_sort_params(filters) do
    sort_by =
      if filters.sort_by in @sortable_cols, do: filters.sort_by, else: "checked_at"

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

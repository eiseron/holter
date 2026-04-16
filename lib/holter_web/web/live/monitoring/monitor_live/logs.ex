defmodule HolterWeb.Web.Monitoring.MonitorLive.Logs do
  use HolterWeb, :monitoring_live_view

  alias Holter.Monitoring

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:monitor:#{id}")
    end

    monitor = Monitoring.get_monitor!(id)

    {:ok,
     socket
     |> assign(:monitor, monitor)
     |> assign(:logs, [])
     |> assign(:filters, %{})
     |> assign(:page_number, 1)
     |> assign(:total_pages, 1)
     |> assign(:form, to_form(%{}, as: "filters"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = parse_filters(params)
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
     |> assign_sort_info(path, filters)}
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

  @sortable_cols ~w(checked_at status latency_ms)

  defp assign_sort_info(socket, path, filters) do
    sort_info = Map.new(@sortable_cols, fn col -> {col, build_sort_col(path, filters, col)} end)
    assign(socket, :sort_info, sort_info)
  end

  defp build_sort_col(path, filters, col_key) do
    active = to_string(filters.sort_by) == col_key

    next_dir =
      cond do
        active and filters.sort_dir == "asc" -> "desc"
        active -> "asc"
        true -> "desc"
      end

    new_filters = Map.merge(filters, %{sort_by: col_key, sort_dir: next_dir, page: 1})

    %{
      url: path <> "?" <> encode_filters(new_filters),
      active: active,
      dir: if(active, do: filters.sort_dir)
    }
  end

  defp assign_page_links(socket, path, filters) do
    %{page_number: page, total_pages: total} = socket.assigns

    page_url = fn p -> path <> "?" <> encode_filters(Map.put(filters, :page, p)) end

    socket
    |> assign(:prev_page_url, if(page > 1, do: page_url.(page - 1)))
    |> assign(:next_page_url, if(page < total, do: page_url.(page + 1)))
    |> assign(
      :page_links,
      for(p <- max(1, page - 2)..min(total, page + 2), do: {p, page_url.(p)})
    )
  end

  defp encode_filters(filters) do
    filters
    |> Enum.reject(fn {k, v} ->
      is_nil(v) or v == "" or k in [:id, :workspace_slug, "id", "workspace_slug"]
    end)
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> URI.encode_query()
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  @valid_filter_keys ~w(status start_date end_date page page_size sort_by sort_dir)

  defp parse_filters(params) do
    %{
      status: nil,
      start_date: nil,
      end_date: nil,
      page: 1,
      page_size: 50,
      sort_by: "checked_at",
      sort_dir: "desc"
    }
    |> Map.merge(normalize_params(params))
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

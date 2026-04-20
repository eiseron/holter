defmodule HolterWeb.Web.Monitoring.MonitorLive.Incidents do
  use HolterWeb, :monitoring_live_view

  import HolterWeb.LiveView.SortPagination

  alias Holter.Monitoring
  alias HolterWeb.LiveView.{FilterParams, PubSubSubscriptions}

  @valid_filter_keys ~w(page page_size type state date_from date_to)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    PubSubSubscriptions.subscribe_to_monitor(socket, id)
    monitor = Monitoring.get_monitor!(id)

    {:ok,
     socket
     |> assign(:monitor, monitor)
     |> assign(:page_title, gettext("Incidents"))
     |> assign(:incidents, [])
     |> assign(:filters, %{})
     |> assign(:page_number, 1)
     |> assign(:total_pages, 1)
     |> assign(:form, to_form(%{}, as: "filters"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = parse_filters(params)

    %{data: incidents, meta: meta} =
      Monitoring.list_incidents_filtered(%{
        monitor_id: socket.assigns.monitor.id,
        page: filters.page,
        page_size: filters.page_size,
        type: filters.type,
        state: filters.state,
        date_from: filters.date_from,
        date_to: filters.date_to
      })

    total_pages = ceil(meta.total / meta.page_size) |> max(1)
    path = ~p"/monitoring/monitor/#{socket.assigns.monitor.id}/incidents"
    form = to_form(Map.new(filters, fn {k, v} -> {Atom.to_string(k), v} end), as: "filters")

    {:noreply,
     socket
     |> assign(:incidents, incidents)
     |> assign(:filters, filters)
     |> assign(:page_number, meta.page)
     |> assign(:total_pages, total_pages)
     |> assign(:form, form)
     |> assign(:patch_path, path)
     |> assign_page_links(path, filters)}
  end

  @impl true
  def handle_event("filter_updated", %{"filters" => params}, socket) do
    form_filters =
      params
      |> Map.new(fn {k, v} -> {k, empty_to_nil(v)} end)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    {:noreply,
     push_patch(socket,
       to: socket.assigns.patch_path <> "?" <> encode_filters(form_filters)
     )}
  end

  @impl true
  def handle_info({event, _data}, socket)
      when event in [
             :incident_created,
             :incident_resolved,
             :incident_updated,
             :monitor_updated
           ] do
    {:noreply, push_patch(socket, to: socket.assigns.patch_path)}
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp parse_filters(params) do
    %{
      page: 1,
      page_size: 25,
      type: nil,
      state: nil,
      date_from: nil,
      date_to: nil
    }
    |> Map.merge(FilterParams.normalize(params, @valid_filter_keys))
    |> FilterParams.cast_integer(:page, 1)
    |> FilterParams.cast_integer(:page_size, 25)
    |> cast_atom_param(:type, [:downtime, :defacement, :ssl_expiry])
    |> cast_atom_param(:state, [:open, :resolved])
    |> cast_date_param(:date_from)
    |> cast_date_param(:date_to)
  end

  defp cast_date_param(filters, key) do
    case Map.get(filters, key) do
      v when is_binary(v) ->
        case Date.from_iso8601(v) do
          {:ok, date} -> Map.put(filters, key, date)
          _ -> Map.put(filters, key, nil)
        end

      _ ->
        filters
    end
  end

  defp cast_atom_param(filters, key, valid_values) do
    case Map.get(filters, key) do
      v when is_binary(v) ->
        atom = String.to_existing_atom(v)
        if atom in valid_values, do: Map.put(filters, key, atom), else: Map.put(filters, key, nil)

      _ ->
        filters
    end
  rescue
    ArgumentError -> Map.put(filters, key, nil)
  end
end

defmodule HolterWeb.Web.Monitoring.MonitorLive.Logs do
  use HolterWeb, :live_view

  alias Holter.Monitoring

  @impl true
  def mount(%{"workspace_slug" => slug, "id" => id}, _session, socket) do
    case Monitoring.get_workspace_by_slug(slug) do
      {:ok, workspace} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:monitor:#{id}")
        end

        monitor = Monitoring.get_monitor!(id)

        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:monitor, monitor)
         |> assign(:logs, [])
         |> assign(:selected_log, nil)
         |> assign(:formatted_snippet, nil)
         |> assign(:formatted_headers, nil)
         |> assign(:evidence_inherited, false)
         |> assign(:evidence_source_time, nil)
         |> assign(:filters, %{})
         |> assign(:page_number, 1)
         |> assign(:total_pages, 1)
         |> assign(:form, to_form(%{}, as: "filters"))}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Workspace not found")
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = parse_filters(params)
    pagination = Monitoring.list_monitor_logs(socket.assigns.monitor, filters)
    form = to_form(Map.new(filters, fn {k, v} -> {Atom.to_string(k), v} end), as: "filters")

    path =
      ~p"/monitoring/workspaces/#{socket.assigns.workspace.slug}/monitor/#{socket.assigns.monitor.id}/logs"

    {:noreply,
     socket
     |> assign(pagination)
     |> assign(:filters, filters)
     |> assign(:form, form)
     |> assign(:patch_path, path)}
  end

  @impl true
  def handle_event("filter_updated", %{"filters" => params}, socket) do
    query =
      params
      |> Map.new(fn {k, v} -> {k, empty_to_nil(v)} end)
      |> Enum.reject(fn {k, v} -> is_nil(v) or k in ["id", "workspace_slug"] or v == "" end)
      |> Enum.into(%{})

    {:noreply,
     push_patch(socket, to: socket.assigns.patch_path <> "?" <> URI.encode_query(query))}
  end

  @impl true
  def handle_event("view_evidence", %{"id" => log_id}, socket) do
    clicked_log = Monitoring.get_monitor_log!(log_id)

    {payload_log, inherited?} =
      if has_technical_payload?(clicked_log) do
        {clicked_log, false}
      else
        case find_nearest_technical_payload(socket.assigns.logs, clicked_log) do
          nil -> {clicked_log, false}
          fallback -> {fallback, true}
        end
      end

    {:noreply,
     socket
     |> assign(:selected_log, clicked_log)
     |> assign(:formatted_snippet, format_evidence_snippet(payload_log.response_snippet))
     |> assign(:formatted_headers, format_response_headers(payload_log.response_headers))
     |> assign(:evidence_inherited, inherited?)
     |> assign(:evidence_source_time, if(inherited?, do: payload_log.checked_at))}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_log, nil)
     |> assign(:formatted_snippet, nil)
     |> assign(:formatted_headers, nil)
     |> assign(:evidence_inherited, false)
     |> assign(:evidence_source_time, nil)}
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

  defp format_response_headers(nil), do: nil

  defp format_response_headers(headers) when is_map(headers) do
    Jason.encode!(headers, pretty: true)
  end

  defp has_technical_payload?(log) do
    has_headers?(log.response_headers) or
      has_content?(log.response_snippet)
  end

  defp has_headers?(nil), do: false
  defp has_headers?(headers), do: map_size(headers) > 0

  defp has_content?(nil), do: false
  defp has_content?(""), do: false
  defp has_content?(_), do: true

  defp find_nearest_technical_payload(logs, current_log) do
    logs
    |> Enum.filter(fn l ->
      DateTime.compare(l.checked_at, current_log.checked_at) != :gt and
        l.id != current_log.id and
        has_technical_payload?(l)
    end)
    |> List.first()
  end

  defp format_evidence_snippet(nil), do: nil

  @snippet_format_threshold 100_000

  defp format_evidence_snippet(snippet) do
    if byte_size(snippet) > @snippet_format_threshold do
      snippet
    else
      case Jason.decode(snippet) do
        {:ok, decoded} -> Jason.encode!(decoded, pretty: true)
        {:error, _} -> snippet
      end
    end
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp parse_filters(params) do
    %{status: nil, start_date: nil, end_date: nil, page: 1, page_size: 50}
    |> Map.merge(normalize_params(params))
    |> cast_integer_param(:page, 1)
    |> cast_integer_param(:page_size, 50)
  end

  defp normalize_params(params) do
    for {k, v} <- params, into: %{}, do: {String.to_atom(k), v}
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

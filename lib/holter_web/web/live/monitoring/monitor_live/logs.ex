defmodule HolterWeb.Web.Monitoring.MonitorLive.Logs do
  use HolterWeb, :live_view

  alias Holter.Monitoring
  alias Holter.Monitoring.MonitorLog

  @impl true
  def mount(%{"workspace_slug" => slug, "id" => id}, _session, socket) do
    case Monitoring.get_workspace_by_slug(slug) do
      {:ok, workspace} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:monitor:#{id}")
        end

        monitor = Monitoring.get_monitor!(id)
        filters = %{status: nil, start_date: nil, end_date: nil}
        logs = Monitoring.list_monitor_logs(monitor, filters)

        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:monitor, monitor)
         |> assign(:logs, logs)
         |> assign(:selected_log, nil)
         |> assign(:formatted_snippet, nil)
         |> assign(:formatted_headers, nil)
         |> assign(:evidence_inherited, false)
         |> assign(:evidence_source_time, nil)
         |> assign(:filters, filters)
         |> assign(:status_options, MonitorLog.status_options())
         |> assign(:form, to_form(%{}, as: "filters"))}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Workspace not found")
         |> push_navigate(to: "/")}
    end
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
    {:noreply,
     assign(socket,
       logs: Monitoring.list_monitor_logs(socket.assigns.monitor, socket.assigns.filters)
     )}
  end

  @impl true
  def handle_event("filter_updated", %{"filters" => params}, socket) do
    filters =
      socket.assigns.filters
      |> Map.merge(params)
      |> Map.new(fn {k, v} -> {k, empty_to_nil(v)} end)

    logs = Monitoring.list_monitor_logs(socket.assigns.monitor, filters)

    {:noreply,
     socket
     |> assign(:logs, logs)
     |> assign(:filters, filters)}
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
end

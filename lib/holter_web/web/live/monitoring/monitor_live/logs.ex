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
        logs = Monitoring.list_monitor_logs(id)

        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:monitor, monitor)
         |> assign(:logs, logs)
         |> assign(:selected_log, nil)
         |> assign(:formatted_snippet, nil)
         |> assign(:formatted_headers, nil)
         |> assign(:evidence_inherited, false)
         |> assign(:evidence_source_time, nil)}

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
    {:noreply, assign(socket, logs: Monitoring.list_monitor_logs(socket.assigns.monitor.id))}
  end

  @impl true
  def handle_event("view_evidence", %{"id" => log_id}, socket) do
    log = Monitoring.get_monitor_log!(log_id)

    {evidence_log, inherited?} =
      if has_evidence?(log) do
        {log, false}
      else
        case find_nearest_evidence(socket.assigns.logs, log) do
          nil -> {log, false}
          fallback -> {fallback, true}
        end
      end

    {:noreply,
     socket
     |> assign(:selected_log, evidence_log)
     |> assign(:formatted_snippet, format_evidence_snippet(evidence_log.response_snippet))
     |> assign(:formatted_headers, format_response_headers(evidence_log.response_headers))
     |> assign(:evidence_inherited, inherited?)
     |> assign(:evidence_source_time, if(inherited?, do: evidence_log.checked_at))}
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

  defp has_evidence?(log) do
    not is_nil(log.response_headers) or
      not is_nil(log.response_snippet) or
      not is_nil(log.error_message)
  end

  defp find_nearest_evidence(logs, current_log) do
    logs
    |> Enum.filter(fn l ->
      DateTime.compare(l.checked_at, current_log.checked_at) != :gt and
        l.id != current_log.id and
        has_evidence?(l)
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
end

defmodule HolterWeb.Web.Monitoring.MonitorLive.LogDetail do
  use HolterWeb, :monitoring_live_view

  alias Holter.Monitoring

  @impl true
  def mount(%{"log_id" => log_id}, _session, socket) do
    log = Monitoring.get_monitor_log!(log_id)
    monitor = Monitoring.get_monitor!(log.monitor_id)

    {payload_log, inherited?} =
      if has_technical_payload?(log) do
        {log, false}
      else
        case Monitoring.find_nearest_technical_log(monitor.id, log) do
          nil -> {log, false}
          source -> {source, true}
        end
      end

    {:ok,
     socket
     |> assign(:monitor, monitor)
     |> assign(:log, log)
     |> assign(:payload_log, payload_log)
     |> assign(:evidence_inherited, inherited?)
     |> assign(:formatted_snippet, format_evidence_snippet(payload_log.response_snippet))
     |> assign(:formatted_headers, format_response_headers(payload_log.response_headers))}
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

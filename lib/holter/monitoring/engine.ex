defmodule Holter.Monitoring.Engine do
  @moduledoc """
  Core monitoring logic detached from Oban workers.
  Coordinates response processing, incident lifecycle, and monitor log creation.
  """

  use Gettext, backend: HolterWeb.Gettext

  alias Holter.Monitoring
  alias Holter.Monitoring.Engine.{IncidentManager, ResponseValidator}
  alias Holter.Monitoring.{Monitor, Monitors}
  alias Holter.Network.Guard, as: NetworkGuard

  def process_response(monitor, response, metadata) do
    Logger.metadata(
      monitor_id: monitor.id,
      workspace_id: monitor.workspace_id,
      context: :monitoring_check
    )

    ip = extract_ip(response)
    metadata = Map.put(metadata, :ip, ip)

    params =
      if NetworkGuard.restricted_ip?(ip) do
        build_restricted_params(response, metadata)
      else
        ResponseValidator.validate_response(monitor, response, metadata)
      end

    finalize_check(monitor, params)
  end

  def handle_failure(monitor, error, duration_ms) do
    params = build_failure_params(error, duration_ms)
    finalize_check(monitor, params)
  end

  defp build_restricted_params(response, metadata) do
    %{
      check_status: :down,
      log_status: :down,
      status_code: response.status,
      duration_ms: metadata.duration_ms,
      error_msg: gettext("Access to restricted internal address blocked"),
      snippet: nil,
      headers: nil,
      ip: metadata.ip,
      redirect_count: Map.get(metadata, :redirects, 0),
      last_redirect_url: Map.get(metadata, :last_url),
      redirect_list: Map.get(metadata, :redirect_list, []),
      defacement_in_body: false
    }
  end

  defp build_failure_params(error, duration_ms) do
    %{
      check_status: :down,
      log_status: :down,
      status_code: nil,
      duration_ms: duration_ms,
      error_msg: Exception.message(error),
      snippet: nil,
      headers: nil,
      ip: nil,
      defacement_in_body: false
    }
  end

  defp finalize_check(monitor, params) do
    now = DateTime.utc_now()
    snapshot = Monitor.capture_snapshot(monitor)

    ctx = build_incident_context(params, snapshot, now)
    ops = IncidentManager.determine_incident_ops(ctx)
    IncidentManager.apply_incident_ops(monitor, ops, ctx)

    {active_incident_id, effective_log_status} =
      compute_effective_status(monitor.id, params.log_status)

    log_ctx = %{
      snapshot: snapshot,
      now: now,
      incident_id: active_incident_id,
      status: effective_log_status
    }

    record_monitor_log(build_log_attrs(monitor, params, log_ctx))

    updated_monitor =
      update_monitor_state(monitor, %{
        check_status: params.check_status,
        effective_status: effective_log_status,
        now: now
      })

    {:ok, updated_monitor}
  end

  defp build_incident_context(params, snapshot, now) do
    %{
      check_status: params.check_status,
      error_msg: params.error_msg,
      positive_ok: Map.get(params, :positive_ok, true),
      downtime_error_msg: Map.get(params, :downtime_error_msg, params.error_msg),
      defacement_error_msg: Map.get(params, :defacement_error_msg, params.error_msg),
      snapshot: snapshot,
      now: now,
      defacement_in_body: Map.get(params, :defacement_in_body, false)
    }
  end

  defp compute_effective_status(monitor_id, log_status) do
    open_incidents = Monitoring.list_open_incidents(monitor_id)
    {active_incident_id, incident_status} = IncidentManager.pick_active_incident(open_incidents)

    effective =
      if Monitors.status_severity(incident_status) > Monitors.status_severity(log_status),
        do: incident_status,
        else: log_status

    {active_incident_id, effective}
  end

  defp build_log_attrs(monitor, params, ctx) do
    %{
      monitor_id: monitor.id,
      status: ctx.status,
      incident_id: ctx.incident_id,
      status_code: params.status_code,
      latency_ms: params.duration_ms,
      error_message: params.error_msg,
      response_snippet: params.snippet,
      response_headers: params.headers,
      response_ip: params.ip,
      region: get_region(),
      redirect_count: params[:redirect_count],
      last_redirect_url: params[:last_redirect_url],
      redirect_list: params[:redirect_list] || [],
      checked_at: ctx.now,
      monitor_snapshot: ctx.snapshot
    }
  end

  defp update_monitor_state(monitor, %{
         check_status: check_status,
         effective_status: effective_status,
         now: now
       }) do
    {:ok, updated_monitor} =
      Monitoring.update_monitor(monitor, %{
        health_status: effective_status,
        last_checked_at: now,
        last_success_at: if(check_status == :up, do: now, else: monitor.last_success_at)
      })

    updated_monitor
  end

  defp record_monitor_log(attrs), do: Monitoring.create_monitor_log(attrs)

  defp extract_ip(response) do
    case response.private[:req_remote_addr] do
      nil -> nil
      addr -> :inet.ntoa(addr) |> to_string()
    end
  end

  defp get_region, do: System.get_env("MONITOR_REGION", "br-sp-1")
end

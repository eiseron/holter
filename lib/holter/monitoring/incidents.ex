defmodule Holter.Monitoring.Incidents do
  @moduledoc false

  use Gettext, backend: HolterWeb.Gettext

  import Ecto.Query
  alias Holter.Monitoring.{Broadcaster, Incident, Pagination}
  alias Holter.Repo

  @label_left 40
  @chart_right 760

  def get_incident!(id), do: Repo.get!(Incident, id)

  def get_incident(id) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         %Incident{} = incident <- Repo.get(Incident, id) do
      {:ok, incident}
    else
      _ -> {:error, :not_found}
    end
  end

  def list_incidents_filtered(params) do
    monitor_id = Map.fetch!(params, :monitor_id)
    page = Map.get(params, :page, 1) |> max(1)
    page_size = Pagination.resolve_page_size(Map.get(params, :page_size))

    base =
      Incident
      |> where([i], i.monitor_id == ^monitor_id)
      |> maybe_filter_by(:type, params)
      |> maybe_filter_by(:state, params)
      |> maybe_filter_by(:date_from, params)
      |> maybe_filter_by(:date_to, params)
      |> order_by([i], desc: i.started_at)

    total = Repo.aggregate(base, :count, :id)
    incidents = base |> Pagination.paginate_query(page, page_size) |> Repo.all()
    %{data: incidents, meta: %{page: page, page_size: page_size, total: total}}
  end

  def incident_to_health(%{type: :downtime}), do: :down
  def incident_to_health(%{type: :defacement}), do: :compromised

  def incident_to_health(%{type: :ssl_expiry, root_cause: rc}) do
    cond do
      is_nil(rc) -> :degraded
      String.contains?(rc, "Critical") -> :compromised
      String.contains?(rc, "expired") -> :compromised
      String.contains?(rc, "SSL Error") -> :compromised
      true -> :degraded
    end
  end

  def incident_to_health(%{type: :domain_expiry, root_cause: rc}) do
    cond do
      is_nil(rc) -> :degraded
      String.contains?(rc, "Critical") -> :compromised
      String.contains?(rc, "expired") -> :compromised
      true -> :degraded
    end
  end

  def incident_to_health(_), do: :unknown

  def type_label(:downtime), do: gettext("Downtime")
  def type_label(:defacement), do: gettext("Defacement")
  def type_label(:ssl_expiry), do: gettext("SSL Expiry")
  def type_label(:domain_expiry), do: gettext("Domain Expiry")

  def list_incidents(monitor_id) do
    Incident
    |> where([i], i.monitor_id == ^monitor_id)
    |> order_by([i], desc: i.started_at)
    |> Repo.all()
  end

  def get_open_incident(monitor_id) do
    Incident
    |> where([i], i.monitor_id == ^monitor_id and is_nil(i.resolved_at))
    |> Repo.one()
  end

  def get_open_incident(monitor_id, type) do
    Incident
    |> where([i], i.monitor_id == ^monitor_id and i.type == ^type and is_nil(i.resolved_at))
    |> Repo.one()
  end

  def list_open_incidents(monitor_id) do
    Incident
    |> where([i], i.monitor_id == ^monitor_id and is_nil(i.resolved_at))
    |> Repo.all()
  end

  def create_incident(attrs \\ %{}) do
    case %Incident{}
         |> Incident.changeset(attrs)
         |> Repo.insert() do
      {:ok, incident} ->
        Broadcaster.broadcast({:ok, incident}, :incident_created, incident.monitor_id)
        Broadcaster.broadcast_incident_opened(incident)
        {:ok, incident}

      error ->
        error
    end
  end

  def open_incident_already_exists?({:error, %Ecto.Changeset{} = cs}) do
    cs.errors
    |> Keyword.get_values(:monitor_id)
    |> Enum.any?(fn {_msg, opts} -> opts[:constraint] == :unique end)
  end

  def open_incident_already_exists?(_), do: false

  def update_incident(%Incident{} = incident, attrs) do
    case incident
         |> Incident.changeset(attrs)
         |> Repo.update() do
      {:ok, updated} ->
        Broadcaster.broadcast({:ok, updated}, :incident_updated, updated.monitor_id)
        {:ok, updated}

      error ->
        error
    end
  end

  def resolve_incident(%Incident{} = incident, resolved_at) do
    duration = DateTime.diff(resolved_at, incident.started_at)

    {count, _} =
      Repo.update_all(
        from(i in Incident, where: i.id == ^incident.id and is_nil(i.resolved_at)),
        set: [resolved_at: resolved_at, duration_seconds: duration]
      )

    if count == 1 do
      updated = %{incident | resolved_at: resolved_at, duration_seconds: duration}
      Broadcaster.broadcast({:ok, updated}, :incident_resolved, updated.monitor_id)
      Broadcaster.broadcast_incident_resolved(updated)
      {:ok, updated}
    else
      {:ok, incident}
    end
  end

  def list_incidents_for_gantt(%{monitor_id: monitor_id} = params) do
    range_start = Map.fetch!(params, :range_start)
    range_end = Map.fetch!(params, :range_end)

    Incident
    |> where([i], i.monitor_id == ^monitor_id)
    |> maybe_filter_by(:type, params)
    |> maybe_filter_by(:state, params)
    |> where([i], i.started_at <= ^range_end)
    |> where([i], is_nil(i.resolved_at) or i.resolved_at >= ^range_start)
    |> order_by([i], asc: i.started_at)
    |> Repo.all()
  end

  def build_gantt_chart_data([], _now) do
    %{bars: [], x_labels: [], has_incidents: false}
  end

  def build_gantt_chart_data(incidents, now) do
    range_start =
      incidents |> Enum.min_by(&DateTime.to_unix(&1.started_at)) |> Map.get(:started_at)

    range_end =
      incidents |> Enum.map(fn i -> i.resolved_at || now end) |> Enum.max_by(&DateTime.to_unix/1)

    min_ts = DateTime.to_unix(range_start)
    max_ts = max(DateTime.to_unix(range_end), min_ts + 1)
    coord = {@label_left, @chart_right}

    bars =
      Enum.map(incidents, fn inc ->
        end_dt = inc.resolved_at || now

        x_start =
          inc.started_at |> map_x({min_ts, max_ts}, coord) |> clamp(@label_left, @chart_right)

        x_end = end_dt |> map_x({min_ts, max_ts}, coord) |> clamp(@label_left, @chart_right)

        %{
          id: inc.id,
          x: Float.round(x_start, 1),
          width: Float.round(max(x_end - x_start, 2.0), 1),
          lane: lane_for(inc.type),
          fill: fill_for(inc.type),
          open?: is_nil(inc.resolved_at)
        }
      end)

    total_seconds = max(DateTime.diff(range_end, range_start), 1)
    total_days = max(div(total_seconds, 86_400), 1)
    step_days = max(1, div(total_days, 6))

    x_labels =
      0..total_days//step_days
      |> Enum.map(fn offset ->
        dt = DateTime.add(range_start, offset * 86_400, :second)
        x = dt |> map_x({min_ts, max_ts}, coord) |> clamp(@label_left, @chart_right)
        %{x: Float.round(x, 1), label: Calendar.strftime(DateTime.to_date(dt), "%m/%d")}
      end)

    %{bars: bars, x_labels: x_labels, has_incidents: true}
  end

  defp maybe_filter_by(query, :type, %{type: type}) when not is_nil(type) do
    where(query, [i], i.type == ^type)
  end

  defp maybe_filter_by(query, :state, %{state: :open}) do
    where(query, [i], is_nil(i.resolved_at))
  end

  defp maybe_filter_by(query, :state, %{state: :resolved}) do
    where(query, [i], not is_nil(i.resolved_at))
  end

  defp maybe_filter_by(query, :date_from, %{date_from: date}) when not is_nil(date) do
    dt = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    where(query, [i], i.started_at >= ^dt)
  end

  defp maybe_filter_by(query, :date_to, %{date_to: date}) when not is_nil(date) do
    dt = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
    where(query, [i], i.started_at <= ^dt)
  end

  defp maybe_filter_by(query, _, _), do: query

  defp map_x(dt, {min_ts, max_ts}, {label_left, svg_right}) do
    ts = DateTime.to_unix(dt)
    label_left + (ts - min_ts) / (max_ts - min_ts) * (svg_right - label_left) * 1.0
  end

  defp clamp(value, min, max), do: value |> max(min * 1.0) |> min(max * 1.0)

  defp lane_for(:downtime), do: 0
  defp lane_for(:defacement), do: 1
  defp lane_for(:ssl_expiry), do: 2
  defp lane_for(:domain_expiry), do: 3

  defp fill_for(:downtime), do: "var(--color-status-down)"
  defp fill_for(:defacement), do: "var(--color-status-compromised)"
  defp fill_for(:ssl_expiry), do: "var(--color-status-degraded)"
  defp fill_for(:domain_expiry), do: "var(--color-status-degraded)"
end

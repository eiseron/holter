defmodule Holter.Monitoring.Incidents do
  @moduledoc false

  import Ecto.Query
  alias Holter.Monitoring.{Broadcaster, Incident, Pagination}
  alias Holter.Repo

  def get_incident!(id), do: Repo.get!(Incident, id)

  def get_incident(id) do
    case Repo.get(Incident, id) do
      nil -> {:error, :not_found}
      incident -> {:ok, incident}
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

  def incident_to_health(_), do: :unknown

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
      {:ok, updated}
    else
      {:ok, incident}
    end
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
end

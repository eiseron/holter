defmodule Holter.Monitoring.MonitorLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "monitor_logs" do
    field :status, Ecto.Enum, values: [:up, :down, :degraded, :compromised, :unknown]
    field :status_code, :integer
    field :latency_ms, :integer
    field :region, :string
    field :response_snippet, :string
    field :response_headers, :map
    field :response_ip, :string
    field :error_message, :string
    field :redirect_count, :integer
    field :last_redirect_url, :string
    field :redirect_list, {:array, :map}, default: []
    field :checked_at, :utc_datetime_usec
    field :monitor_snapshot, :map

    belongs_to :monitor, Holter.Monitoring.Monitor
    belongs_to :incident, Holter.Monitoring.Incident

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(monitor_log, attrs) do
    monitor_log
    |> cast(attrs, [
      :monitor_id,
      :status,
      :status_code,
      :latency_ms,
      :region,
      :response_snippet,
      :response_headers,
      :response_ip,
      :error_message,
      :redirect_count,
      :last_redirect_url,
      :redirect_list,
      :checked_at,
      :monitor_snapshot,
      :incident_id
    ])
    |> validate_required([:monitor_id, :status, :checked_at])
  end

  @doc """
  Returns the available status values for form selects.
  """
  def status_options do
    [:up, :down, :degraded, :compromised, :unknown]
    |> Enum.map(&to_string/1)
    |> Enum.map(fn status -> {String.capitalize(status), status} end)
  end
end

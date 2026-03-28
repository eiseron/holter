defmodule Holter.Monitoring.MonitorLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "monitor_logs" do
    field :status, Ecto.Enum, values: [:success, :failure, :suspicious, :unknown]
    field :status_code, :integer
    field :latency_ms, :integer
    field :region, :string
    field :response_snippet, :string
    field :error_message, :string
    field :checked_at, :utc_datetime

    belongs_to :monitor, Holter.Monitoring.Monitor

    timestamps(type: :utc_datetime)
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
      :error_message,
      :checked_at
    ])
    |> validate_required([:monitor_id, :status, :checked_at])
  end
end

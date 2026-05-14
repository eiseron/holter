defmodule Holter.Integrations.Models.Integration do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @providers ~w(
    google_ads meta_ads slack pagerduty opsgenie
    linear jira github statuspage instatus
    google_calendar outlook
  )a

  @statuses ~w(active reauth_required rate_limited disabled provider_down)a

  @settings_max_bytes 4096

  schema "integrations" do
    field :name, :string
    field :provider, Ecto.Enum, values: @providers
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :credentials_encrypted, Holter.Integrations.EncryptedMap
    field :settings, :map, default: %{}
    field :subscribed_events, {:array, :string}, default: []
    field :last_sync_at, :utc_datetime
    field :last_error_at, :utc_datetime
    field :last_error_reason, :string

    belongs_to :workspace, Holter.Monitoring.Models.Workspace

    timestamps(type: :utc_datetime)
  end

  def providers, do: @providers
  def statuses, do: @statuses

  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [
      :workspace_id,
      :provider,
      :name,
      :status,
      :credentials_encrypted,
      :settings,
      :subscribed_events,
      :last_sync_at,
      :last_error_at,
      :last_error_reason
    ])
    |> validate_required([:workspace_id, :provider, :name])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_settings_size()
    |> foreign_key_constraint(:workspace_id)
    |> unique_constraint([:workspace_id, :provider, :name],
      name: :integrations_workspace_id_provider_name_index,
      message: "an integration with this name already exists for this provider"
    )
  end

  def status_changeset(integration, attrs) do
    integration
    |> cast(attrs, [:status, :last_sync_at, :last_error_at, :last_error_reason])
    |> validate_required([:status])
  end

  def credentials_changeset(integration, attrs) do
    integration
    |> cast(attrs, [:credentials_encrypted, :last_sync_at])
  end

  defp validate_settings_size(changeset) do
    validate_change(changeset, :settings, fn :settings, value ->
      case Jason.encode(value) do
        {:ok, json} when byte_size(json) > @settings_max_bytes ->
          [settings: "must be at most #{@settings_max_bytes} bytes when encoded"]

        {:ok, _json} ->
          []

        {:error, _} ->
          [settings: "must be a JSON-serializable map"]
      end
    end)
  end
end

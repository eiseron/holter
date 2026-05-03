defmodule Holter.Delivery.WebhookChannel do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Holter.Network.Guard

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @settings_max_bytes 4096

  schema "webhook_channels" do
    field :name, :string
    field :url, :string
    field :settings, :map, default: %{}
    field :signing_token, :string
    field :last_test_dispatched_at, :utc_datetime

    belongs_to :workspace, Holter.Monitoring.Workspace

    timestamps(type: :utc_datetime)
  end

  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, [:workspace_id, :name, :url, :settings])
    |> validate_required([:workspace_id, :name, :url])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:url, min: 1, max: 2048)
    |> validate_url_format()
    |> validate_settings_size()
    |> ensure_signing_token()
    |> foreign_key_constraint(:workspace_id)
  end

  def generate_signing_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  def settings_max_bytes, do: @settings_max_bytes

  defp ensure_signing_token(changeset) do
    case get_field(changeset, :signing_token) do
      nil -> put_change(changeset, :signing_token, generate_signing_token())
      _ -> changeset
    end
  end

  defp validate_url_format(changeset) do
    validate_change(changeset, :url, fn :url, url ->
      case Guard.restricted_url?(url) do
        :ok -> []
        {:error, reason} -> [url: error_message(reason)]
      end
    end)
  end

  defp error_message(:control_chars), do: "must not contain whitespace or control characters"
  defp error_message(:credentials), do: "must not include credentials"
  defp error_message(_), do: "must be a valid http or https URL"

  defp validate_settings_size(changeset) do
    validate_change(changeset, :settings, fn :settings, value ->
      case Jason.encode(value) do
        {:ok, json} when byte_size(json) > @settings_max_bytes ->
          [settings: "must be at most #{@settings_max_bytes} bytes when encoded"]

        _ ->
          []
      end
    end)
  end
end

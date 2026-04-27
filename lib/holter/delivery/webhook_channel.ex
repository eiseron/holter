defmodule Holter.Delivery.WebhookChannel do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "webhook_channels" do
    field :url, :string
    field :settings, :map, default: %{}
    field :signing_token, :string

    belongs_to :notification_channel, Holter.Delivery.NotificationChannel

    timestamps(type: :utc_datetime)
  end

  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, [:notification_channel_id, :url, :settings])
    |> validate_required([:url])
    |> validate_length(:url, min: 1, max: 2048)
    |> validate_url_format()
    |> ensure_signing_token()
    |> unique_constraint(:notification_channel_id)
    |> foreign_key_constraint(:notification_channel_id)
  end

  def generate_signing_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp ensure_signing_token(changeset) do
    case get_field(changeset, :signing_token) do
      nil -> put_change(changeset, :signing_token, generate_signing_token())
      _ -> changeset
    end
  end

  defp validate_url_format(changeset) do
    validate_change(changeset, :url, fn :url, url ->
      if valid_http_url?(url), do: [], else: [url: "must be a valid http or https URL"]
    end)
  end

  defp valid_http_url?(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
        not private_host?(host)

      _ ->
        false
    end
  end

  defp private_host?(host) do
    normalized = String.downcase(host)
    normalized in ~w(localhost 0.0.0.0) or private_ip?(normalized)
  end

  defp private_ip?(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, ip} -> private_ip_tuple?(ip)
      _ -> false
    end
  end

  defp private_ip_tuple?({127, _, _, _}), do: true
  defp private_ip_tuple?({10, _, _, _}), do: true
  defp private_ip_tuple?({172, b, _, _}) when b in 16..31, do: true
  defp private_ip_tuple?({192, 168, _, _}), do: true
  defp private_ip_tuple?({169, 254, _, _}), do: true
  defp private_ip_tuple?({0, _, _, _}), do: true
  defp private_ip_tuple?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp private_ip_tuple?({0, 0, 0, 0, 0, 0, 0, 0}), do: true
  defp private_ip_tuple?(_), do: false
end

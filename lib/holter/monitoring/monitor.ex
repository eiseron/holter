defmodule Holter.Monitoring.Monitor do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "monitors" do
    field :user_id, :binary_id
    field :logical_state, Ecto.Enum, values: [:active, :paused, :archived], default: :active
    field :health_status, Ecto.Enum, values: [:up, :down, :degraded, :compromised, :unknown], default: :unknown
    
    field :url, :string
    field :method, Ecto.Enum, values: [:GET, :POST, :HEAD, :PUT, :PATCH, :DELETE, :OPTIONS], default: :GET
    
    field :interval_seconds, :integer, default: 60
    field :timeout_seconds, :integer, default: 30
    
    field :headers, :map, default: %{}
    field :raw_headers, :string, virtual: true
    field :body, :string
    
    field :ssl_ignore, :boolean, default: false
    field :raw_keyword_positive, :string, virtual: true
    field :raw_keyword_negative, :string, virtual: true
    field :keyword_positive, {:array, :string}, default: []
    field :keyword_negative, {:array, :string}, default: []

    field :last_checked_at, :utc_datetime
    field :last_success_at, :utc_datetime
    field :last_manual_check_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(monitor, attrs) do
    monitor
    |> cast(attrs, [
      :user_id, :logical_state, :health_status, :url, :method,
      :interval_seconds, :timeout_seconds, :headers, :raw_headers, :body,
      :ssl_ignore, :raw_keyword_positive, :raw_keyword_negative,
      :last_checked_at, :last_success_at, :last_manual_check_at
    ])
    |> validate_required([:url, :method, :interval_seconds, :timeout_seconds])
    |> validate_url()
    |> validate_raw_headers()
    |> parse_keywords(:raw_keyword_positive, :keyword_positive)
    |> parse_keywords(:raw_keyword_negative, :keyword_negative)
  end

  defp parse_keywords(changeset, raw_field, target_field) do
    case get_change(changeset, raw_field) do
      nil -> changeset
      "" -> put_change(changeset, target_field, [])
      str ->
        list = str |> String.split(~r/[,;]+/, trim: true) |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
        put_change(changeset, target_field, list)
    end
  end

  defp validate_raw_headers(changeset) do
    case get_change(changeset, :raw_headers) do
      nil -> changeset
      "" -> put_change(changeset, :headers, %{})
      json_str ->
        case Jason.decode(json_str) do
          {:ok, map} when is_map(map) -> put_change(changeset, :headers, map)
          _ -> add_error(changeset, :raw_headers, "must be a valid JSON object")
        end
    end
  end

  defp validate_url(changeset) do
    validate_change(changeset, :url, fn :url, url ->
      case parse_url(url) do
        {:ok, _} -> []
        {:error, msg} -> [url: msg]
      end
    end)
  end

  defp parse_url(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
        {:ok, true}
      _ ->
        {:error, "must be a valid http or https URL"}
    end
  end
end

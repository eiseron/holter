defmodule Holter.Monitoring.Monitor do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "monitors" do
    field :user_id, :binary_id
    field :logical_state, Ecto.Enum, values: [:active, :paused, :archived], default: :active

    field :health_status, Ecto.Enum,
      values: [:up, :down, :degraded, :compromised, :unknown],
      default: :unknown

    field :url, :string

    field :method, Ecto.Enum,
      values: [
        get: "GET",
        post: "POST",
        head: "HEAD",
        put: "PUT",
        patch: "PATCH",
        delete: "DELETE",
        options: "OPTIONS"
      ],
      default: :get

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
    field :ssl_expires_at, :utc_datetime

    has_many :daily_metrics, Holter.Monitoring.DailyMetric

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(monitor, attrs) do
    monitor
    |> cast(attrs, [
      :user_id,
      :logical_state,
      :health_status,
      :url,
      :method,
      :interval_seconds,
      :timeout_seconds,
      :headers,
      :raw_headers,
      :body,
      :ssl_ignore,
      :raw_keyword_positive,
      :raw_keyword_negative,
      :last_checked_at,
      :last_success_at,
      :last_manual_check_at,
      :ssl_expires_at
    ])
    |> validate_required([:url, :method, :interval_seconds, :timeout_seconds])
    |> validate_length(:url, max: 2048)
    |> validate_length(:raw_headers, max: 4096)
    |> validate_length(:body, max: 8192)
    |> validate_url()
    |> validate_ssrf()
    |> validate_raw_headers()
    |> parse_keywords(:raw_keyword_positive, :keyword_positive)
    |> parse_keywords(:raw_keyword_negative, :keyword_negative)
  end

  defp parse_keywords(changeset, raw_field, target_field) do
    case fetch_change(changeset, raw_field) do
      {:ok, nil} ->
        put_change(changeset, target_field, [])

      {:ok, str} when is_binary(str) ->
        list =
          str
          |> String.split(~r/[,;]+/, trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        put_change(changeset, target_field, list)

      :error ->
        changeset
    end
  end

  defp validate_raw_headers(changeset) do
    case fetch_change(changeset, :raw_headers) do
      {:ok, nil} ->
        put_change(changeset, :headers, %{})

      {:ok, json_str} when is_binary(json_str) ->
        case Jason.decode(json_str) do
          {:ok, map} when is_map(map) -> put_change(changeset, :headers, map)
          _ -> add_error(changeset, :raw_headers, "must be a valid JSON object")
        end

      :error ->
        changeset
    end
  end

  defp validate_url(changeset) do
    validate_change(changeset, :url, fn :url, url ->
      case parse_url(url) do
        {:ok, true} -> []
        {:error, msg} -> [url: msg]
      end
    end)
  end

  defp validate_ssrf(changeset) do
    validate_change(changeset, :url, fn :url, url ->
      host = URI.parse(url).host

      if restricted_host?(host) do
        [url: "is a restricted internal address"]
      else
        []
      end
    end)
  end

  defp restricted_host?(nil), do: true

  defp restricted_host?(host) do
    host = String.downcase(host)
    trusted = get_trusted_hosts()

    (localhost?(host) or private_ip?(host)) and host not in trusted
  end

  defp get_trusted_hosts do
    :holter
    |> Application.get_env(:monitoring, [])
    |> Keyword.get(:trusted_hosts, [])
  end

  defp localhost?(host) do
    host in ["localhost", "127.0.0.1", "::1", "0.0.0.0", "0"]
  end

  defp private_ip?(host) do
    case :inet.parse_address(to_charlist(host)) do
      {:ok, {10, _, _, _}} -> true
      {:ok, {172, second, _, _}} when second >= 16 and second <= 31 -> true
      {:ok, {192, 168, _, _}} -> true
      {:ok, {169, 254, _, _}} -> true
      {:ok, {127, _, _, _}} -> true
      _ -> false
    end
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

defmodule Holter.Monitoring.Monitor do
  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: HolterWeb.Gettext

  @manual_check_cooldown 60
  def manual_check_cooldown, do: @manual_check_cooldown

  @http_methods [:get, :post, :head, :put, :patch, :delete, :options]
  def http_methods, do: @http_methods

  @interval_min_seconds 60
  @interval_max_seconds 7200
  @interval_default_seconds 5400
  def interval_min_seconds, do: @interval_min_seconds
  def interval_max_seconds, do: @interval_max_seconds
  def interval_default_seconds, do: @interval_default_seconds

  @bodyless_methods [:get, :head]
  @body_methods [:post, :put, :patch, :delete, :options]
  @max_keywords 20

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

    field :interval_seconds, :integer, default: 5400
    field :timeout_seconds, :integer, default: 30

    field :headers, :map, default: %{}
    field :raw_headers, :string, virtual: true
    field :body, :string

    field :ssl_ignore, :boolean, default: false
    field :follow_redirects, :boolean, default: true
    field :max_redirects, :integer, default: 5

    field :raw_keyword_positive, :string, virtual: true
    field :raw_keyword_negative, :string, virtual: true
    field :keyword_positive, {:array, :string}, default: []
    field :keyword_negative, {:array, :string}, default: []

    field :last_checked_at, :utc_datetime
    field :last_success_at, :utc_datetime
    field :last_manual_check_at, :utc_datetime
    field :ssl_expires_at, :utc_datetime

    belongs_to :workspace, Holter.Monitoring.Workspace
    has_many :daily_metrics, Holter.Monitoring.DailyMetric
    has_many :logs, Holter.Monitoring.MonitorLog

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(monitor, attrs, workspace \\ nil) do
    monitor
    |> cast_fields(attrs)
    |> validate_core_fields()
    |> validate_url_field()
    |> validate_http_semantics(workspace)
    |> process_virtual_fields()
  end

  def capture_snapshot(%__MODULE__{} = monitor) do
    %{
      url: monitor.url,
      method: monitor.method,
      interval_seconds: monitor.interval_seconds,
      timeout_seconds: monitor.timeout_seconds,
      headers: monitor.headers,
      body: monitor.body,
      keyword_positive: monitor.keyword_positive,
      keyword_negative: monitor.keyword_negative,
      ssl_ignore: monitor.ssl_ignore,
      follow_redirects: monitor.follow_redirects,
      max_redirects: monitor.max_redirects
    }
  end

  @allowed_fields [
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
    :follow_redirects,
    :max_redirects,
    :raw_keyword_positive,
    :raw_keyword_negative,
    :last_checked_at,
    :last_success_at,
    :last_manual_check_at,
    :ssl_expires_at
  ]

  defp cast_fields(monitor, attrs) do
    allowed = if is_nil(monitor.id), do: [:workspace_id | @allowed_fields], else: @allowed_fields
    cast(monitor, attrs, allowed)
  end

  defp validate_core_fields(changeset) do
    changeset
    |> validate_required([:url, :method, :interval_seconds, :timeout_seconds, :workspace_id])
    |> validate_number(:interval_seconds,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 86_400
    )
    |> validate_number(:timeout_seconds, greater_than_or_equal_to: 1, less_than_or_equal_to: 300)
    |> validate_number(:max_redirects, greater_than_or_equal_to: 1, less_than_or_equal_to: 20)
    |> validate_length(:url, max: 2048)
    |> validate_length(:raw_headers, max: 4096)
    |> validate_length(:body, max: 8192)
  end

  defp validate_url_field(changeset) do
    changeset
    |> validate_url()
    |> validate_ssrf()
  end

  defp validate_http_semantics(changeset, workspace) do
    changeset
    |> validate_workspace_interval(workspace)
    |> validate_timeout_vs_interval()
    |> validate_body_allowed_for_method()
    |> validate_body_json()
    |> validate_ssl_ignore_requires_https()
    |> validate_quota_on_activation(workspace)
  end

  defp validate_quota_on_activation(changeset, nil), do: changeset

  defp validate_quota_on_activation(changeset, workspace) do
    state_changed? = field_changed?(changeset, :logical_state)
    new_state = get_field(changeset, :logical_state)

    if state_changed? and changeset.data.logical_state == :archived and new_state != :archived do
      if Holter.Monitoring.at_quota?(workspace, changeset.data.id) do
        add_error(changeset, :logical_state, gettext("Monitor limit reached for this workspace"),
          code: :quota_reached
        )
      else
        changeset
      end
    else
      changeset
    end
  end

  defp process_virtual_fields(changeset) do
    changeset
    |> validate_raw_headers()
    |> parse_keywords(:raw_keyword_positive, :keyword_positive)
    |> parse_keywords(:raw_keyword_negative, :keyword_negative)
    |> validate_keyword_count()
  end

  defp validate_workspace_interval(changeset, nil), do: changeset

  defp validate_workspace_interval(changeset, %{min_interval_seconds: min}) do
    validate_number(changeset, :interval_seconds,
      greater_than_or_equal_to: min,
      message: "must be at least #{min}s for this workspace plan"
    )
  end

  defp validate_timeout_vs_interval(changeset) do
    if field_changed?(changeset, :timeout_seconds) or field_changed?(changeset, :interval_seconds) do
      interval = get_field(changeset, :interval_seconds)
      timeout = get_field(changeset, :timeout_seconds)

      if interval && timeout && timeout >= interval do
        add_error(
          changeset,
          :timeout_seconds,
          gettext("must be less than the check interval (%{interval}s)"),
          interval: Integer.to_string(interval)
        )
      else
        changeset
      end
    else
      changeset
    end
  end

  defp validate_body_allowed_for_method(changeset) do
    if field_changed?(changeset, :body) or field_changed?(changeset, :method) do
      method = get_field(changeset, :method)
      body = get_field(changeset, :body)

      if method in @bodyless_methods && body && body != "" do
        add_error(changeset, :body, gettext("must be empty for %{method} requests"),
          method: method |> to_string() |> String.upcase()
        )
      else
        changeset
      end
    else
      changeset
    end
  end

  defp validate_body_json(changeset) do
    if field_changed?(changeset, :body) do
      check_body_json(changeset, get_field(changeset, :method), get_field(changeset, :body))
    else
      changeset
    end
  end

  defp check_body_json(changeset, method, body)
       when method in @body_methods and is_binary(body) and body != "" do
    case Jason.decode(body) do
      {:ok, _} -> changeset
      {:error, _} -> add_error(changeset, :body, gettext("must be a valid JSON string"))
    end
  end

  defp check_body_json(changeset, _method, _body), do: changeset

  defp validate_ssl_ignore_requires_https(changeset) do
    if field_changed?(changeset, :ssl_ignore) or field_changed?(changeset, :url) do
      ssl_ignore = get_field(changeset, :ssl_ignore)
      url = get_field(changeset, :url)

      if ssl_ignore && url && String.starts_with?(url, "http://") do
        add_error(changeset, :ssl_ignore, gettext("is only applicable to HTTPS URLs"))
      else
        changeset
      end
    else
      changeset
    end
  end

  defp field_changed?(changeset, field), do: Map.has_key?(changeset.changes, field)

  defp validate_keyword_count(changeset) do
    changeset
    |> check_keyword_list(:keyword_positive)
    |> check_keyword_list(:keyword_negative)
  end

  defp check_keyword_list(changeset, field) do
    if field_changed?(changeset, field) do
      keywords = get_field(changeset, field) || []

      if length(keywords) > @max_keywords do
        add_error(
          changeset,
          field,
          gettext("cannot have more than %{max_keywords} keywords (got %{count})"),
          max_keywords: @max_keywords,
          count: length(keywords)
        )
      else
        changeset
      end
    else
      changeset
    end
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
          {:ok, map} when is_map(map) ->
            put_change(changeset, :headers, sanitize_map(map))

          _ ->
            add_error(changeset, :raw_headers, gettext("must be a valid JSON object"))
        end

      :error ->
        changeset
    end
  end

  defp sanitize_map(map) do
    Map.new(map, fn {k, v} -> {sanitize_string(k), sanitize_string(v)} end)
  end

  defp sanitize_string(value) when is_binary(value) do
    value
    |> String.replace("\0", "")
    |> String.replace(~r/[\r\n]+/, " ")
    |> String.trim()
  end

  defp sanitize_string(value), do: value

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
        [url: gettext("is a restricted internal address")]
      else
        []
      end
    end)
  end

  defp restricted_host?(nil), do: true

  defp restricted_host?(host) do
    host = host |> String.downcase() |> String.replace("[", "") |> String.replace("]", "")
    trusted = get_trusted_hosts()

    (localhost?(host) or private_ip?(host) or single_token_host?(host)) and host not in trusted
  end

  defp single_token_host?(host) do
    not String.contains?(host, ".")
  end

  defp get_trusted_hosts do
    :holter
    |> Application.get_env(:monitoring, [])
    |> Keyword.get(:trusted_hosts, [])
  end

  defp localhost?(host) do
    host in ["localhost", "127.0.0.1", "::1", "0.0.0.0", "0"] or
      String.starts_with?(host, "127.") or
      String.starts_with?(host, "::ffff:127.")
  end

  defp private_ip?(host) do
    case :inet.parse_address(to_charlist(host)) do
      {:ok, {127, _, _, _}} -> true
      {:ok, {10, _, _, _}} -> true
      {:ok, {172, second, _, _}} when second >= 16 and second <= 31 -> true
      {:ok, {192, 168, _, _}} -> true
      {:ok, {169, 254, _, _}} -> true
      _ -> encoded_ip?(host)
    end
  end

  defp encoded_ip?(host) do
    is_numeric = Regex.match?(~r/^(0x[0-9a-f]+|[0-9]+)$/i, host)
    is_short_ip = Regex.match?(~r/^[0-9]+\.[0-9]+(\.[0-9]+)?$/, host)

    is_numeric or is_short_ip
  end

  defp parse_url(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
        {:ok, true}

      _ ->
        {:error, gettext("must be a valid http or https URL")}
    end
  end
end

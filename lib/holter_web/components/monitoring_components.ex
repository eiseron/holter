defmodule HolterWeb.MonitoringComponents do
  @moduledoc false
  use HolterWeb, :html

  attr :navigate, :string, required: true

  def back_link(assigns) do
    ~H"""
    <.link navigate={@navigate} class="h-btn-back">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="16"
        height="16"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M19 12H5M12 5l-7 7 7 7" />
      </svg>
    </.link>
    """
  end

  attr :new_monitor_url, :string, required: true

  def dashboard_header(assigns) do
    ~H"""
    <header class="dashboard-header-premium">
      <div>
        <h1>{gettext("Dashboard")}</h1>
        <p class="h-mt-1 h-opacity-60">{gettext("Real-time Overview")}</p>
      </div>
      <div class="h-flex h-gap-3">
        <.link navigate={@new_monitor_url} class="h-btn h-btn-primary">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M12 5v14M5 12h14" />
          </svg>
          {gettext("New Monitor")}
        </.link>
      </div>
    </header>
    """
  end

  def empty_state_dark(assigns) do
    ~H"""
    <div class="h-empty-state-dark">
      <p>{gettext("No monitors heartbeat found in this workspace.")}</p>
    </div>
    """
  end

  attr :monitor, :map, required: true
  attr :detail_url, :string, required: true

  def monitor_card(assigns) do
    ~H"""
    <div class="monitor-card-premium">
      <header>
        <h3 class="h-font-bold h-text-lg h-truncate" data-role="monitor-url">
          {@monitor.url}
        </h3>
        <div class="h-flex h-justify-between h-items-center h-mt-2">
          <p class="h-text-xs h-opacity-50">
            {@monitor.method |> to_string() |> String.upcase()} • {@monitor.interval_seconds}s
          </p>
          <.health_badge status={@monitor.health_status} />
        </div>
      </header>

      <.sparkline monitor_id={@monitor.id} logs={@monitor.logs} />

      <footer class="h-flex h-justify-between h-items-center h-mt-4">
        <span class="h-text-xs h-font-mono h-opacity-40">
          {@monitor.id |> String.slice(0..7)}
        </span>
        <.link
          navigate={@detail_url}
          class="h-text-sky-400 h-text-sm h-font-semibold h-hover-underline"
        >
          {gettext("Details")} →
        </.link>
      </footer>
    </div>
    """
  end

  attr :status, :atom, required: true

  def health_badge(assigns) do
    ~H"""
    <div class={["h-health-pulse-badge", "h-status-#{@status}"]}>
      <span class="pulse-dot"></span>
      <span class="status-label">{@status |> to_string() |> String.upcase()}</span>
    </div>
    """
  end

  attr :status, :atom, required: true
  attr :status_code, :integer, default: nil

  def status_pill(assigns) do
    ~H"""
    <span
      class={"h-status-pill h-status-#{@status}"}
      data-role="log-status"
      data-status={@status}
    >
      {@status |> to_string() |> String.upcase()}
      <span :if={@status_code}>({@status_code})</span>
    </span>
    """
  end

  attr :monitor_id, :string, required: true
  attr :logs, :list, default: []

  def sparkline(assigns) do
    data_points = Enum.reverse(assigns.logs)

    assigns =
      assigns
      |> assign(:data_points, data_points)
      |> assign(:path, calculate_path(data_points))
      |> assign(:area_path, calculate_area_path(data_points))

    ~H"""
    <div class="sparkline-container" id={"sparkline-#{@monitor_id}"}>
      <%= if @data_points == [] do %>
        <svg class="sparkline-svg" viewBox="0 0 300 80" preserveAspectRatio="none">
          <line
            x1="0"
            y1="75"
            x2="300"
            y2="75"
            stroke="rgba(255,255,255,0.08)"
            stroke-width="1"
            stroke-dasharray="4 4"
          />
        </svg>
        <p class="sparkline-no-data">{gettext("No data yet")}</p>
      <% else %>
        <svg class="sparkline-svg" viewBox="0 0 300 80" preserveAspectRatio="none">
          <defs>
            <linearGradient id={"sparkline-gradient-#{@monitor_id}"} x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" stop-color="var(--color-monitor-pulse-primary)" stop-opacity="0.3" />
              <stop offset="100%" stop-color="var(--color-monitor-pulse-primary)" stop-opacity="0" />
            </linearGradient>
          </defs>

          <path
            d={@area_path}
            fill={"url(#sparkline-gradient-#{@monitor_id})"}
            class="sparkline-area"
          />
          <path d={@path} class="sparkline-line" />

          <%= for {point, index} <- Enum.with_index(@data_points) do %>
            <%= if point.status != :up do %>
              <circle
                cx={index * 10}
                cy={normalize_y(point.latency_ms)}
                r="3"
                fill={log_status_color(point.status)}
                class="sparkline-error-marker"
              />
            <% end %>
          <% end %>
        </svg>
      <% end %>
    </div>
    """
  end

  attr :prev_page_url, :string, default: nil
  attr :next_page_url, :string, default: nil
  attr :page_links, :list, required: true
  attr :page_number, :integer, required: true
  attr :total_pages, :integer, required: true

  def pagination_nav(assigns) do
    ~H"""
    <div class="h-logs-pagination">
      <div class="h-text-muted h-text-sm" data-role="page-info">
        {gettext("Page %{page_number} of %{total_pages}",
          page_number: @page_number,
          total_pages: @total_pages
        )}
      </div>
      <nav class="h-pagination-nav">
        <.link :if={@prev_page_url} patch={@prev_page_url} class="h-btn h-btn-soft h-pagination-btn">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M15 18l-6-6 6-6" />
          </svg>
        </.link>

        <%= for {p, url} <- @page_links do %>
          <.link
            patch={url}
            class={"h-btn h-pagination-btn #{if p == @page_number, do: "h-btn-primary", else: "h-btn-soft"}"}
          >
            {p}
          </.link>
        <% end %>

        <.link :if={@next_page_url} patch={@next_page_url} class="h-btn h-btn-soft h-pagination-btn">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M9 18l6-6-6-6" />
          </svg>
        </.link>
      </nav>
    </div>
    """
  end

  attr :metrics, :list, required: true
  attr :logs_url, :string, required: true

  def daily_metrics_section(assigns) do
    ~H"""
    <section class="h-section">
      <.header>
        {gettext("Daily Uptime History")}
        <:actions>
          <.link navigate={@logs_url} class="h-btn h-btn-soft">
            {gettext("View Technical Logs")}
          </.link>
        </:actions>
      </.header>

      <div :if={Enum.empty?(@metrics)} class="h-empty-state">
        <p>{gettext("No history recorded yet. Metrics are aggregated daily at midnight.")}</p>
      </div>

      <.table :if={not Enum.empty?(@metrics)} id="metrics-table" rows={@metrics}>
        <:col :let={metric} label={gettext("Date")}>
          {Calendar.strftime(metric.date, "%Y-%m-%d")}
        </:col>
        <:col :let={metric} label={gettext("Uptime (%)")}>
          <span class={
            if Holter.Monitoring.DailyMetric.uptime_healthy?(metric),
              do: "h-text-success",
              else: "h-text-error"
          }>
            {metric.uptime_percent}%
          </span>
        </:col>
        <:col :let={metric} label={gettext("Avg Latency")}>{metric.avg_latency_ms}ms</:col>
        <:col :let={metric} label={gettext("Downtime")}>
          {metric.total_downtime_minutes} {gettext("min")}
        </:col>
      </.table>
    </section>
    """
  end

  attr :form, :any, required: true

  def monitor_form_technical(assigns) do
    ~H"""
    <div class="h-fieldset-card">
      <h3 class="h-fieldset-legend">{gettext("Technical Configuration")}</h3>
      <div class="h-form-grid h-grid-cols-2">
        <div>
          <.input
            field={@form[:url]}
            type="url"
            label={gettext("URL")}
            placeholder="https://example.com"
            required
          />
          <p class="h-help-text">
            {gettext("The precise target endpoint or website you want to monitor.")}
          </p>
        </div>

        <div>
          <.input
            field={@form[:method]}
            type="select"
            label={gettext("Method")}
            options={
              Holter.Monitoring.Monitor.http_methods()
              |> Enum.map(fn m -> {String.upcase(to_string(m)), to_string(m)} end)
            }
            required
          />
          <p class="h-help-text">{gettext("The HTTP method to use for the request.")}</p>
        </div>

        <div class="h-col-span-2">
          <.input
            field={@form[:raw_headers]}
            type="textarea"
            label={gettext("Custom Headers (JSON)")}
            placeholder={~s|{"Authorization": "Bearer token"}|}
          />
          <p class="h-help-text">
            {gettext("Additional HTTP headers formatted as a valid JSON object.")}
          </p>
        </div>

        <div class="h-col-span-2">
          <.input
            field={@form[:body]}
            type="textarea"
            label={gettext("Request Body")}
            placeholder={~s|{"my_key": "my_value"}|}
          />
          <p class="h-help-text">
            {gettext("Payload to send with POST/PUT requests (JSON, text, XML).")}
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr :form, :any, required: true

  def monitor_form_security(assigns) do
    ~H"""
    <div class="h-fieldset-card">
      <h3 class="h-fieldset-legend">{gettext("Security & Validation Rules")}</h3>
      <div class="h-form-grid h-grid-cols-2">
        <div>
          <.input
            field={@form[:raw_keyword_positive]}
            type="text"
            label={gettext("Must Contain (Keywords)")}
            placeholder={gettext("Brand Name, Title, Success")}
          />
          <p class="h-help-text">
            {gettext(
              "The endpoint response MUST contain these words, otherwise it is considered DOWN. Separate multiple words by comma."
            )}
          </p>
        </div>

        <div>
          <.input
            field={@form[:raw_keyword_negative]}
            type="text"
            label={gettext("Must Not Contain (Defacement)")}
            placeholder={gettext("hacked, database error")}
          />
          <p class="h-help-text">
            {gettext(
              "The endpoint response MUST NOT contain these words. Useful to detect hacks/defacements. Separate by comma."
            )}
          </p>
        </div>

        <div class="h-col-span-2">
          <.input
            field={@form[:ssl_ignore]}
            type="checkbox"
            label={gettext("Ignore SSL Validation Errors")}
          />
          <p class="h-help-text">
            {gettext("Check this if your endpoint uses self-signed certificates or expired SSL.")}
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :show_logical_state, :boolean, default: false

  def monitor_form_interval(assigns) do
    ~H"""
    <div class="h-fieldset-card">
      <h3 class="h-fieldset-legend">{gettext("Interval Defaults")}</h3>
      <div class={"h-form-grid #{if @show_logical_state, do: "h-grid-cols-3", else: "h-grid-cols-2"}"}>
        <div>
          <.input
            field={@form[:interval_seconds]}
            type="select"
            label={gettext("Check Interval")}
            options={
              Holter.Monitoring.Monitor.check_interval_seconds()
              |> Enum.map(fn s -> {interval_label(s), s} end)
            }
            required
          />
          <p class="h-help-text">
            {gettext("How frequently our worker nodes will ping your URL.")}
          </p>
        </div>

        <div>
          <.input
            field={@form[:timeout_seconds]}
            type="number"
            label={gettext("Timeout Threshold (Seconds)")}
            required
          />
          <p class="h-help-text">
            {gettext("Maximum time to wait for a response before declaring the endpoint DOWN.")}
          </p>
        </div>

        <div :if={@show_logical_state}>
          <.input
            field={@form[:logical_state]}
            type="select"
            label={gettext("Monitor State")}
            options={[{gettext("Active"), "active"}, {gettext("Paused"), "paused"}]}
            required
          />
        </div>
      </div>
    </div>
    """
  end

  defp interval_label(60), do: gettext("1 Minute")
  defp interval_label(300), do: gettext("5 Minutes")
  defp interval_label(600), do: gettext("10 Minutes")
  defp interval_label(n), do: "#{n}s"

  defp calculate_path([]), do: ""

  defp calculate_path(logs) do
    "M " <>
      Enum.map_join(Enum.with_index(logs), " ", fn {log, i} ->
        "#{i * 10},#{normalize_y(log.latency_ms)}"
      end)
  end

  defp calculate_area_path([]), do: ""

  defp calculate_area_path(logs) do
    path = calculate_path(logs)
    last_x = (length(logs) - 1) * 10
    path <> " L #{last_x},80 L 0,80 Z"
  end

  defp normalize_y(nil), do: 75

  defp normalize_y(latency) do
    clamped = min(latency, 1000)
    70 - clamped / 1000 * 60
  end

  defp log_status_color(:down), do: "var(--color-status-down)"
  defp log_status_color(:compromised), do: "var(--color-status-compromised)"
  defp log_status_color(:degraded), do: "var(--color-status-degraded)"
  defp log_status_color(:unknown), do: "var(--color-status-unknown)"
  defp log_status_color(_), do: "var(--color-status-down)"
end

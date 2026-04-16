defmodule HolterWeb.Components.Monitoring.MonitorSnapshot do
  @moduledoc false
  use HolterWeb, :component

  @doc """
  Renders monitor configuration at time of check.
  """
  attr :snapshot, :map, required: true

  def monitor_snapshot(assigns) do
    ~H"""
    <div class="h-fieldset-card">
      <h3 class="h-fieldset-legend">{gettext("Monitor Configuration")}</h3>
      <div class="h-form-grid h-grid-cols-2">
        <div>
          <label class="h-snapshot-label">{gettext("URL")}</label>
          <code class="h-snapshot-value">{@snapshot["url"]}</code>
        </div>
        <div>
          <label class="h-snapshot-label">{gettext("Method")}</label>
          <span class="h-snapshot-value">{String.upcase(to_string(@snapshot["method"]))}</span>
        </div>
        <div>
          <label class="h-snapshot-label">{gettext("Check Interval")}</label>
          <span class="h-snapshot-value">{@snapshot["interval_seconds"]}s</span>
        </div>
        <div>
          <label class="h-snapshot-label">{gettext("Timeout Threshold (Seconds)")}</label>
          <span class="h-snapshot-value">{@snapshot["timeout_seconds"]}s</span>
        </div>
        <%= if @snapshot["follow_redirects"] do %>
          <div>
            <label class="h-snapshot-label">{gettext("Max Redirects")}</label>
            <span class="h-snapshot-value">{@snapshot["max_redirects"]}</span>
          </div>
        <% end %>
        <%= if @snapshot["ssl_ignore"] do %>
          <div>
            <label class="h-snapshot-label">{gettext("Ignore SSL Validation Errors")}</label>
            <span class="h-snapshot-value h-snapshot-badge">{gettext("Yes")}</span>
          </div>
        <% end %>
      </div>

      <%= if @snapshot["headers"] && is_map(@snapshot["headers"]) && map_size(@snapshot["headers"]) > 0 do %>
        <div class="h-col-span-2 h-snapshot-rules-section">
          <label class="h-snapshot-label">{gettext("Custom Headers (JSON)")}</label>
          <code class="h-snapshot-code">{Jason.encode!(@snapshot["headers"], pretty: true)}</code>
        </div>
      <% end %>

      <%= if @snapshot["body"] && @snapshot["body"] != "" do %>
        <div class="h-col-span-2 h-snapshot-rules-section">
          <label class="h-snapshot-label">{gettext("Request Body")}</label>
          <code class="h-snapshot-code">{@snapshot["body"]}</code>
        </div>
      <% end %>

      <%= if @snapshot["keyword_positive"] && Enum.any?(@snapshot["keyword_positive"]) do %>
        <div class="h-col-span-2 h-snapshot-rules-section">
          <label class="h-snapshot-label">{gettext("Must Contain (Keywords)")}</label>
          <code class="h-snapshot-code">{Enum.join(@snapshot["keyword_positive"], ", ")}</code>
        </div>
      <% end %>

      <%= if @snapshot["keyword_negative"] && Enum.any?(@snapshot["keyword_negative"]) do %>
        <div class="h-col-span-2 h-snapshot-rules-section">
          <label class="h-snapshot-label">{gettext("Must Not Contain (Defacement)")}</label>
          <code class="h-snapshot-code">{Enum.join(@snapshot["keyword_negative"], ", ")}</code>
        </div>
      <% end %>
    </div>
    """
  end
end

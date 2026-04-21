defmodule HolterWeb.Components.Delivery.MonitorChannelSelect do
  @moduledoc false
  use HolterWeb, :component

  import HolterWeb.Components.EmptyState

  attr :monitors, :list, required: true
  attr :selected_ids, :list, default: []
  attr :input_name, :string, default: "monitor_ids[]"

  def monitor_channel_select(assigns) do
    ~H"""
    <div class="h-fieldset-card">
      <h3 class="h-fieldset-legend">{gettext("Linked Monitors")}</h3>
      <p class="h-help-text h-mb-4">
        {gettext("Select which monitors will trigger notifications through this channel.")}
      </p>
      <%= if Enum.empty?(@monitors) do %>
        <.empty_state>
          <p>{gettext("No monitors in this workspace yet.")}</p>
        </.empty_state>
      <% else %>
        <div class="h-monitor-select-grid">
          <%= for monitor <- @monitors do %>
            <label class={[
              "h-monitor-select-item",
              monitor.id in @selected_ids && "h-monitor-select-item--checked"
            ]}>
              <input
                type="checkbox"
                name={@input_name}
                value={monitor.id}
                checked={monitor.id in @selected_ids}
                class="h-monitor-select-check"
              />
              <span class="h-monitor-select-name">{monitor.url}</span>
            </label>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end

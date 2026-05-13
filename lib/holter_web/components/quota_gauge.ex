defmodule HolterWeb.Components.QuotaGauge do
  @moduledoc false
  use HolterWeb, :component

  @doc """
  Renders a segmented gauge showing `count/max` usage of a plan slot
  allocation. One cell per available slot, filled cells reflect current
  consumption, with a tabular fraction (e.g. `2/3`) to the right.

  Pair with a `<dl class="h-quota-gauge-list">` wrapper to stack
  multiple gauges with semantic markup.

  ## Examples

      <dl class="h-quota-gauge-list">
        <.quota_gauge label={gettext("Monitors")} count={@monitor_count} max={@max_monitors} />
        <.quota_gauge label={gettext("Channels")} count={@channel_count} max={@max_channels} />
      </dl>
  """
  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :max, :integer, required: true

  def quota_gauge(assigns) do
    ~H"""
    <div class="h-quota-gauge">
      <dt class="h-quota-gauge-label">{@label}</dt>
      <dd>
        <div class="h-quota-gauge-row">
          <ul class="h-quota-gauge-segments" aria-hidden="true">
            <li
              :for={i <- 1..@max}
              class={[
                "h-quota-gauge-segment",
                i <= @count && "h-quota-gauge-segment--filled"
              ]}
            >
            </li>
          </ul>
          <span class="h-quota-gauge-fraction">{@count}/{@max}</span>
        </div>
      </dd>
    </div>
    """
  end
end

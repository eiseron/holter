defmodule HolterWeb.CoreComponents.Flash do
  @moduledoc """
  Core Flash components with Sentinel Ethos (4px severity border).
  """
  use Phoenix.Component
  use Gettext, backend: HolterWeb.Gettext
  alias Phoenix.LiveView.JS
  import HolterWeb.CoreComponents.Helpers
  import HolterWeb.CoreComponents.Icon

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil

  attr :kind, :atom,
    values: [:info, :error, :success, :warning],
    doc: "used for styling and flash lookup"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={["h-flash", "h-flash-#{@kind}"]}
      {@rest}
    >
      <div class="flex flex-col gap-1 flex-1">
        <p :if={@title} class="font-semibold text-sm">{@title}</p>
        <p class="text-sm">{msg}</p>
      </div>
      <button
        type="button"
        class="h-flash-close"
        aria-label="close"
      >
        <.icon name="hero-x-mark" class="icon-sm" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite" class="h-flash-group">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:success} flash={@flash} />
      <.flash kind={:warning} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("Connection Error")}
        phx-disconnected={show("#client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect...")}
        <.icon name="hero-arrow-path" class="icon-sm animate-spin ml-1" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Server Error")}
        phx-disconnected={show("#server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Something went wrong. Attempting to reconnect...")}
        <.icon name="hero-arrow-path" class="icon-sm animate-spin ml-1" />
      </.flash>
    </div>
    """
  end
end

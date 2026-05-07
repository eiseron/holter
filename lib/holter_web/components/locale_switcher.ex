defmodule HolterWeb.Components.LocaleSwitcher do
  @moduledoc """
  Quick locale switcher rendered in the workspace sidebar footer.
  100% LiveView-native: a `<select>` with `phx-change` that flips
  `users.preferred_locale` directly via `Holter.Identity` and asks
  the parent LV to re-render in the new locale via a `:locale_updated`
  message. No HTTP POST, no controller, no fetch.
  """

  use HolterWeb, :live_component

  alias Holter.I18n.Locale
  alias Holter.Identity

  @impl true
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  @impl true
  def handle_event("change_locale", %{"locale" => locale}, socket) do
    if Locale.valid?(locale) do
      case Identity.update_user_preferences(socket.assigns.current_user, %{
             preferred_locale: locale
           }) do
        {:ok, user} ->
          Gettext.put_locale(HolterWeb.Gettext, locale)
          send(self(), {:locale_updated, locale})
          {:noreply, assign(socket, current_user: user, current_locale: locale)}

        {:error, _changeset} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="h-sidebar-locale-switcher">
      <form phx-change="change_locale" phx-target={@myself}>
        <label class="h-sidebar-locale-label" for={"#{@id}-select"}>
          {gettext("Language")}
        </label>
        <select id={"#{@id}-select"} name="locale" class="h-sidebar-locale-select">
          <option value="pt_BR" selected={@current_locale == "pt_BR"}>
            {gettext("Portuguese (Brazil)")}
          </option>
          <option value="en" selected={@current_locale == "en"}>
            {gettext("English")}
          </option>
        </select>
      </form>
    </div>
    """
  end
end

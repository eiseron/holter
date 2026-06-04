defmodule HolterWeb.Components.Integrations.ProviderLogo do
  @moduledoc false
  use HolterWeb, :component

  import HolterWeb.Components.Icon

  @available ~w(google_ads meta_ads)a

  attr :provider, :atom, required: true
  attr :class, :string, default: "h-provider-logo"
  attr :alt, :string, default: nil

  def provider_logo(assigns) do
    has_logo = assigns.provider in @available
    assigns = assign(assigns, :has_logo, has_logo)

    ~H"""
    <%= if @has_logo do %>
      <img
        src={~p"/images/integrations/#{Atom.to_string(@provider) <> ".svg"}"}
        alt={@alt || provider_display_name(@provider)}
        class={@class}
        data-role="provider-logo"
        data-provider={@provider}
      />
    <% else %>
      <span class={[@class, "h-provider-logo-placeholder"]} aria-hidden="true">
        <.icon name="bell" />
      </span>
    <% end %>
    """
  end

  defp provider_display_name(provider) do
    provider
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end

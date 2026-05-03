defmodule HolterWeb.Components.Delivery.EmailChannelFormFields do
  @moduledoc false
  use HolterWeb, :component

  import HolterWeb.Components.Input

  attr :form, :any, required: true
  attr :verification_status, :atom, default: nil, values: [nil, :verified, :pending]

  def email_channel_form_fields(assigns) do
    ~H"""
    <div class="h-fieldset-card">
      <h3 class="h-fieldset-legend">{gettext("Email details")}</h3>
      <div class="h-form-grid h-grid-cols-2">
        <div>
          <.input
            field={@form[:name]}
            label={gettext("Name")}
            placeholder={gettext("e.g. On-call rotation")}
            required
          />
          <p class="h-help-text">{gettext("A label to identify this channel in your workspace.")}</p>
        </div>

        <div class="h-col-span-2">
          <.input
            field={@form[:address]}
            type="email"
            label={gettext("Address")}
            placeholder="ops@example.com"
            required
          />
          <p class="h-help-text">
            {gettext("The primary email address that will receive alerts.")}
          </p>
          <%= if @verification_status do %>
            <span class={"h-recipient-badge h-recipient-badge--#{badge_modifier(@verification_status)} h-mt-2"}>
              {verification_label(@verification_status)}
            </span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp badge_modifier(:verified), do: "verified"
  defp badge_modifier(:pending), do: "pending"

  defp verification_label(:verified), do: gettext("Verified")
  defp verification_label(:pending), do: gettext("Pending verification")
end

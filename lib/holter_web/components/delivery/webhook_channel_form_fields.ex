defmodule HolterWeb.Components.Delivery.WebhookChannelFormFields do
  @moduledoc false
  use HolterWeb, :component

  import HolterWeb.Components.Input

  attr :form, :any, required: true

  def webhook_channel_form_fields(assigns) do
    ~H"""
    <div class="h-fieldset-card">
      <h3 class="h-fieldset-legend">{gettext("Webhook details")}</h3>
      <div class="h-form-grid h-grid-cols-2">
        <div>
          <.input
            field={@form[:name]}
            label={gettext("Name")}
            placeholder={gettext("e.g. Production Alerts")}
            required
          />
          <p class="h-help-text">{gettext("A label to identify this channel in your workspace.")}</p>
        </div>

        <div class="h-col-span-2">
          <.input
            field={@form[:url]}
            type="text"
            label={gettext("URL")}
            placeholder="https://example.com/webhook"
            required
          />
          <p class="h-help-text">
            {gettext("The URL that will receive HTTP POST requests with alert payloads.")}
          </p>
        </div>
      </div>
    </div>
    """
  end
end

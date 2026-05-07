defmodule HolterWeb.Components.Delivery.EmailChannelFormFields do
  @moduledoc false
  use HolterWeb, :component

  import HolterWeb.Components.Input

  attr :form, :any, required: true

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
      </div>
    </div>
    """
  end
end

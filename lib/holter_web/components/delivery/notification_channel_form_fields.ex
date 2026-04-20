defmodule HolterWeb.Components.Delivery.NotificationChannelFormFields do
  @moduledoc false
  use HolterWeb, :component

  import HolterWeb.Components.Input

  alias Holter.Delivery.NotificationChannel

  @doc """
  Renders the main configuration fieldset for a notification channel form.
  Accepts an optional `locked_type` boolean to disable the type selector
  when editing an existing channel.
  """
  attr :form, :any, required: true
  attr :locked_type, :boolean, default: false

  def notification_channel_form_fields(assigns) do
    ~H"""
    <div class="h-fieldset-card">
      <h3 class="h-fieldset-legend">{gettext("Channel Details")}</h3>
      <div class="h-form-grid h-grid-cols-2">
        <div>
          <.input field={@form[:name]} label={gettext("Name")} required />
          <p class="h-help-text">{gettext("A label to identify this channel in your workspace.")}</p>
        </div>

        <div>
          <.input
            field={@form[:type]}
            type="select"
            label={gettext("Type")}
            options={channel_type_options()}
            disabled={@locked_type}
            required
          />
          <p class="h-help-text">
            {gettext("Delivery method. Cannot be changed after creation.")}
          </p>
        </div>

        <div class="h-col-span-2">
          <.input field={@form[:target]} label={gettext("Target")} required />
          <p class="h-help-text">{target_help_text()}</p>
        </div>
      </div>
    </div>
    """
  end

  defp channel_type_options do
    NotificationChannel.channel_types()
    |> Enum.map(fn type ->
      label =
        case type do
          :webhook -> gettext("Webhook")
          :email -> gettext("Email")
        end

      {label, to_string(type)}
    end)
  end

  defp target_help_text do
    gettext("URL for webhook channels. Email address for email channels.")
  end
end

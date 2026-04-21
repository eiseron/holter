defmodule HolterWeb.Components.Delivery.NotificationChannelFormFields do
  @moduledoc false
  use HolterWeb, :component

  import HolterWeb.Components.Input

  alias Holter.Delivery.NotificationChannel

  attr :form, :any, required: true
  attr :locked_type, :boolean, default: false
  attr :selected_type, :atom, default: :webhook

  def notification_channel_form_fields(assigns) do
    ~H"""
    <div class="h-fieldset-card">
      <h3 class="h-fieldset-legend">{gettext("Channel Details")}</h3>
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
          <.input
            field={@form[:target]}
            type={input_type_for(@selected_type)}
            label={gettext("Target")}
            placeholder={target_placeholder(@selected_type)}
            required
          />
          <p class="h-help-text">{target_help_text(@selected_type)}</p>
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

  defp input_type_for(:email), do: "email"
  defp input_type_for(_), do: "url"

  defp target_placeholder(:email), do: "ops@example.com"
  defp target_placeholder(_), do: "https://example.com/webhook"

  defp target_help_text(:email),
    do: gettext("The primary email address that will receive alerts.")

  defp target_help_text(_),
    do: gettext("The URL that will receive HTTP POST requests with alert payloads.")
end

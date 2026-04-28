defmodule HolterWeb.Web.Delivery.EmailChannelLive.Verify do
  use HolterWeb, :live_view

  alias Holter.Delivery
  alias Holter.Delivery.{EmailChannel, NotificationChannel}

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    result =
      if connected?(socket) do
        Delivery.verify_email_channel(token)
      else
        Delivery.get_email_channel_by_verification_token(token)
      end

    case result do
      {:ok, %NotificationChannel{id: channel_id}} ->
        {:ok,
         socket
         |> assign(:status, :verified)
         |> assign(:channel_id, channel_id)}

      {:ok, %EmailChannel{notification_channel_id: channel_id}} ->
        {:ok,
         socket
         |> assign(:status, :verified)
         |> assign(:channel_id, channel_id)}

      {:error, :expired} ->
        {:ok, assign(socket, :status, :expired)}

      {:error, :not_found} ->
        {:ok, assign(socket, :status, :not_found)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-page-container">
      <%= case @status do %>
        <% :verified -> %>
          <h1 class="h-header-title">{gettext("Email channel verified")}</h1>
          <p class="h-header-subtitle h-mt-2">
            {gettext(
              "This email address has been verified. The channel will now deliver alerts here."
            )}
          </p>
          <.link
            navigate={~p"/delivery/notification-channels/#{@channel_id}"}
            class="h-btn h-btn-primary h-mt-6"
            style="display:inline-flex"
          >
            {gettext("Back to channel settings")}
          </.link>
        <% :expired -> %>
          <h1 class="h-header-title">{gettext("Link expired")}</h1>
          <p class="h-header-subtitle h-mt-2">
            {gettext(
              "This verification link has expired. Open the channel settings and click \"Resend verification\" to request a new link."
            )}
          </p>
        <% :not_found -> %>
          <h1 class="h-header-title">{gettext("Link not found")}</h1>
          <p class="h-header-subtitle h-mt-2">
            {gettext("This verification link is invalid or has already been used.")}
          </p>
      <% end %>
    </div>
    """
  end
end

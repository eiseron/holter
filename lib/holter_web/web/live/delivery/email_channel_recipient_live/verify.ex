defmodule HolterWeb.Web.Delivery.EmailChannelRecipientLive.Verify do
  use HolterWeb, :live_view

  alias Holter.Delivery.EmailChannels

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    result =
      if connected?(socket) do
        EmailChannels.verify_recipient(token)
      else
        EmailChannels.get_recipient_by_token(token)
      end

    case result do
      {:ok, recipient} ->
        {:ok,
         socket
         |> assign(:status, :verified)
         |> assign(:channel_id, recipient.email_channel_id)}

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
          <h1 class="h-header-title">{gettext("Email verified")}</h1>
          <p class="h-header-subtitle h-mt-2">
            {gettext(
              "Your email address has been verified. You will now receive notifications through this channel."
            )}
          </p>
          <.link
            navigate={~p"/delivery/email-channels/#{@channel_id}"}
            class="h-btn h-btn-primary h-mt-6"
            style="display:inline-flex"
          >
            {gettext("Back to channel settings")}
          </.link>
        <% :expired -> %>
          <h1 class="h-header-title">{gettext("Link expired")}</h1>
          <p class="h-header-subtitle h-mt-2">
            {gettext(
              "This verification link has expired. Please ask the channel owner to re-add your email address."
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

defmodule HolterWeb.Web.Delivery.EmailChannelRecipientLive.Verify do
  use HolterWeb, :live_view

  alias Holter.Delivery.EmailChannels
  alias Holter.Monitoring
  alias Holter.Repo.Tenant

  @impl true
  def mount(%{"workspace_slug" => slug, "token" => token}, _session, socket) do
    slug
    |> Monitoring.get_workspace_by_slug()
    |> resolve_token(token, socket)
    |> handle_verify_result(socket)
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

  defp resolve_token({:ok, workspace}, token, socket) do
    Tenant.with_workspace!(workspace.id, fn ->
      if connected?(socket) do
        EmailChannels.verify_recipient(token)
      else
        EmailChannels.get_recipient_by_token(token)
      end
    end)
  end

  defp resolve_token({:error, :not_found}, _token, _socket), do: {:error, :not_found}

  defp handle_verify_result({:ok, recipient}, socket) do
    {:ok,
     socket
     |> assign(:status, :verified)
     |> assign(:channel_id, recipient.email_channel_id)}
  end

  defp handle_verify_result({:error, :expired}, socket) do
    {:ok, assign(socket, :status, :expired)}
  end

  defp handle_verify_result({:error, :not_found}, socket) do
    {:ok, assign(socket, :status, :not_found)}
  end
end

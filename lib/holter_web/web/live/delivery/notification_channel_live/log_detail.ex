defmodule HolterWeb.Web.Delivery.NotificationChannelLive.LogDetail do
  use HolterWeb, :delivery_live_view

  alias Holter.Delivery
  alias Holter.Monitoring

  @impl true
  def mount(%{"log_id" => log_id}, _session, socket) do
    log = Delivery.get_channel_log!(log_id)
    channel = Delivery.get_channel!(log.notification_channel_id)
    {:ok, workspace} = Monitoring.get_workspace(channel.workspace_id)

    {:ok,
     socket
     |> assign(:workspace, workspace)
     |> assign(:channel, channel)
     |> assign(:log, log)
     |> assign(:page_title, gettext("Delivery Log Detail"))}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}
end

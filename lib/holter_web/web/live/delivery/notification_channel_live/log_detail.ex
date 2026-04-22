defmodule HolterWeb.Web.Delivery.NotificationChannelLive.LogDetail do
  use HolterWeb, :delivery_live_view

  alias Holter.Delivery
  alias Holter.Delivery.ChannelLogs
  alias Holter.Monitoring

  @impl true
  def mount(%{"log_id" => log_id}, _session, socket) do
    job = Delivery.get_channel_log!(String.to_integer(log_id))
    channel = Delivery.get_channel!(job.args["channel_id"])
    {:ok, workspace} = Monitoring.get_workspace(channel.workspace_id)

    {:ok,
     socket
     |> assign(:workspace, workspace)
     |> assign(:channel, channel)
     |> assign(:job, job)
     |> assign(:page_title, gettext("Delivery Log Detail"))}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  defp classify_delivery_status(job), do: ChannelLogs.classify_delivery_status(job)
  defp format_event_type(job), do: ChannelLogs.format_event_type(job)
  defp format_last_error(job), do: ChannelLogs.format_last_error(job)
end

defmodule HolterWeb.Web.Delivery.NotificationChannelLive.LogDetail do
  use HolterWeb, :delivery_live_view

  alias Holter.Delivery
  alias Holter.Delivery.ChannelLogs

  @impl true
  def mount(%{"id" => channel_id, "log_id" => log_id}, _session, socket) do
    with {:ok, channel} <- Delivery.get_channel(channel_id),
         {:ok, job} <- Delivery.get_channel_log(channel_id, log_id) do
      {:ok,
       socket
       |> assign(:channel, channel)
       |> assign(:job, job)
       |> assign(:page_title, gettext("Delivery Log Detail"))}
    else
      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Not found"))
         |> push_navigate(to: "/")}
    end
  end

  defp classify_delivery_status(job), do: ChannelLogs.classify_delivery_status(job)
  defp format_event_type(job), do: ChannelLogs.format_event_type(job)
end

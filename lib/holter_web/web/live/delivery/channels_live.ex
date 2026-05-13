defmodule HolterWeb.Web.Delivery.ChannelsLive do
  use HolterWeb, :workspace_live_view

  import HolterWeb.Components.Monitoring.DashboardHeader

  alias Holter.Delivery
  alias Holter.Delivery.{EmailChannels, Profiles, WebhookChannels}
  alias Holter.Monitoring

  @impl true
  def mount(%{"workspace_slug" => slug}, _session, socket) do
    case Monitoring.get_workspace_by_slug(slug) do
      {:ok, workspace} ->
        channels = list_all_channels(workspace.id)
        channel_max = Profiles.get_for_workspace!(workspace.id).max_channels

        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:page_title, gettext("Notification Channels"))
         |> assign(:channels, channels)
         |> assign(:channel_max, channel_max)
         |> assign(:at_quota, Delivery.count_channels(workspace.id) >= channel_max)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Workspace not found"))
         |> push_navigate(to: "/")}
    end
  end

  defp list_all_channels(workspace_id) do
    webhooks =
      workspace_id
      |> WebhookChannels.list()
      |> Enum.map(fn c ->
        %{
          id: c.id,
          name: c.name,
          type: :webhook,
          target: c.url,
          show_path: ~p"/delivery/webhook-channels/#{c.id}"
        }
      end)

    emails =
      workspace_id
      |> EmailChannels.list()
      |> Enum.map(fn c ->
        %{
          id: c.id,
          name: c.name,
          type: :email,
          target: format_recipient_count(EmailChannels.list_recipients(c.id)),
          show_path: ~p"/delivery/email-channels/#{c.id}"
        }
      end)

    Enum.sort_by(webhooks ++ emails, & &1.name)
  end

  defp format_recipient_count([]), do: gettext("No recipients")

  defp format_recipient_count(recipients) do
    verified = Enum.count(recipients, & &1.verified_at)
    total = length(recipients)

    if verified == total do
      ngettext("%{count} verified recipient", "%{count} verified recipients", total, count: total)
    else
      gettext("%{verified}/%{total} verified", verified: verified, total: total)
    end
  end
end

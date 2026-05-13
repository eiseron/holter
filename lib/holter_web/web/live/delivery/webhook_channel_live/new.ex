defmodule HolterWeb.Web.Delivery.WebhookChannelLive.New do
  use HolterWeb, :delivery_live_view

  import HolterWeb.Components.Delivery.MonitorChannelSelect
  import HolterWeb.Components.Delivery.WebhookChannelFormFields

  alias Holter.Delivery
  alias Holter.Delivery.Models.WebhookChannel
  alias Holter.Delivery.{Profiles, WebhookChannels}
  alias Holter.Monitoring

  @impl true
  def mount(%{"workspace_slug" => slug}, _session, socket) do
    case Monitoring.get_workspace_by_slug(slug) do
      {:ok, workspace} -> mount_for_workspace(socket, workspace)
      {:error, :not_found} -> {:ok, redirect_workspace_not_found(socket)}
    end
  end

  @impl true
  def handle_event("validate", %{"webhook_channel" => params}, socket) do
    changeset =
      %WebhookChannel{}
      |> WebhookChannels.change(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"webhook_channel" => params} = full_params, socket) do
    actor = socket.assigns.current_user
    workspace = socket.assigns.workspace
    attrs = Map.put(params, "workspace_id", workspace.id)
    monitor_ids = Map.get(full_params, "monitor_ids", [])

    with :ok <- authorize(actor, :create, {WebhookChannel, workspace}),
         {:ok, channel} <- WebhookChannels.create(attrs) do
      WebhookChannels.sync_monitors_for(channel.id, monitor_ids)

      {:noreply,
       socket
       |> put_flash(:info, gettext("Webhook channel created successfully"))
       |> push_navigate(to: ~p"/delivery/workspaces/#{workspace.slug}/channels")}
    else
      {:error, :unauthorized} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("You are not allowed to create channels in this workspace.")
         )}

      {:error, :channel_quota_reached} ->
        {:noreply,
         redirect_channel_quota_reached(
           socket,
           socket.assigns.workspace,
           socket.assigns.channel_max
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp mount_for_workspace(socket, workspace) do
    channel_max = Profiles.get_for_workspace!(workspace.id).max_channels

    if Delivery.count_channels(workspace.id) >= channel_max do
      {:ok, redirect_channel_quota_reached(socket, workspace, channel_max)}
    else
      {:ok, build_new_channel_socket(socket, workspace, channel_max)}
    end
  end

  defp build_new_channel_socket(socket, workspace, channel_max) do
    changeset = WebhookChannels.change(%WebhookChannel{workspace_id: workspace.id})
    available_monitors = Monitoring.list_monitors_by_workspace(workspace.id)

    socket
    |> assign(:workspace, workspace)
    |> assign(:channel_max, channel_max)
    |> assign(:page_title, gettext("New Webhook Channel"))
    |> assign(:available_monitors, available_monitors)
    |> assign(:form, to_form(changeset))
  end

  defp redirect_workspace_not_found(socket) do
    socket
    |> put_flash(:error, gettext("Workspace not found"))
    |> push_navigate(to: "/")
  end

  defp redirect_channel_quota_reached(socket, workspace, channel_max) do
    socket
    |> put_flash(
      :error,
      gettext("Channel limit reached for this workspace (max: %{max})", max: channel_max)
    )
    |> push_navigate(to: ~p"/delivery/workspaces/#{workspace.slug}/channels")
  end
end

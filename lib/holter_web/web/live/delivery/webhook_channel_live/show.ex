defmodule HolterWeb.Web.Delivery.WebhookChannelLive.Show do
  use HolterWeb, :delivery_live_view

  import HolterWeb.Components.Delivery.ChannelForm
  import HolterWeb.Components.Delivery.SecretCard
  import HolterWeb.Components.Delivery.WebhookChannelFormFields

  alias Holter.Delivery.{Engine, WebhookChannels}
  alias Holter.Monitoring
  alias HolterWeb.Web.Delivery.ChannelLiveCommon

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    with {:ok, channel} <- WebhookChannels.get(id),
         {:ok, workspace} <- Monitoring.get_workspace(channel.workspace_id) do
      changeset = WebhookChannels.change(channel)

      available_monitors =
        Monitoring.list_monitors_by_workspace(workspace.id)

      linked_monitor_ids = WebhookChannels.list_monitor_ids_for(id)

      {:ok,
       socket
       |> assign(:workspace, workspace)
       |> assign(:channel, channel)
       |> assign(:page_title, channel.name)
       |> assign(:form, to_form(changeset))
       |> assign(:available_monitors, available_monitors)
       |> assign(:linked_monitor_ids, linked_monitor_ids)
       |> assign(:test_sent, false)
       |> ChannelLiveCommon.assign_test_cooldown(channel.last_test_dispatched_at)}
    else
      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Not found"))
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_event("validate", %{"webhook_channel" => params}, socket) do
    changeset =
      socket.assigns.channel
      |> WebhookChannels.change(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"webhook_channel" => params} = full_params, socket) do
    actor = socket.assigns.current_user
    channel = socket.assigns.channel
    monitor_ids = Map.get(full_params, "monitor_ids", [])

    with :ok <- authorize(actor, :update, channel),
         {:ok, updated} <- WebhookChannels.update(channel, params) do
      WebhookChannels.sync_monitors_for(updated.id, monitor_ids)
      linked_monitor_ids = WebhookChannels.list_monitor_ids_for(updated.id)

      {:noreply,
       socket
       |> put_flash(:info, gettext("Webhook channel updated successfully"))
       |> assign(:channel, updated)
       |> assign(:linked_monitor_ids, linked_monitor_ids)
       |> assign(:form, to_form(WebhookChannels.change(updated)))}
    else
      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, gettext("You are not allowed to update this channel."))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("test", _params, socket) do
    actor = socket.assigns.current_user
    channel = socket.assigns.channel

    with :ok <- authorize(actor, :test, channel),
         {:ok, _} <- Engine.dispatch_test_webhook(channel.id) do
      {:ok, refreshed} = WebhookChannels.get(channel.id)

      {:noreply,
       socket
       |> put_flash(:info, gettext("Test notification enqueued"))
       |> assign(:test_sent, true)
       |> assign(:channel, refreshed)
       |> ChannelLiveCommon.assign_test_cooldown(refreshed.last_test_dispatched_at)}
    else
      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, gettext("You are not allowed to test this channel."))}

      {:error, :test_dispatch_rate_limited} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Wait before sending another test ping for this channel.")
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to enqueue test notification"))}
    end
  end

  @impl true
  def handle_event("regenerate_secret", _params, socket) do
    actor = socket.assigns.current_user
    channel = socket.assigns.channel

    with :ok <- authorize(actor, :update, channel),
         {:ok, updated} <- WebhookChannels.regenerate_signing_token(channel) do
      {:noreply,
       socket
       |> put_flash(
         :info,
         gettext("Signing token regenerated. Update your receiver to avoid missed alerts.")
       )
       |> assign(:channel, updated)}
    else
      {:error, :unauthorized} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("You are not allowed to rotate this channel's secret.")
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to regenerate the signing token"))}
    end
  end

  @impl true
  def handle_event("delete_channel", _params, socket) do
    actor = socket.assigns.current_user
    channel = socket.assigns.channel
    workspace = socket.assigns.workspace

    with :ok <- authorize(actor, :delete, channel),
         {:ok, _} <- WebhookChannels.delete(channel) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Webhook channel deleted successfully"))
       |> push_navigate(to: ~p"/delivery/workspaces/#{workspace.slug}/channels")}
    else
      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, gettext("You are not allowed to delete this channel."))}
    end
  end

  @impl true
  def handle_info(:tick, socket), do: {:noreply, ChannelLiveCommon.handle_tick(socket)}
  def handle_info(_message, socket), do: {:noreply, socket}
end

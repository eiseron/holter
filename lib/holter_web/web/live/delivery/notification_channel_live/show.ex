defmodule HolterWeb.Web.Delivery.NotificationChannelLive.Show do
  use HolterWeb, :delivery_live_view

  import HolterWeb.Components.Delivery.MonitorChannelSelect

  alias Holter.Delivery
  alias Holter.Delivery.Emails.RecipientVerification
  alias Holter.Delivery.Engine
  alias Holter.Mailers.InfoMailer
  alias Holter.Monitoring

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    with {:ok, channel} <- Delivery.get_channel(id),
         {:ok, workspace} <- Monitoring.get_workspace(channel.workspace_id) do
      changeset = Delivery.change_channel(channel)
      available_monitors = Monitoring.list_monitors_by_workspace(workspace.id)
      linked_monitor_ids = Delivery.list_monitor_ids_for_channel(id)

      {:ok,
       socket
       |> assign(:workspace, workspace)
       |> assign(:channel, channel)
       |> assign(:page_title, channel.name)
       |> assign(:selected_type, channel.type)
       |> assign(:form, to_form(changeset))
       |> assign(:available_monitors, available_monitors)
       |> assign(:linked_monitor_ids, linked_monitor_ids)
       |> assign(:recipients, load_recipients(channel))
       |> assign(:cc_input, "")
       |> assign(:test_sent, false)}
    else
      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Not found"))
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_event("validate", %{"notification_channel" => params}, socket) do
    changeset =
      socket.assigns.channel
      |> Delivery.change_channel(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"notification_channel" => params} = full_params, socket) do
    monitor_ids = Map.get(full_params, "monitor_ids", [])

    case Delivery.update_channel(socket.assigns.channel, params) do
      {:ok, channel} ->
        Delivery.sync_monitors_for_channel(channel.id, monitor_ids)
        linked_monitor_ids = Delivery.list_monitor_ids_for_channel(channel.id)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Channel updated successfully"))
         |> assign(:channel, channel)
         |> assign(:linked_monitor_ids, linked_monitor_ids)
         |> assign(:form, to_form(Delivery.change_channel(channel)))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("test", _params, socket) do
    case Engine.dispatch_test(socket.assigns.channel.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Test notification enqueued"))
         |> assign(:test_sent, true)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to enqueue test notification"))}
    end
  end

  @impl true
  def handle_event("update_cc_input", %{"cc_email" => email}, socket) do
    {:noreply, assign(socket, :cc_input, email)}
  end

  @impl true
  def handle_event("add_recipient", params, socket) do
    email = (Map.get(params, "email") || Map.get(params, "value", "")) |> String.trim()
    channel = socket.assigns.channel

    case Delivery.add_recipient(channel.id, email) do
      {:ok, recipient} ->
        verification_url =
          url(~p"/delivery/notification-channels/recipients/verify/#{recipient.token}")

        RecipientVerification.build_verification_email(
          recipient,
          channel,
          %{url: verification_url, from: info_from_address()}
        )
        |> InfoMailer.deliver()

        {:noreply,
         socket
         |> put_flash(:info, gettext("Verification email sent to %{email}", email: email))
         |> assign(:recipients, Delivery.list_recipients(channel.id))
         |> assign(:cc_input, "")}

      {:error, changeset} ->
        [message | _] =
          changeset.errors |> Keyword.values() |> List.flatten() |> Enum.map(&elem(&1, 0))

        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("delete_channel", _params, socket) do
    channel = socket.assigns.channel
    workspace = socket.assigns.workspace
    {:ok, _} = Delivery.delete_channel(channel)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Channel deleted successfully"))
     |> push_navigate(to: ~p"/delivery/workspaces/#{workspace.slug}/channels")}
  end

  @impl true
  def handle_event("remove_recipient", %{"id" => id}, socket) do
    channel = socket.assigns.channel
    Delivery.remove_recipient(id)

    {:noreply, assign(socket, :recipients, Delivery.list_recipients(channel.id))}
  end

  defp load_recipients(%{type: :email, id: id}), do: Delivery.list_recipients(id)
  defp load_recipients(_), do: []

  defp info_from_address, do: Application.fetch_env!(:holter, :info_email)[:from_address]
end

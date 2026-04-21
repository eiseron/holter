defmodule HolterWeb.Web.Delivery.NotificationChannelLive.New do
  use HolterWeb, :delivery_live_view

  import HolterWeb.Components.Delivery.MonitorChannelSelect

  alias Holter.Delivery
  alias Holter.Delivery.Emails.RecipientVerification
  alias Holter.Delivery.NotificationChannel
  alias Holter.Mailers.InfoMailer
  alias Holter.Monitoring

  @impl true
  def mount(%{"workspace_slug" => slug}, _session, socket) do
    case Monitoring.get_workspace_by_slug(slug) do
      {:ok, workspace} ->
        changeset = Delivery.change_channel(%NotificationChannel{workspace_id: workspace.id})
        available_monitors = Monitoring.list_monitors_by_workspace(workspace.id)

        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:page_title, gettext("New Notification Channel"))
         |> assign(:selected_type, :email)
         |> assign(:available_monitors, available_monitors)
         |> assign(:form, to_form(changeset))
         |> assign(:pending_cc_emails, [])
         |> assign(:new_cc_input, "")}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Workspace not found"))
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_event("validate", %{"notification_channel" => params}, socket) do
    changeset =
      %NotificationChannel{}
      |> Delivery.change_channel(params)
      |> Map.put(:action, :validate)

    selected_type =
      case params["type"] do
        t when t in ["email", "webhook"] -> String.to_existing_atom(t)
        _ -> socket.assigns.selected_type
      end

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:selected_type, selected_type)}
  end

  @impl true
  def handle_event("update_new_cc_input", %{"cc_email" => email}, socket) do
    {:noreply, assign(socket, :new_cc_input, email)}
  end

  @impl true
  def handle_event("add_pending_cc", params, socket) do
    email = (Map.get(params, "email") || Map.get(params, "value", "")) |> String.trim()

    if valid_email?(email) and email not in socket.assigns.pending_cc_emails do
      {:noreply,
       socket
       |> assign(:pending_cc_emails, socket.assigns.pending_cc_emails ++ [email])
       |> assign(:new_cc_input, "")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_pending_cc", %{"email" => email}, socket) do
    updated = Enum.reject(socket.assigns.pending_cc_emails, &(&1 == email))
    {:noreply, assign(socket, :pending_cc_emails, updated)}
  end

  @impl true
  def handle_event("save", %{"notification_channel" => params} = full_params, socket) do
    workspace = socket.assigns.workspace
    attrs = Map.put(params, "workspace_id", workspace.id)
    monitor_ids = Map.get(full_params, "monitor_ids", [])

    case Delivery.create_channel(attrs) do
      {:ok, channel} ->
        Delivery.sync_monitors_for_channel(channel.id, monitor_ids)
        add_pending_cc_recipients(channel, socket.assigns.pending_cc_emails)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Channel created successfully"))
         |> push_navigate(to: ~p"/delivery/workspaces/#{workspace.slug}/channels")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp info_from_address, do: Application.fetch_env!(:holter, :info_email)[:from_address]

  defp valid_email?(email), do: email =~ ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  defp add_pending_cc_recipients(channel, emails) do
    Enum.each(emails, fn email ->
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

        {:error, _} ->
          :ok
      end
    end)
  end
end

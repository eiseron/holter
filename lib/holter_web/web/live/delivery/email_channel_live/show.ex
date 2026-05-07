defmodule HolterWeb.Web.Delivery.EmailChannelLive.Show do
  use HolterWeb, :delivery_live_view

  import HolterWeb.Components.Delivery.ChannelForm
  import HolterWeb.Components.Delivery.EmailChannelFormFields
  import HolterWeb.Components.Delivery.SecretCard

  alias Holter.Delivery.{EmailChannels, Engine}
  alias Holter.Delivery.Emails.RecipientVerification
  alias Holter.Mailers.InfoMailer
  alias Holter.Monitoring
  alias HolterWeb.Web.Delivery.ChannelLiveCommon

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    with {:ok, channel} <- EmailChannels.get(id),
         {:ok, workspace} <- Monitoring.get_workspace(channel.workspace_id) do
      changeset = EmailChannels.change(channel)
      available_monitors = Monitoring.list_monitors_by_workspace(workspace.id)
      linked_monitor_ids = EmailChannels.list_monitor_ids_for(id)

      {:ok,
       socket
       |> assign(:workspace, workspace)
       |> assign(:channel, channel)
       |> assign(:page_title, channel.name)
       |> assign(:form, to_form(changeset))
       |> assign(:available_monitors, available_monitors)
       |> assign(:linked_monitor_ids, linked_monitor_ids)
       |> assign(:saved_recipients, EmailChannels.list_recipients(channel.id))
       |> assign(:pending_additions, [])
       |> assign(:pending_removed_ids, MapSet.new())
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
  def handle_event("validate", %{"email_channel" => params}, socket) do
    changeset =
      socket.assigns.channel
      |> EmailChannels.change(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"email_channel" => params} = full_params, socket) do
    monitor_ids = Map.get(full_params, "monitor_ids", [])

    staged = %{
      attrs: params,
      additions: socket.assigns.pending_additions,
      removed_ids: MapSet.to_list(socket.assigns.pending_removed_ids)
    }

    case EmailChannels.apply_staged_changes(socket.assigns.channel, staged) do
      {:ok, %{channel: channel, added: added_recipients}} ->
        EmailChannels.sync_monitors_for(channel.id, monitor_ids)
        Enum.each(added_recipients, &deliver_verification_email(&1, channel))

        {:noreply,
         socket
         |> put_flash(:info, gettext("Email channel updated successfully"))
         |> assign(:channel, channel)
         |> assign(:linked_monitor_ids, EmailChannels.list_monitor_ids_for(channel.id))
         |> assign(:saved_recipients, EmailChannels.list_recipients(channel.id))
         |> assign(:pending_additions, [])
         |> assign(:pending_removed_ids, MapSet.new())
         |> assign(:form, to_form(EmailChannels.change(channel)))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("test", _params, socket) do
    case Engine.dispatch_test_email(socket.assigns.channel.id) do
      {:ok, _} ->
        {:ok, refreshed} = EmailChannels.get(socket.assigns.channel.id)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Test notification enqueued"))
         |> assign(:test_sent, true)
         |> assign(:channel, refreshed)
         |> ChannelLiveCommon.assign_test_cooldown(refreshed.last_test_dispatched_at)}

      {:error, :no_verified_recipients} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext(
             "Cannot send a test: this channel has no verified recipients. Add at least one and verify it first."
           )
         )}

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
  def handle_event("add_pending_recipient", %{"recipient" => %{"email" => email}}, socket) do
    email = String.trim(email)

    cond do
      not valid_email?(email) ->
        {:noreply, socket}

      email in socket.assigns.pending_additions ->
        {:noreply, socket}

      Enum.any?(socket.assigns.saved_recipients, &(&1.email == email)) ->
        {:noreply,
         put_flash(socket, :info, gettext("%{email} is already on this channel.", email: email))}

      true ->
        {:noreply,
         socket
         |> assign(:pending_additions, socket.assigns.pending_additions ++ [email])
         |> push_event("recipient-input-clear", %{})}
    end
  end

  @impl true
  def handle_event("cancel_pending_recipient", %{"email" => email}, socket) do
    {:noreply,
     assign(
       socket,
       :pending_additions,
       Enum.reject(socket.assigns.pending_additions, &(&1 == email))
     )}
  end

  @impl true
  def handle_event("mark_recipient_for_removal", %{"id" => id}, socket) do
    {:noreply,
     assign(
       socket,
       :pending_removed_ids,
       MapSet.put(socket.assigns.pending_removed_ids, id)
     )}
  end

  @impl true
  def handle_event("restore_recipient", %{"id" => id}, socket) do
    {:noreply,
     assign(
       socket,
       :pending_removed_ids,
       MapSet.delete(socket.assigns.pending_removed_ids, id)
     )}
  end

  @impl true
  def handle_event("regenerate_secret", _params, socket) do
    case EmailChannels.regenerate_anti_phishing_code(socket.assigns.channel) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("Anti-phishing code regenerated. The next email will contain the new code.")
         )
         |> assign(:channel, updated)}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, gettext("Failed to regenerate the anti-phishing code"))}
    end
  end

  @impl true
  def handle_event("delete_channel", _params, socket) do
    channel = socket.assigns.channel
    workspace = socket.assigns.workspace
    {:ok, _} = EmailChannels.delete(channel)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Email channel deleted successfully"))
     |> push_navigate(to: ~p"/delivery/workspaces/#{workspace.slug}/channels")}
  end

  @impl true
  def handle_event("resend_recipient_verification", %{"id" => id}, socket) do
    case EmailChannels.resend_recipient_verification(id) do
      {:ok, recipient} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("Verification email sent to %{email}", email: recipient.email)
         )
         |> assign(:saved_recipients, EmailChannels.list_recipients(socket.assigns.channel.id))}

      {:error, :already_verified} ->
        {:noreply, put_flash(socket, :info, gettext("This recipient is already verified."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to send verification email"))}
    end
  end

  @impl true
  def handle_info(:tick, socket), do: {:noreply, ChannelLiveCommon.handle_tick(socket)}
  def handle_info(_message, socket), do: {:noreply, socket}

  defp valid_email?(email), do: email =~ ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  defp deliver_verification_email(recipient, channel) do
    verification_url =
      url(~p"/delivery/email-channels/recipients/verify/#{recipient.token}")

    RecipientVerification.build_verification_email(
      recipient,
      channel,
      %{url: verification_url, from: info_from_address()}
    )
    |> InfoMailer.deliver()
  end

  defp info_from_address, do: Application.fetch_env!(:holter, :info_email)[:from_address]
end

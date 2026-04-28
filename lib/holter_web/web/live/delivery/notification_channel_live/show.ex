defmodule HolterWeb.Web.Delivery.NotificationChannelLive.Show do
  use HolterWeb, :delivery_live_view

  import HolterWeb.Components.Delivery.MonitorChannelSelect
  import HolterWeb.Components.Delivery.SecretCard

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
       |> assign(:email_verification_status, email_verification_status(channel))
       |> assign(:cc_input, "")
       |> assign(:test_sent, false)
       |> assign_test_cooldown(channel.last_test_dispatched_at)}
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
         |> assign(:email_verification_status, email_verification_status(channel))
         |> assign(:form, to_form(Delivery.change_channel(channel)))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("test", _params, socket) do
    case Engine.dispatch_test(socket.assigns.channel.id) do
      {:ok, _} ->
        {:ok, refreshed} = Delivery.get_channel(socket.assigns.channel.id)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Test notification enqueued"))
         |> assign(:test_sent, true)
         |> assign(:channel, refreshed)
         |> assign_test_cooldown(refreshed.last_test_dispatched_at)}

      {:error, :no_verified_recipients} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext(
             "Cannot send a test: no recipient on this channel is verified. Verify the primary email or at least one CC recipient first."
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
  def handle_event("resend_email_verification", _params, socket) do
    case Delivery.send_email_channel_verification(socket.assigns.channel) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("Verification email sent to %{email}.",
             email: updated.email_channel.address
           )
         )
         |> assign(:channel, updated)
         |> assign(:email_verification_status, email_verification_status(updated))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to send verification email"))}
    end
  end

  @impl true
  def handle_event("regenerate_secret", _params, socket) do
    case regenerate_for(socket.assigns.channel) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, regenerate_secret_message(updated))
         |> assign(:channel, updated)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to regenerate the secret"))}
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

  @impl true
  def handle_event("resend_recipient_verification", %{"id" => id}, socket) do
    case Delivery.resend_recipient_verification(id) do
      {:ok, recipient} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("Verification email sent to %{email}", email: recipient.email)
         )
         |> assign(:recipients, Delivery.list_recipients(socket.assigns.channel.id))}

      {:error, :already_verified} ->
        {:noreply, put_flash(socket, :info, gettext("This recipient is already verified."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to send verification email"))}
    end
  end

  @impl true
  def handle_info(:tick, socket) do
    new_cooldown = max(0, socket.assigns.cooldown_remaining - 1)

    if new_cooldown > 0, do: Process.send_after(self(), :tick, 1000)

    {:noreply, assign(socket, :cooldown_remaining, new_cooldown)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp load_recipients(%{type: :email, id: id}), do: Delivery.list_recipients(id)
  defp load_recipients(_), do: []

  defp assign_test_cooldown(socket, nil), do: assign(socket, :cooldown_remaining, 0)

  defp assign_test_cooldown(socket, %DateTime{} = last) do
    diff = DateTime.diff(DateTime.utc_now(), last, :second)
    remaining = max(0, Engine.test_dispatch_cooldown() - diff)
    already_ticking = Map.get(socket.assigns, :cooldown_remaining, 0) > 0

    if remaining > 0 and not already_ticking and connected?(socket) do
      Process.send_after(self(), :tick, 1000)
    end

    assign(socket, :cooldown_remaining, remaining)
  end

  defp email_verification_status(%{type: :email, email_channel: %{verified_at: %DateTime{}}}),
    do: :verified

  defp email_verification_status(%{type: :email}), do: :pending
  defp email_verification_status(_), do: nil

  defp info_from_address, do: Application.fetch_env!(:holter, :info_email)[:from_address]

  defp regenerate_secret_message(%{type: :webhook}) do
    gettext("Signing token regenerated. Update your receiver to avoid missed alerts.")
  end

  defp regenerate_secret_message(%{type: :email}) do
    gettext("Anti-phishing code regenerated. The next email will contain the new code.")
  end

  defp regenerate_for(%{type: :webhook} = channel),
    do: Delivery.regenerate_signing_token(channel)

  defp regenerate_for(%{type: :email} = channel),
    do: Delivery.regenerate_anti_phishing_code(channel)

  defp regenerate_modal_title(%{type: :webhook}),
    do: gettext("Regenerate signing token")

  defp regenerate_modal_title(%{type: :email}),
    do: gettext("Regenerate anti-phishing code")

  defp regenerate_modal_warning(%{type: :webhook}) do
    gettext(
      "Regenerating invalidates the current signature. Update your receiver before regenerating to avoid missed alerts."
    )
  end

  defp regenerate_modal_warning(%{type: :email}) do
    gettext(
      "Regenerating replaces the code shown in future emails. Recipients trained on the old code will see the new one in the next email."
    )
  end
end

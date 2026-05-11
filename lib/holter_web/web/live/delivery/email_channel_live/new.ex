defmodule HolterWeb.Web.Delivery.EmailChannelLive.New do
  use HolterWeb, :delivery_live_view

  import HolterWeb.Components.Delivery.EmailChannelFormFields
  import HolterWeb.Components.Delivery.MonitorChannelSelect

  alias Holter.Delivery.EmailChannels

  alias Holter.Delivery.Emails.RecipientVerification
  alias Holter.Delivery.Models.EmailChannel
  alias Holter.Mailers.InfoMailer
  alias Holter.Monitoring

  @impl true
  def mount(%{"workspace_slug" => slug}, _session, socket) do
    case Monitoring.get_workspace_by_slug(slug) do
      {:ok, workspace} ->
        changeset = EmailChannels.change(%EmailChannel{workspace_id: workspace.id})

        available_monitors =
          Monitoring.list_monitors_by_workspace(workspace.id)

        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:page_title, gettext("New Email Channel"))
         |> assign(:available_monitors, available_monitors)
         |> assign(:form, to_form(changeset))
         |> assign(:pending_recipients, [])}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Workspace not found"))
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_event("validate", %{"email_channel" => params}, socket) do
    changeset =
      %EmailChannel{}
      |> EmailChannels.change(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("add_pending_recipient", %{"recipient" => %{"email" => email}}, socket) do
    email = String.trim(email)

    if valid_email?(email) and email not in socket.assigns.pending_recipients do
      socket = assign(socket, :pending_recipients, socket.assigns.pending_recipients ++ [email])

      {:noreply,
       socket
       |> push_event("recipient-input-clear", %{})
       |> sync_form_dirty()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_pending_recipient", %{"email" => email}, socket) do
    updated = Enum.reject(socket.assigns.pending_recipients, &(&1 == email))

    {:noreply,
     socket
     |> assign(:pending_recipients, updated)
     |> sync_form_dirty()}
  end

  @impl true
  def handle_event("save", %{"email_channel" => params} = full_params, socket) do
    actor = socket.assigns.current_user
    workspace = socket.assigns.workspace
    attrs = Map.put(params, "workspace_id", workspace.id)
    monitor_ids = Map.get(full_params, "monitor_ids", [])

    with :ok <- authorize(actor, :create, {EmailChannel, workspace}),
         {:ok, channel} <- EmailChannels.create(attrs) do
      EmailChannels.sync_monitors_for(channel.id, monitor_ids)
      persist_pending_recipients(channel, socket.assigns.pending_recipients)

      {:noreply,
       socket
       |> put_flash(
         :info,
         gettext("Channel created. Verification email sent to each recipient.")
       )
       |> push_navigate(to: ~p"/delivery/workspaces/#{workspace.slug}/channels")}
    else
      {:error, :unauthorized} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("You are not allowed to create channels in this workspace.")
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp info_from_address, do: Application.fetch_env!(:holter, :info_email)[:from_address]

  defp valid_email?(email), do: email =~ ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  defp sync_form_dirty(socket) do
    push_event(socket, "form-dirty", %{
      form: "email-channel-form",
      dirty: socket.assigns.pending_recipients != []
    })
  end

  defp persist_pending_recipients(channel, emails) do
    workspace_slug = Holter.Monitoring.get_workspace!(channel.workspace_id).slug

    Enum.each(emails, fn email ->
      case EmailChannels.add_recipient(channel.id, email) do
        {:ok, recipient} ->
          verification_url =
            url(
              ~p"/delivery/workspaces/#{workspace_slug}/email-channels/recipients/verify/#{recipient.token}"
            )

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

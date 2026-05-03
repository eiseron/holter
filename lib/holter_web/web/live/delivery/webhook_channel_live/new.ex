defmodule HolterWeb.Web.Delivery.WebhookChannelLive.New do
  use HolterWeb, :delivery_live_view

  import HolterWeb.Components.Delivery.MonitorChannelSelect
  import HolterWeb.Components.Delivery.WebhookChannelFormFields

  alias Holter.Delivery.{WebhookChannel, WebhookChannels}
  alias Holter.Monitoring

  @impl true
  def mount(%{"workspace_slug" => slug}, _session, socket) do
    case Monitoring.get_workspace_by_slug(slug) do
      {:ok, workspace} ->
        changeset = WebhookChannels.change(%WebhookChannel{workspace_id: workspace.id})
        available_monitors = Monitoring.list_monitors_by_workspace(workspace.id)

        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:page_title, gettext("New Webhook Channel"))
         |> assign(:available_monitors, available_monitors)
         |> assign(:form, to_form(changeset))}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Workspace not found"))
         |> push_navigate(to: "/")}
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
    workspace = socket.assigns.workspace
    attrs = Map.put(params, "workspace_id", workspace.id)
    monitor_ids = Map.get(full_params, "monitor_ids", [])

    case WebhookChannels.create(attrs) do
      {:ok, channel} ->
        WebhookChannels.sync_monitors_for(channel.id, monitor_ids)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Webhook channel created successfully"))
         |> push_navigate(to: ~p"/delivery/workspaces/#{workspace.slug}/channels")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

defmodule HolterWeb.Web.Delivery.NotificationChannelLive.New do
  use HolterWeb, :delivery_live_view

  alias Holter.Delivery
  alias Holter.Delivery.NotificationChannel
  alias Holter.Monitoring

  @impl true
  def mount(%{"workspace_slug" => slug}, _session, socket) do
    case Monitoring.get_workspace_by_slug(slug) do
      {:ok, workspace} ->
        changeset = Delivery.change_channel(%NotificationChannel{workspace_id: workspace.id})

        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:page_title, gettext("New Notification Channel"))
         |> assign(:selected_type, :webhook)
         |> assign(:form, to_form(changeset))}

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
  def handle_event("save", %{"notification_channel" => params}, socket) do
    workspace = socket.assigns.workspace
    attrs = Map.put(params, "workspace_id", workspace.id)

    case Delivery.create_channel(attrs) do
      {:ok, _channel} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Channel created successfully"))
         |> push_navigate(to: ~p"/workspaces/#{workspace.slug}/channels")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

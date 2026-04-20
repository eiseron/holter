defmodule HolterWeb.Web.Delivery.NotificationChannelLive.Show do
  use HolterWeb, :live_view

  alias Holter.Delivery
  alias Holter.Delivery.Engine
  alias Holter.Monitoring

  @impl true
  def mount(%{"workspace_slug" => slug, "id" => id}, _session, socket) do
    with {:ok, workspace} <- Monitoring.get_workspace_by_slug(slug),
         {:ok, channel} <- Delivery.get_channel(id) do
      changeset = Delivery.change_channel(channel)

      {:ok,
       socket
       |> assign(:workspace, workspace)
       |> assign(:channel, channel)
       |> assign(:page_title, channel.name)
       |> assign(:form, to_form(changeset))
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
  def handle_event("save", %{"notification_channel" => params}, socket) do
    case Delivery.update_channel(socket.assigns.channel, params) do
      {:ok, channel} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Channel updated successfully"))
         |> assign(:channel, channel)
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
end

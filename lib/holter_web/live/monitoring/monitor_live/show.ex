defmodule HolterWeb.Monitoring.MonitorLive.Show do
  use HolterWeb, :live_view

  alias Holter.Monitoring
  alias Holter.Monitoring.Monitor

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    hydrated_monitor =
      id
      |> Monitoring.get_monitor!()
      |> hydrate_virtual_array_fields()

    daily_metrics = Monitoring.list_daily_metrics(id)
    changeset = Monitoring.change_monitor(hydrated_monitor)

    {:ok,
     socket
     |> assign(:monitor, hydrated_monitor)
     |> assign(:daily_metrics, daily_metrics)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"monitor" => monitor_params}, socket) do
    changeset =
      socket.assigns.monitor
      |> Monitoring.change_monitor(monitor_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"monitor" => monitor_params}, socket) do
    case Monitoring.update_monitor(socket.assigns.monitor, monitor_params) do
      {:ok, monitor} ->
        hydrated_monitor = hydrate_virtual_array_fields(monitor)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Monitor updated successfully"))
         |> assign(:monitor, hydrated_monitor)
         |> assign(:form, to_form(Monitoring.change_monitor(hydrated_monitor)))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("delete", _params, socket) do
    {:ok, _} = Monitoring.delete_monitor(socket.assigns.monitor)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Monitor deleted successfully"))
     |> push_navigate(to: ~p"/monitoring/dashboard")}
  end

  defp hydrate_virtual_array_fields(%Monitor{} = monitor) do
    %{
      monitor
      | raw_keyword_positive: Enum.join(monitor.keyword_positive || [], ", "),
        raw_keyword_negative: Enum.join(monitor.keyword_negative || [], ", ")
    }
  end
end

defmodule HolterWeb.Monitoring.MonitorLive.New do
  use HolterWeb, :live_view

  alias Holter.Monitoring
  alias Holter.Monitoring.Monitor

  @impl true
  def mount(_params, _session, socket) do
    changeset = Monitoring.change_monitor(%Monitor{})
    {:ok, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"monitor" => monitor_params}, socket) do
    changeset =
      %Monitor{}
      |> Monitoring.change_monitor(monitor_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"monitor" => monitor_params}, socket) do
    case Monitoring.create_monitor(monitor_params) do
      {:ok, _monitor} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Monitor created successfully"))
         |> push_navigate(to: ~p"/monitoring/dashboard")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

defmodule HolterWeb.Web.Monitoring.MonitorLive.New do
  use HolterWeb, :monitoring_live_view

  alias Holter.Monitoring
  alias Holter.Monitoring.Monitor

  @impl true
  def mount(%{"workspace_slug" => slug}, _session, socket) do
    case Monitoring.get_workspace_by_slug(slug) do
      {:ok, workspace} ->
        changeset = Monitoring.change_monitor(%Monitor{workspace_id: workspace.id})

        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:form, to_form(changeset))}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Workspace not found")
         |> push_navigate(to: "/")}
    end
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
    params = Map.put(monitor_params, "workspace_id", socket.assigns.workspace.id)

    case Monitoring.create_monitor(params) do
      {:ok, _monitor} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Monitor created successfully"))
         |> push_navigate(
           to: ~p"/monitoring/workspaces/#{socket.assigns.workspace.slug}/dashboard"
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

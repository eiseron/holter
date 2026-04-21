defmodule HolterWeb.Web.Monitoring.MonitorLive.New do
  use HolterWeb, :monitoring_live_view

  alias Holter.Monitoring
  alias Holter.Monitoring.Monitor

  @impl true
  def mount(%{"workspace_slug" => slug}, _session, socket) do
    case Monitoring.get_workspace_by_slug(slug) do
      {:ok, workspace} ->
        if Monitoring.at_quota?(workspace) do
          {:ok,
           socket
           |> put_flash(
             :error,
             gettext("Monitor limit reached for this workspace (max: %{max})",
               max: workspace.max_monitors
             )
           )
           |> push_navigate(to: "/")}
        else
          changeset = Monitoring.change_monitor(%Monitor{workspace_id: workspace.id})

          {:ok,
           socket
           |> assign(:workspace, workspace)
           |> assign(:page_title, gettext("New Monitor"))
           |> assign(:form, to_form(changeset))}
        end

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Workspace not found"))
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_event("validate", %{"monitor" => monitor_params}, socket) do
    changeset =
      %Monitor{}
      |> Monitoring.change_monitor(monitor_params, socket.assigns.workspace)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"monitor" => monitor_params}, socket) do
    attrs = Map.put(monitor_params, "workspace_id", socket.assigns.workspace.id)

    case Monitoring.create_monitor(attrs) do
      {:ok, monitor} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Monitor created successfully"))
         |> push_navigate(to: ~p"/monitoring/monitor/#{monitor.id}")}

      {:error, :quota_exceeded} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Monitor limit reached for this workspace (max: %{max})",
             max: socket.assigns.workspace.max_monitors
           )
         )}

      {:error, :create_rate_limited} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Too many monitors created recently. Please wait before creating another.")
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

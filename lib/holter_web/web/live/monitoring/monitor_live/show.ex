defmodule HolterWeb.Web.Monitoring.MonitorLive.Show do
  use HolterWeb, :monitoring_live_view

  alias Holter.Monitoring
  alias Holter.Monitoring.Monitor

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Holter.PubSub, "monitoring:monitor:#{id}")
    end

    monitor = Monitoring.get_monitor!(id)
    workspace = Monitoring.get_workspace!(monitor.workspace_id)
    hydrated_monitor = hydrate_virtual_array_fields(monitor)

    changeset = Monitoring.change_monitor(hydrated_monitor)

    socket =
      socket
      |> assign(:workspace, workspace)
      |> assign(:monitor, hydrated_monitor)
      |> assign(:page_title, gettext("Monitor Details"))
      |> assign(:form, to_form(changeset))
      |> assign_cooldown(monitor.last_manual_check_at)

    {:ok, socket}
  end

  @impl true
  def handle_event("run_now", _params, socket) do
    cond do
      socket.assigns.cooldown_remaining > 0 ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Please wait before triggering another manual check."))}

      socket.assigns.form.source.changes != %{} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("You have unsaved changes. Please save them before checking.")
         )}

      true ->
        trigger_manual_check(socket)
    end
  end

  @impl true
  def handle_event("validate", %{"monitor" => monitor_params}, socket) do
    changeset =
      socket.assigns.monitor
      |> Monitoring.change_monitor(monitor_params, socket.assigns.workspace)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
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

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _} = Monitoring.delete_monitor(socket.assigns.monitor)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Monitor deleted successfully"))
     |> push_navigate(to: ~p"/monitoring/workspaces/#{socket.assigns.workspace.slug}/dashboard")}
  end

  @impl true
  def handle_info({event, _data}, socket)
      when event in [
             :log_created,
             :monitor_updated,
             :incident_created,
             :incident_resolved,
             :incident_updated
           ] do
    monitor = Monitoring.get_monitor!(socket.assigns.monitor.id)
    hydrated_monitor = hydrate_virtual_array_fields(monitor)

    {:noreply,
     socket
     |> assign(:monitor, hydrated_monitor)
     |> assign_cooldown(monitor.last_manual_check_at)}
  end

  @impl true
  def handle_info(:tick, socket) do
    new_cooldown = max(0, socket.assigns.cooldown_remaining - 1)

    if new_cooldown > 0 do
      Process.send_after(self(), :tick, 1000)
    end

    {:noreply, assign(socket, :cooldown_remaining, new_cooldown)}
  end

  defp assign_cooldown(socket, nil), do: assign(socket, :cooldown_remaining, 0)

  defp assign_cooldown(socket, last_check) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, last_check)

    remaining = max(0, Monitor.manual_check_cooldown() - diff)

    if remaining > 0 and connected?(socket) do
      Process.send_after(self(), :tick, 1000)
    end

    assign(socket, :cooldown_remaining, remaining)
  end

  defp hydrate_virtual_array_fields(%Monitor{} = monitor) do
    %{
      monitor
      | raw_keyword_positive: Enum.join(monitor.keyword_positive || [], ", "),
        raw_keyword_negative: Enum.join(monitor.keyword_negative || [], ", ")
    }
  end

  defp trigger_manual_check(socket) do
    case Monitoring.mark_manual_check_triggered(socket.assigns.monitor) do
      {:ok, updated_monitor} ->
        Monitoring.enqueue_checks(updated_monitor)

        {:noreply,
         socket
         |> assign(:monitor, hydrate_virtual_array_fields(updated_monitor))
         |> assign_cooldown(updated_monitor.last_manual_check_at)}

      {:error, :short_budget_exhausted} ->
        {:noreply,
         put_flash(socket, :error, gettext("Too many checks in the last minute. Please wait."))}

      {:error, :long_budget_exhausted} ->
        {:noreply,
         put_flash(socket, :error, gettext("Hourly check limit reached for this workspace."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to trigger check"))}
    end
  end
end

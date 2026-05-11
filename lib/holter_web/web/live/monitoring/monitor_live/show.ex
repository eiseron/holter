defmodule HolterWeb.Web.Monitoring.MonitorLive.Show do
  use HolterWeb, :monitoring_live_view

  alias Holter.Monitoring
  alias Holter.Monitoring.Models.Monitor
  alias Holter.Repo.Tenant
  alias HolterWeb.LiveView.PubSubSubscriptions

  def incident_type_to_status(:downtime), do: :down
  def incident_type_to_status(:defacement), do: :compromised
  def incident_type_to_status(:ssl_expiry), do: :degraded
  def incident_type_to_status(:domain_expiry), do: :degraded
  def incident_type_to_status(_), do: :unknown

  @impl true
  def mount(_params, _session, socket) do
    monitor = socket.assigns.current_monitor
    workspace = socket.assigns.current_workspace
    PubSubSubscriptions.subscribe_to_monitor(socket, monitor.id)
    hydrated_monitor = hydrate_virtual_array_fields(monitor)

    changeset = Monitoring.change_monitor(hydrated_monitor)

    socket =
      socket
      |> assign(:workspace, workspace)
      |> assign(:monitor, hydrated_monitor)
      |> assign(:chart_logs, Monitoring.list_recent_logs_for_chart(monitor.id))
      |> assign(:active_incidents, Monitoring.list_open_incidents(monitor.id))
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
    actor = socket.assigns.current_user
    monitor = socket.assigns.monitor

    with :ok <- authorize(actor, :update, monitor),
         {:ok, updated} <- Monitoring.update_monitor(actor, monitor, monitor_params) do
      hydrated_monitor = hydrate_virtual_array_fields(updated)

      {:noreply,
       socket
       |> put_flash(:info, gettext("Monitor updated successfully"))
       |> assign(:monitor, hydrated_monitor)
       |> assign(:form, to_form(Monitoring.change_monitor(hydrated_monitor)))}
    else
      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("You are not allowed to update this monitor."))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    actor = socket.assigns.current_user
    monitor = socket.assigns.monitor

    with :ok <- authorize(actor, :delete, monitor),
         {:ok, _} <- Monitoring.delete_monitor(actor, monitor) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Monitor deleted successfully"))
       |> push_navigate(to: "/")}
    else
      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("You are not allowed to delete this monitor."))}
    end
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
    workspace = socket.assigns.workspace

    monitor =
      Tenant.with_workspace!(workspace.id, fn ->
        Monitoring.get_monitor!(socket.assigns.current_user, socket.assigns.monitor.id)
      end)

    hydrated_monitor = hydrate_virtual_array_fields(monitor)

    {:noreply,
     socket
     |> assign(:monitor, hydrated_monitor)
     |> assign(:chart_logs, Monitoring.list_recent_logs_for_chart(monitor.id))
     |> assign(:active_incidents, Monitoring.list_open_incidents(monitor.id))
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

    already_ticking = Map.get(socket.assigns, :cooldown_remaining, 0) > 0

    if remaining > 0 and not already_ticking and connected?(socket) do
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
    actor = socket.assigns.current_user
    monitor = socket.assigns.monitor

    with :ok <- authorize(actor, :run_now, monitor),
         {:ok, updated_monitor} <- Monitoring.mark_manual_check_triggered(actor, monitor) do
      Monitoring.enqueue_checks(actor, updated_monitor)

      {:noreply,
       socket
       |> assign(:monitor, hydrate_virtual_array_fields(updated_monitor))
       |> assign_cooldown(updated_monitor.last_manual_check_at)}
    else
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext("You are not allowed to run this monitor."))}

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

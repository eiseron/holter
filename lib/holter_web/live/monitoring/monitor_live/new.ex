defmodule HolterWeb.Monitoring.MonitorLive.New do
  use HolterWeb, :live_view

  alias Holter.Monitoring
  alias Holter.Monitoring.Monitor

  @impl true
  def mount(%{"org_slug" => slug}, _session, socket) do
    case Monitoring.get_organization_by_slug(slug) do
      {:ok, org} ->
        changeset = Monitoring.change_monitor(%Monitor{organization_id: org.id})

        {:ok,
         socket
         |> assign(:org, org)
         |> assign(:form, to_form(changeset))}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Organization not found")
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
    params = Map.put(monitor_params, "organization_id", socket.assigns.org.id)

    case Monitoring.create_monitor(params) do
      {:ok, _monitor} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Monitor created successfully"))
         |> push_navigate(to: ~p"/orgs/#{socket.assigns.org.slug}/monitoring/dashboard")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

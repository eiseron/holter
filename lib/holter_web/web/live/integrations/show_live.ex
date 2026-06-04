defmodule HolterWeb.Web.Integrations.ShowLive do
  use HolterWeb, :workspace_live_view

  import HolterWeb.Components.Integrations.IntegrationStatusBadge
  import HolterWeb.Components.Integrations.IntegrationSubnav

  alias Holter.Integrations.IntegrationRulesContext
  alias Holter.Integrations.Models.IntegrationRule
  alias Holter.Integrations.Provider
  alias Holter.Monitoring

  @event_type_labels %{
    "incident_opened" => gettext_noop("When an incident is opened"),
    "incident_resolved" => gettext_noop("When an incident is resolved"),
    "monitor_paused" => gettext_noop("When the monitor is paused"),
    "monitor_resumed" => gettext_noop("When the monitor is resumed")
  }

  @impl true
  def mount(%{"id" => _id}, _session, socket) do
    integration = socket.assigns.current_integration
    workspace = socket.assigns.current_workspace

    rules = IntegrationRulesContext.list_for_integration(integration.id)
    monitors = Monitoring.list_monitors_by_workspace(workspace.id)
    actions = resolve_supported_actions(integration.provider)

    {:ok,
     socket
     |> assign(:page_title, provider_display_name(integration.provider))
     |> assign(:integration, integration)
     |> assign(:workspace, workspace)
     |> assign(:rules, rules)
     |> assign(:monitors, monitors)
     |> assign(:event_type_options, IntegrationRule.event_types())
     |> assign(:action_options, actions)
     |> assign(:pending_delete_rule_id, nil)}
  end

  @impl true
  def handle_event("ask_delete_rule", %{"id" => id}, socket) do
    {:noreply, assign(socket, :pending_delete_rule_id, id)}
  end

  @impl true
  def handle_event("cancel_delete_rule", _params, socket) do
    {:noreply, assign(socket, :pending_delete_rule_id, nil)}
  end

  @impl true
  def handle_event("create_rule", %{"rule" => params}, socket) do
    integration = socket.assigns.integration
    actor = socket.assigns.current_user

    attrs = Map.put(params, "integration_id", integration.id)

    with :ok <- authorize(actor, :update, integration),
         {:ok, _rule} <- IntegrationRulesContext.create(attrs) do
      rules = IntegrationRulesContext.list_for_integration(integration.id)

      {:noreply,
       socket
       |> put_flash(:info, gettext("Rule added"))
       |> assign(:rules, rules)}
    else
      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, gettext("You are not allowed to update this integration."))}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, gettext("Could not add rule. Check the fields."))}
    end
  end

  @impl true
  def handle_event("delete_rule", %{"id" => id}, socket) do
    integration = socket.assigns.integration
    actor = socket.assigns.current_user

    with :ok <- authorize(actor, :update, integration),
         {:ok, rule} <- IntegrationRulesContext.get(id),
         :ok <- check_rule_belongs_to_integration(rule, integration),
         {:ok, _} <- IntegrationRulesContext.delete(rule) do
      rules = IntegrationRulesContext.list_for_integration(integration.id)

      {:noreply,
       socket
       |> put_flash(:info, gettext("Rule removed"))
       |> assign(:rules, rules)
       |> assign(:pending_delete_rule_id, nil)}
    else
      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, gettext("You are not allowed to update this integration."))
         |> assign(:pending_delete_rule_id, nil)}

      _ ->
        {:noreply,
         put_flash(socket, :error, gettext("Could not remove rule."))
         |> assign(:pending_delete_rule_id, nil)}
    end
  end

  defp check_rule_belongs_to_integration(rule, integration) do
    if rule.integration_id == integration.id, do: :ok, else: {:error, :forbidden}
  end

  defp resolve_supported_actions(provider) do
    case Provider.provider_module(provider) do
      {:ok, mod} -> Enum.map(mod.supported_actions(), &Atom.to_string/1)
      {:error, :not_implemented} -> []
    end
  end

  defp action_label(provider, action) when is_binary(action) do
    {:ok, mod} = Provider.provider_module(provider)
    mod.action_label(String.to_existing_atom(action))
  end

  defp event_type_label(event) do
    Gettext.gettext(HolterWeb.Gettext, Map.fetch!(@event_type_labels, event))
  end

  defp provider_display_name(provider) do
    provider
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp monitor_name(monitors, monitor_id) do
    case Enum.find(monitors, &(&1.id == monitor_id)) do
      %{url: url} -> url
      _ -> gettext("(removed monitor)")
    end
  end
end

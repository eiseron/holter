defmodule HolterWeb.Web.Workspaces.ShowLive do
  @moduledoc """
  Workspace settings page at `/workspaces/:workspace_slug`. Top-level
  workspace resource page — not nested under any feature context (the
  workspace itself spans Identity, Monitoring and Delivery). Admin-gated
  via `:require_workspace_admin`. Exposes:

    * `default_locale` — editable.
    * `max_monitors`, `max_channels` — read-only. Plan limits are set by
      Eiseron internal admin tooling, not by workspace admins.
  """

  use HolterWeb, :workspace_live_view

  import Ecto.Query
  import HolterWeb.Components.QuotaGauge

  alias Holter.Delivery
  alias Holter.I18n.Locale
  alias Holter.Monitoring
  alias Holter.Monitoring.Models.Monitor
  alias Holter.Repo

  def locale_options do
    [
      {gettext("Portuguese (Brazil)"), "pt_BR"},
      {gettext("English"), "en"}
    ]
  end

  @impl true
  def mount(_params, _session, socket) do
    workspace = socket.assigns.current_workspace
    monitoring_profile = Monitoring.get_workspace_profile!(workspace.id)
    delivery_profile = Delivery.get_workspace_profile!(workspace.id)
    monitor_count = active_monitor_count(workspace.id)
    channel_count = Delivery.count_channels(workspace.id)

    {:ok,
     socket
     |> assign(:page_title, gettext("Workspace"))
     |> assign(:workspace, workspace)
     |> assign(:monitoring_profile, monitoring_profile)
     |> assign(:delivery_profile, delivery_profile)
     |> assign(:monitor_count, monitor_count)
     |> assign(:channel_count, channel_count)
     |> assign(:form, build_form(workspace))}
  end

  @impl true
  def handle_event("save", %{"workspace" => attrs}, socket) do
    actor = socket.assigns.current_user
    workspace = socket.assigns.current_workspace
    safe_attrs = Map.take(attrs, ["default_locale"])

    with :ok <- authorize(actor, :update, workspace),
         {:ok, updated_ws} <- Monitoring.update_workspace(workspace, safe_attrs) do
      handle_save_result({:ok, updated_ws}, socket)
    else
      {:error, :unauthorized} -> reply_unauthorized(socket)
      {:error, %Ecto.Changeset{} = changeset} -> handle_save_result({:error, changeset}, socket)
    end
  end

  defp handle_save_result({:ok, updated_ws}, socket) do
    Gettext.put_locale(HolterWeb.Gettext, effective_locale(socket, updated_ws))

    {:noreply,
     socket
     |> put_flash(:info, gettext("Saved."))
     |> push_navigate(to: ~p"/identity/workspaces/#{updated_ws.slug}", replace: true)}
  end

  defp handle_save_result({:error, changeset}, socket) do
    {:noreply, assign(socket, :form, to_form(changeset, as: "workspace"))}
  end

  defp reply_unauthorized(socket) do
    {:noreply,
     put_flash(socket, :error, gettext("You are not allowed to update this workspace."))}
  end

  defp build_form(workspace) do
    to_form(%{"default_locale" => workspace.default_locale}, as: "workspace")
  end

  defp effective_locale(socket, workspace) do
    case socket.assigns.current_user do
      %{preferred_locale: locale} when is_binary(locale) -> locale
      _ -> workspace.default_locale || Locale.default()
    end
  end

  defp active_monitor_count(workspace_id) do
    from(m in Monitor,
      where: m.workspace_id == ^workspace_id and m.logical_state != :archived
    )
    |> Repo.aggregate(:count, :id)
  end
end

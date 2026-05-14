defmodule HolterWeb.Components.AdminAudit do
  @moduledoc """
  Render helpers for cross-page audit log refs in the admin panel.

  Audit rows reference resources by string (`"User:<uuid>"` or
  `"Workspace:<uuid>"`) and actors by `actor_id` + `actor_type`. These
  components parse those values and render them as links to the matching
  admin detail page, falling back to a plain monospace span when the
  format is unrecognized.
  """

  use Phoenix.Component
  use Gettext, backend: HolterWeb.Gettext
  use HolterWeb, :verified_routes

  attr :value, :string, required: true

  def audit_resource(assigns) do
    assigns = assign(assigns, :parsed, parse_resource(assigns.value))

    ~H"""
    <%= case @parsed do %>
      <% {:user, id} -> %>
        <.link navigate={~p"/admin/users/#{id}"} class="h-font-mono">{@value}</.link>
      <% {:workspace, id} -> %>
        <.link navigate={~p"/admin/workspaces/#{id}"} class="h-font-mono">{@value}</.link>
      <% :unknown -> %>
        <span class="h-font-mono">{@value}</span>
    <% end %>
    """
  end

  attr :actor_id, :string, default: nil
  attr :actor_type, :string, required: true

  def audit_actor(assigns) do
    ~H"""
    <%= cond do %>
      <% @actor_type == "system" -> %>
        <em>{gettext("system")}</em>
      <% is_binary(@actor_id) and @actor_id != "" -> %>
        <.link navigate={~p"/admin/users/#{@actor_id}"} class="h-font-mono">{@actor_id}</.link>
      <% true -> %>
        <span class="h-admin-muted">—</span>
    <% end %>
    """
  end

  defp parse_resource("User:" <> id), do: {:user, id}
  defp parse_resource("Workspace:" <> id), do: {:workspace, id}
  defp parse_resource(_), do: :unknown
end

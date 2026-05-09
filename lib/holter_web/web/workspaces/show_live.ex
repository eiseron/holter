defmodule HolterWeb.Web.Workspaces.ShowLive do
  @moduledoc """
  Workspace settings page at `/workspaces/:workspace_slug`. Top-level
  workspace resource page — not nested under any feature context (the
  workspace itself spans Identity, Monitoring and Delivery). Admin-gated
  via `:require_workspace_admin`. Today exposes a single editable field
  (`default_locale`) under a "General" section.
  """

  use HolterWeb, :workspace_live_view

  alias Holter.I18n.Locale
  alias Holter.Monitoring

  def locale_options do
    [
      {gettext("Portuguese (Brazil)"), "pt_BR"},
      {gettext("English"), "en"}
    ]
  end

  @impl true
  def mount(_params, _session, socket) do
    workspace = socket.assigns.current_workspace

    {:ok,
     socket
     |> assign(:page_title, gettext("Workspace"))
     |> assign(:form, build_form(workspace))
     |> assign(:workspace, workspace)}
  end

  @impl true
  def handle_event("save", %{"workspace" => attrs}, socket) do
    case Monitoring.update_workspace(socket.assigns.current_workspace, attrs) do
      {:ok, workspace} ->
        Gettext.put_locale(HolterWeb.Gettext, effective_locale(socket, workspace))

        {:noreply,
         socket
         |> put_flash(:info, gettext("Saved."))
         |> push_navigate(to: ~p"/workspaces/#{workspace.slug}", replace: true)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "workspace"))}
    end
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
end

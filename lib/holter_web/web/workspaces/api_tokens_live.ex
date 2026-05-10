defmodule HolterWeb.Web.Workspaces.ApiTokensLive do
  use HolterWeb, :workspace_live_view

  alias Holter.Identity.ApiTokens
  alias Holter.Identity.Models.ApiToken
  alias Holter.Identity.Scopes

  def scope_label("read:workspaces"), do: gettext("View workspace")
  def scope_label("read:monitors"), do: gettext("View monitors")
  def scope_label("write:monitors"), do: gettext("Manage monitors")
  def scope_label("read:logs"), do: gettext("View logs")
  def scope_label("read:metrics"), do: gettext("View metrics")
  def scope_label("read:incidents"), do: gettext("View incidents")
  def scope_label("read:channels"), do: gettext("View notification channels")
  def scope_label("write:channels"), do: gettext("Manage notification channels")
  def scope_label("ping:channels"), do: gettext("Send test pings")
  def scope_label("read:delivery_logs"), do: gettext("View delivery history")

  def scope_description("read:workspaces"),
    do: gettext("Read workspace metadata.")

  def scope_description("read:monitors"),
    do: gettext("List monitors and read their current status.")

  def scope_description("write:monitors"),
    do: gettext("Create, update and delete monitors.")

  def scope_description("read:logs"),
    do: gettext("Read raw monitor check logs.")

  def scope_description("read:metrics"),
    do: gettext("Read daily uptime metrics.")

  def scope_description("read:incidents"),
    do: gettext("Read incidents and their timeline.")

  def scope_description("read:channels"),
    do: gettext("Read webhook and email channel configuration.")

  def scope_description("write:channels"),
    do: gettext("Create, update and delete notification channels (and rotate their secrets).")

  def scope_description("ping:channels"),
    do: gettext("Send test deliveries to webhook and email channels.")

  def scope_description("read:delivery_logs"),
    do: gettext("Read channel delivery history.")

  @impl true
  def mount(_params, _session, socket) do
    workspace = socket.assigns.current_workspace
    membership = socket.assigns.current_workspace_membership
    owner? = membership.role == :owner
    tokens = if owner?, do: ApiTokens.list_tokens_for_workspace(workspace), else: []

    {:ok,
     socket
     |> assign(:page_title, gettext("API tokens"))
     |> assign(:workspace, workspace)
     |> assign(:owner?, owner?)
     |> assign(:scopes, Scopes.all())
     |> assign(:new_plaintext, nil)
     |> assign(:form, build_form())
     |> stream(:tokens, tokens)}
  end

  @impl true
  def handle_event("create_token", %{"api_token" => attrs}, socket) do
    user = socket.assigns.current_user
    workspace = socket.assigns.current_workspace

    case ApiTokens.create_token(user, workspace, normalize(attrs)) do
      {:ok, token, plaintext} ->
        {:noreply,
         socket
         |> assign(:new_plaintext, plaintext)
         |> assign(:form, build_form())
         |> stream_insert(:tokens, token, at: 0)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "api_token"))}

      {:error, :forbidden} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Only workspace owners can create API tokens.")
         )}
    end
  end

  def handle_event("dismiss_plaintext", _params, socket) do
    {:noreply, assign(socket, :new_plaintext, nil)}
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    workspace = socket.assigns.current_workspace
    tokens = ApiTokens.list_tokens_for_workspace(workspace)

    case Enum.find(tokens, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      %ApiToken{} = token ->
        {:ok, revoked} = ApiTokens.revoke_token(token)
        {:noreply, stream_insert(socket, :tokens, revoked)}
    end
  end

  defp build_form do
    to_form(%{"name" => "", "scopes" => []}, as: "api_token")
  end

  defp normalize(attrs) do
    %{
      name: attrs["name"] || "",
      scopes: List.wrap(attrs["scopes"]) |> Enum.reject(&(&1 in [nil, ""]))
    }
  end
end

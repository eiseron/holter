defmodule HolterWeb.Web.Identity.UserLive.Show do
  @moduledoc """
  User settings page at `/identity/user/:id`. Mounted under the `:user`
  layout — its own shell, parallel to the workspace shell — so the
  user shows up in a sidebar that lists "My account" plus every
  workspace they belong to. The page itself exposes a single editable
  field (`preferred_locale`) under a "Preferences" section; new fields
  land additively without restructuring the page or the sidebar.
  """

  use HolterWeb, :user_live_view

  alias Holter.I18n.Locale
  alias Holter.Identity

  def locale_options do
    [
      {gettext("Portuguese (Brazil)"), "pt_BR"},
      {gettext("English"), "en"}
    ]
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    memberships = Identity.list_workspace_memberships_for_user(user)

    {:ok,
     socket
     |> assign(:page_title, gettext("My account"))
     |> assign(:memberships, memberships)
     |> assign(:form, build_form(user))}
  end

  @impl true
  def handle_event("save", %{"preferences" => attrs}, socket) do
    case Identity.update_user_preferences(socket.assigns.current_user, attrs) do
      {:ok, user} ->
        Gettext.put_locale(HolterWeb.Gettext, user.preferred_locale || Locale.default())

        {:noreply,
         socket
         |> put_flash(:info, gettext("Saved."))
         |> push_navigate(to: ~p"/identity/user/#{user.id}", replace: true)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "preferences"))}
    end
  end

  defp build_form(user) do
    to_form(%{"preferred_locale" => user.preferred_locale}, as: "preferences")
  end
end

defmodule HolterWeb.Web.Identity.UserRegistrationLive do
  use HolterWeb, :live_view

  alias Holter.Identity

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Sign up"))
     |> assign(:check_errors, false)
     |> assign(:form, blank_form())}
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    case Identity.register_user(prepare_attrs(params)) do
      {:ok, _user, _workspace, _token} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("Check your email to verify your account before signing in.")
         )
         |> push_navigate(to: ~p"/identity/login")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:check_errors, true)
         |> assign(:form, to_form(Map.put(changeset, :action, :insert), as: "user"))}
    end
  end

  defp blank_form do
    to_form(%{"email" => "", "password" => "", "terms_accepted" => false}, as: "user")
  end

  defp prepare_attrs(params) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    accepted? = params["terms_accepted"] in [true, "true", "on"]

    %{
      email: params["email"] || "",
      password: params["password"] || "",
      terms_accepted_at: if(accepted?, do: now, else: nil),
      terms_version: "v1"
    }
  end
end

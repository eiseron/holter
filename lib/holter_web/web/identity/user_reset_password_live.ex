defmodule HolterWeb.Web.Identity.UserResetPasswordLive do
  use HolterWeb, :live_view

  alias Holter.Identity

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Set a new password"))
     |> assign(:token, token)
     |> assign(:form, blank_form())}
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    %{"password" => password, "password_confirmation" => confirmation} = params
    token = socket.assigns.token

    if password == confirmation do
      handle_reset(socket, token, password)
    else
      {:noreply, assign(socket, :form, mismatch_form())}
    end
  end

  defp handle_reset(socket, token, password) do
    case Identity.reset_password(token, password) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("Your password has been updated. Sign in with the new password.")
         )
         |> push_navigate(to: ~p"/identity/login")}

      {:error, :invalid_or_expired} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("This reset link is invalid or has expired."))
         |> push_navigate(to: ~p"/identity/forgot-password")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         assign(socket, :form, to_form(Map.put(changeset, :action, :update), as: "user"))}
    end
  end

  defp blank_form do
    to_form(%{"password" => "", "password_confirmation" => ""}, as: "user")
  end

  defp mismatch_form do
    to_form(%{"password" => "", "password_confirmation" => ""},
      as: "user",
      errors: [password_confirmation: {gettext("does not match"), []}]
    )
  end
end

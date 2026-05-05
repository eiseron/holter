defmodule HolterWeb.Web.Identity.UserForgotPasswordLive do
  use HolterWeb, :live_view

  alias Holter.Identity

  @neutral_flash "If this email exists, you will receive instructions."

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Forgot your password?"))
     |> assign(:form, blank_form())}
  end

  @impl true
  def handle_event("save", %{"user" => %{"email" => email}}, socket) do
    if blank?(email) do
      {:noreply, assign(socket, :form, blank_form_with_required_error())}
    else
      :ok = Identity.request_password_reset(email)

      {:noreply,
       socket
       |> put_flash(:info, gettext(@neutral_flash))
       |> push_navigate(to: ~p"/identity/login")}
    end
  end

  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_), do: true

  defp blank_form do
    to_form(%{"email" => ""}, as: "user")
  end

  defp blank_form_with_required_error do
    to_form(%{"email" => ""}, as: "user", errors: [email: {gettext("can't be blank"), []}])
  end
end

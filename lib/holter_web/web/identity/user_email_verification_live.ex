defmodule HolterWeb.Web.Identity.UserEmailVerificationLive do
  use HolterWeb, :live_view

  alias Holter.Identity

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Identity.verify_email(token) do
      {:ok, _user} ->
        {:ok,
         socket
         |> put_flash(:info, gettext("Your email is verified. You can sign in now."))
         |> push_navigate(to: ~p"/identity/login")}

      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(
           :error,
           gettext("This verification link is invalid or has expired.")
         )
         |> push_navigate(to: ~p"/identity/login")}
    end
  end
end

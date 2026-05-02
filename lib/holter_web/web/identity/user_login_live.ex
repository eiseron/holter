defmodule HolterWeb.Web.Identity.UserLoginLive do
  use HolterWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Sign in"))
     |> assign(:form, to_form(%{"email" => "", "password" => ""}, as: "user"))}
  end
end

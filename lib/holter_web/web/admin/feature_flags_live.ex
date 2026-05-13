defmodule HolterWeb.Web.Admin.FeatureFlagsLive do
  @moduledoc """
  Feature flags admin (BDDs 67-69). Lists every flag with its current
  gate summary and toggles its boolean gate. Backed by FunWithFlags.
  """

  use HolterWeb, :admin_live_view

  alias Holter.System
  alias Holter.System.Admins
  alias Holter.System.FeatureFlags

  def strategy_label(:global), do: gettext("Global")
  def strategy_label(:percentage), do: gettext("Percentage")
  def strategy_label(:list), do: gettext("List")
  def strategy_label(_), do: ""

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Admin · Feature flags"))
     |> assign(:form, to_form(%{}, as: "flag"))
     |> assign_flags()}
  end

  @impl true
  def handle_event("toggle", %{"name" => name}, socket) do
    actor = current_admin!(socket)
    flag = System.get_feature_flag!(String.to_existing_atom(name))
    currently_enabled = FeatureFlags.boolean_enabled?(flag)

    with :ok <- authorize(socket.assigns.current_user, :update, flag),
         {:ok, _updated} <- System.set_feature_flag_enabled(flag, !currently_enabled, actor) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Flag %{name} toggled.", name: name))
       |> assign_flags()}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not toggle flag."))}
    end
  end

  @impl true
  def handle_event("create", %{"flag" => %{"name" => name}}, socket) do
    actor = current_admin!(socket)

    with :ok <- authorize(socket.assigns.current_user, :create, {FunWithFlags.Flag, nil}),
         {:ok, _flag} <- System.create_feature_flag(%{name: name}, actor) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Flag %{name} created.", name: name))
       |> assign(:form, to_form(%{}, as: "flag"))
       |> assign_flags()}
    else
      {:error, :invalid_name} ->
        {:noreply, put_flash(socket, :error, gettext("Invalid flag name."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not create flag."))}
    end
  end

  defp assign_flags(socket), do: assign(socket, :flags, System.list_feature_flags())

  defp current_admin!(socket) do
    Admins.get_by_user_id(socket.assigns.current_user.id)
  end
end

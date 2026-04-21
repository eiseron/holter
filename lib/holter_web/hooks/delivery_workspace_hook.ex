defmodule HolterWeb.Hooks.DeliveryWorkspaceHook do
  @moduledoc false
  import Phoenix.LiveView
  import Phoenix.Component

  alias Holter.Monitoring

  def on_mount(:default, _params, _session, socket) do
    {:cont, attach_hook(socket, :inject_workspace, :handle_params, &resolve/3)}
  end

  defp resolve(params, _uri, socket) do
    socket =
      assign_new(socket, :workspace, fn ->
        case params["workspace_slug"] do
          nil ->
            raise "DeliveryWorkspaceHook: no workspace_slug in params #{inspect(Map.keys(params))}"

          slug ->
            Monitoring.get_workspace_by_slug!(slug)
        end
      end)

    {:cont, socket}
  end
end

defmodule HolterWeb.Hooks.MonitoringWorkspaceHook do
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
        cond do
          monitor = socket.assigns[:monitor] ->
            Monitoring.get_workspace!(monitor.workspace_id)

          slug = params["workspace_slug"] ->
            Monitoring.get_workspace_by_slug!(slug)

          true ->
            raise "MonitoringWorkspaceHook: no workspace resolution path for params #{inspect(Map.keys(params))}"
        end
      end)

    {:cont, socket}
  end
end

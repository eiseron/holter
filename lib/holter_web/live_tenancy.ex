defmodule HolterWeb.LiveTenancy do
  @moduledoc """
  LiveView macro that wraps every callback in the workspace tenant
  context, so RLS policies on indirect-scoped tables (`monitor_logs`,
  `incidents`, `daily_metrics`, etc.) see a stamped
  `app.current_workspace_id` for the whole callback — not just the
  call sites that happen to remember to wrap themselves.

  ## Why a macro and not an `attach_hook`

  Phoenix LiveView's `attach_hook` only observes a callback; it
  cannot wrap it. Wrapping is required because Postgres session
  variables are connection-level, and Ecto checks out a fresh
  connection per `Repo.*` call — stamping at the start of a callback
  on one connection does not bleed into the next call's connection.
  `Holter.Repo.Tenant.with_workspace!/2` uses `Repo.checkout` to hold
  one connection for the lifetime of the wrapped function, which is
  what we need for the var to apply to every query in the callback.

  This macro overrides `mount/3`, `handle_params/3`, `handle_event/3`,
  and `handle_info/2` (only the ones the LiveView actually defines)
  so each one runs inside `with_workspace!` keyed on
  `socket.assigns.current_workspace.id` (or `:workspace`, whichever
  the auth hook set). LiveViews without a workspace assign get a
  no-op pass-through.

  ## Usage

      defmodule HolterWeb.MyLive do
        use Phoenix.LiveView
        use HolterWeb.LiveTenancy
        ...
      end

  Or, more commonly, attach it once in `HolterWeb.monitoring_live_view`
  / `HolterWeb.delivery_live_view` so every workspace-scoped LiveView
  gets the wrap automatically.

  ## LiveComponents are not covered

  This macro only wraps LiveView callbacks. `Phoenix.LiveComponent`
  has its own lifecycle (`update/2`) that runs during the parent's
  render diff — *after* the wrapped callback has returned and the
  `Repo.checkout` has released the connection. Stateful components
  that hit RLS-enforced tables must therefore stamp their own tenant
  in `update/2`:

      def update(assigns, socket) do
        Tenant.with_workspace!(assigns.workspace.id, fn ->
          load_counts(assigns.workspace.id)
        end)
      end
  """

  alias Holter.Repo.Tenant

  @doc false
  def run_with_workspace(socket, fun) do
    case socket.assigns[:current_workspace] || socket.assigns[:workspace] do
      nil -> fun.()
      ws -> Tenant.with_workspace!(ws.id, fun)
    end
  end

  defmacro __using__(_opts) do
    quote do
      @before_compile HolterWeb.LiveTenancy
    end
  end

  defmacro __before_compile__(env) do
    callbacks = [
      {:mount, 3, [quote(do: params), quote(do: session), quote(do: socket)]},
      {:handle_params, 3, [quote(do: params), quote(do: uri), quote(do: socket)]},
      {:handle_event, 3, [quote(do: event), quote(do: params), quote(do: socket)]},
      {:handle_info, 2, [quote(do: msg), quote(do: socket)]}
    ]

    overrides =
      Enum.filter(callbacks, fn {name, arity, _} ->
        Module.defines?(env.module, {name, arity})
      end)

    for {name, arity, args} <- overrides do
      quote do
        defoverridable [{unquote(name), unquote(arity)}]

        def unquote(name)(unquote_splicing(args)) do
          HolterWeb.LiveTenancy.run_with_workspace(socket, fn ->
            super(unquote_splicing(args))
          end)
        end
      end
    end
  end
end

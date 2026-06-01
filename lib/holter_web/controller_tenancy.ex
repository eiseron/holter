defmodule HolterWeb.ControllerTenancy do
  @moduledoc """
  Controller mixin that wraps every action in the workspace tenant
  context. The controller-side mirror of `HolterWeb.LiveTenancy`.

  ## Why a controller mixin and not a Plug

  Postgres session variables are connection-level. Ecto checks out a
  fresh connection per `Repo.*` call — stamping the variable at the
  start of a request via a Plug doesn't survive subsequent queries
  because each call gets a different connection from the pool.
  `Holter.Repo.Tenant.with_workspace!/2` uses `Repo.checkout` to hold
  one connection for the wrapped function.

  Plugs are linear (no continuation), so a Plug can't wrap "the rest
  of the request". Phoenix controllers expose `action/2` (the
  dispatcher to the named action) which `Phoenix.Controller` declares
  as overridable. After the wrap, every query inside the action body
  runs under the tenant.

  ## Usage

      defmodule HolterWeb.Some.Controller do
        use HolterWeb, :controller
        use HolterWeb.ControllerTenancy
        ...
      end

  The workspace is read from `conn.assigns[:current_workspace]`, which
  an upstream plug must assign. When it is missing the macro is a no-op
  pass-through, so the same controller can be reused on routes that do
  not resolve a workspace.
  """

  alias Holter.Repo.Tenant

  @doc false
  def run(conn, fun) do
    case conn.assigns[:current_workspace] do
      nil -> fun.()
      %{id: workspace_id} -> Tenant.with_workspace!(workspace_id, fun)
    end
  end

  defmacro __using__(_opts) do
    quote do
      def action(conn, _opts) do
        HolterWeb.ControllerTenancy.run(conn, fn -> super(conn, conn.params) end)
      end
    end
  end
end

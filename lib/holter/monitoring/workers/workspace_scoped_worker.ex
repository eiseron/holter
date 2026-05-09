defmodule Holter.Monitoring.Workers.WorkspaceScopedWorker do
  @moduledoc """
  Oban worker macro that lifts every `perform/1` clause into the
  workspace tenant context, so RLS policies on workspace-scoped tables
  see a stamped `app.current_workspace_id` for the whole job — not
  just the call sites that happen to remember to wrap themselves.

  Mirrors the `HolterWeb.LiveTenancy` macro on the LiveView side: a
  worker tagged with this macro gets its `perform/1` overridden to
  wrap the body in `Holter.Repo.Tenant.with_workspace!/2` keyed on
  `args["workspace_id"]`.

  ## Why a macro and not a one-off wrap per worker

  Every workspace-scoped worker has the same pre/post: extract the
  workspace id, stamp the tenant for the lifetime of the job, restore
  on exit. Doing that by hand at the top of every `perform/1` clause
  drifts (some workers wrap, some don't — and the ones that don't
  fail silently in production while passing in dev, since the
  superuser sandbox bypasses RLS). Lifting the contract into the
  worker definition itself makes "is this worker tenant-scoped?" a
  property of the module's `use` line, not a discipline you have to
  audit clause-by-clause.

  ## Contract

  Workers MUST include `workspace_id` (string UUID) in their job
  args. Missing it raises `ArgumentError` immediately — failing loud
  is preferable to a job that silently sees no rows under RLS.

  ## Usage

      defmodule MyApp.Worker do
        use Holter.Monitoring.Workers.WorkspaceScopedWorker, queue: :default

        @impl Oban.Worker
        def perform(%Oban.Job{args: %{"id" => id}}) do
          MyContext.do_something(id)
        end
      end

      MyApp.Worker.new(%{"id" => id, "workspace_id" => workspace_id})
      |> Oban.insert()

  Callers must include `workspace_id` in args. Pattern matches in
  `perform/1` clauses can omit it — the macro extracts it from the
  raw `Oban.Job` before delegating to the user clauses.
  """

  alias Holter.Repo.Tenant

  @doc false
  def run(%{"workspace_id" => workspace_id}, fun) when is_binary(workspace_id) do
    Tenant.with_workspace!(workspace_id, fun)
  end

  def run(args, _fun) do
    raise ArgumentError,
          "Holter.Monitoring.Workers.WorkspaceScopedWorker requires \"workspace_id\" in job args; " <>
            "got: #{inspect(args)}"
  end

  defmacro __using__(opts) do
    quote do
      use Oban.Worker, unquote(opts)

      @before_compile Holter.Monitoring.Workers.WorkspaceScopedWorker
    end
  end

  defmacro __before_compile__(_env) do
    module = __MODULE__

    quote do
      defoverridable perform: 1

      def perform(%Oban.Job{args: args} = job) do
        unquote(module).run(args, fn -> super(job) end)
      end
    end
  end
end

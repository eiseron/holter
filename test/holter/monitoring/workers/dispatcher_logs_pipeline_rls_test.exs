defmodule Holter.Monitoring.Workers.DispatcherLogsPipelineRLSTest do
  @moduledoc """
  End-to-end coverage for the periodic check pipeline under the
  `holter_app` Postgres role:

      MonitorDispatcher.perform/1
        ↓ enumerates workspaces (workspaces table is global, no RLS)
        ↓ per workspace, calls Monitoring.list_monitors_for_dispatch/1
            (wrapped in Tenant.with_workspace! → RLS policy resolves)
        ↓ enqueues HTTPCheck.new(%{id, workspace_id})
      HTTPCheck.perform/1
        ↓ Tenant.with_workspace!(workspace_id) wraps the body
        ↓ Monitoring.get_monitor!(id) — RLS resolves under workspace
        ↓ engine writes a monitor_log row

  Without the dispatcher's per-workspace iteration AND the workers'
  `workspace_id` arg + wrapper, no monitor would ever be visible to
  the worker, no check would run, and the user's logs page would stay
  empty (the bug reported on the !43 preview deploy:
  "agora os logs não aparecem no monitor").

  Once `monitor_logs` itself gets RLS (issue #51 indirect-tables MR
  !45), reads of that table also need to happen inside a tenant
  context. This test wraps every assertion that queries `monitor_logs`
  in `Tenant.with_workspace!/2` so it stays correct under both pre-RLS
  and post-RLS states of the table. Forgetting the wrapper would make
  the `Repo` SELECT after `HTTPCheck.perform/1` return zero rows under
  RLS — not because the worker failed to insert, but because the test's
  own SELECT runs without a tenant stamped.
  """

  use Holter.DataCase, async: false
  use Oban.Testing, repo: Holter.Repo

  import Holter.RLSHelpers, only: [setup_app_role: 0]

  alias Holter.Monitoring
  alias Holter.Monitoring.MonitorLog
  alias Holter.Monitoring.Workers.{HTTPCheck, MonitorDispatcher}
  alias Holter.Repo
  alias Holter.Repo.Tenant

  describe "MonitorDispatcher.perform/1 under holter_app role" do
    setup do
      user = user_fixture()
      workspace = workspace_fixture(%{owner: user})

      monitor =
        monitor_fixture(%{
          workspace_id: workspace.id,
          url: "https://dispatcher-target.local",
          interval_seconds: 60,
          last_checked_at: nil
        })

      setup_app_role()

      %{user: user, workspace: workspace, monitor: monitor}
    end

    test "iterates workspaces and enqueues an HTTPCheck job with workspace_id",
         %{monitor: monitor} do
      :ok = MonitorDispatcher.perform(%Oban.Job{})

      assert_enqueued(
        worker: HTTPCheck,
        args: %{"id" => monitor.id, "workspace_id" => monitor.workspace_id}
      )
    end
  end

  describe "HTTPCheck.perform/1 under holter_app role with workspace_id arg" do
    setup do
      user = user_fixture()
      workspace = workspace_fixture(%{owner: user})

      monitor =
        monitor_fixture(%{
          workspace_id: workspace.id,
          url: "https://check-target.local",
          interval_seconds: 60,
          method: :get
        })

      setup_app_role()

      %{user: user, workspace: workspace, monitor: monitor}
    end

    test "resolves the monitor under the policy and creates a monitor_log",
         %{monitor: monitor} do
      Mox.expect(Holter.Monitoring.MonitorClientMock, :request, fn _opts ->
        {:ok, %Req.Response{status: 200, body: "OK"}}
      end)

      job = %Oban.Job{
        args: %{"id" => monitor.id, "workspace_id" => monitor.workspace_id}
      }

      assert :ok = HTTPCheck.perform(job)

      assert Tenant.with_workspace!(monitor.workspace_id, fn ->
               Repo.exists?(from l in MonitorLog, where: l.monitor_id == ^monitor.id)
             end)
    end
  end

  describe "End-to-end log visibility through Monitoring.list_monitor_logs/2" do
    setup do
      user = user_fixture()
      workspace = workspace_fixture(%{owner: user})

      monitor =
        monitor_fixture(%{
          workspace_id: workspace.id,
          url: "https://e2e-target.local",
          interval_seconds: 60,
          method: :get
        })

      Mox.expect(Holter.Monitoring.MonitorClientMock, :request, fn _opts ->
        {:ok, %Req.Response{status: 200, body: "OK"}}
      end)

      setup_app_role()

      :ok =
        HTTPCheck.perform(%Oban.Job{
          args: %{"id" => monitor.id, "workspace_id" => monitor.workspace_id}
        })

      %{user: user, workspace: workspace, monitor: monitor}
    end

    test "the freshly created log shows up in Monitoring.list_monitor_logs/2",
         %{monitor: monitor} do
      filters = %{
        page: 1,
        page_size: 50,
        sort_by: "checked_at",
        sort_dir: "desc",
        timezone: "Etc/UTC"
      }

      %{logs: logs} =
        Tenant.with_workspace!(monitor.workspace_id, fn ->
          Monitoring.list_monitor_logs(monitor, filters)
        end)

      refute Enum.empty?(logs)
    end
  end
end

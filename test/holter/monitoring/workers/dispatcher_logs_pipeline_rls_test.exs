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
  """

  use Holter.DataCase, async: false
  use Oban.Testing, repo: Holter.Repo

  import Holter.RLSHelpers, only: [setup_app_role: 0]

  alias Holter.Monitoring
  alias Holter.Monitoring.MonitorLog
  alias Holter.Monitoring.Workers.{HTTPCheck, MonitorDispatcher}
  alias Holter.Repo

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
      mox_called = :counters.new(1, [])

      Mox.expect(Holter.Monitoring.MonitorClientMock, :request, fn _opts ->
        :counters.add(mox_called, 1, 1)
        {:ok, %Req.Response{status: 200, body: "OK"}}
      end)

      job = %Oban.Job{
        args: %{"id" => monitor.id, "workspace_id" => monitor.workspace_id}
      }

      result = HTTPCheck.perform(job)

      role_after = Repo.query!("SELECT current_role", []).rows |> hd() |> hd()

      ws_after =
        Repo.query!("SELECT current_setting('app.current_workspace_id', true)", []).rows
        |> hd()
        |> hd()

      log_count =
        Repo.aggregate(from(l in MonitorLog, where: l.monitor_id == ^monitor.id), :count, :id)

      total_log_count = Repo.aggregate(MonitorLog, :count, :id)

      mox_count = :counters.get(mox_called, 1)

      diag = %{
        result: result,
        role_after: role_after,
        ws_after: ws_after,
        log_count_for_monitor: log_count,
        total_log_count: total_log_count,
        mox_request_called: mox_count
      }

      assert :ok = result,
             "HTTPCheck.perform should return :ok, got: #{inspect(result)}; diag: #{inspect(diag)}"

      assert mox_count >= 1,
             "Mox MonitorClientMock.request should have been called; diag: #{inspect(diag)}"

      assert Repo.exists?(from l in MonitorLog, where: l.monitor_id == ^monitor.id),
             "Expected monitor_log row for monitor #{monitor.id}; diag: #{inspect(diag)}"
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

      %{logs: logs} = Monitoring.list_monitor_logs(monitor, filters)

      refute Enum.empty?(logs)
    end
  end
end

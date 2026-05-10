defmodule Holter.Security.RlsMonitorsTest do
  use Holter.DataCase, async: false

  alias Holter.Monitoring
  alias Holter.Monitoring.Monitor
  alias Holter.Repo

  setup do
    user = user_fixture()
    workspace_a = workspace_fixture(%{owner: user, name: "Alpha"})
    workspace_b = workspace_fixture(%{owner: user, name: "Beta"})

    monitor_a = monitor_fixture(%{workspace_id: workspace_a.id, url: "https://alpha.example"})
    monitor_b = monitor_fixture(%{workspace_id: workspace_b.id, url: "https://beta.example"})

    %{
      user: user,
      workspace_a: workspace_a,
      workspace_b: workspace_b,
      monitor_a: monitor_a,
      monitor_b: monitor_b
    }
  end

  describe "USING policy (read path, keyed on workspace_id)" do
    test "as holter_app with workspace A set, only A's monitor is visible",
         %{workspace_a: workspace_a, monitor_a: monitor_a} do
      expected = uuid_dump(monitor_a.id)

      result =
        run_as_app(workspace_a.id, fn ->
          %{rows: rows} = Repo.query!("SELECT id FROM monitors", [])
          rows
        end)

      assert {:ok, [[^expected]]} = result
    end

    test "as holter_app with no workspace set, monitors are invisible",
         %{monitor_a: monitor_a} do
      result =
        Repo.transaction(fn ->
          Repo.query!("SET LOCAL ROLE holter_app", [])

          %{rows: rows} =
            Repo.query!("SELECT id FROM monitors WHERE id = $1", [uuid_dump(monitor_a.id)])

          Repo.query!("RESET ROLE", [])
          rows
        end)

      assert {:ok, []} = result
    end

    test "as holter_app with the wrong workspace set, the monitor is invisible",
         %{workspace_b: workspace_b, monitor_a: monitor_a} do
      result =
        run_as_app(workspace_b.id, fn ->
          %{rows: rows} =
            Repo.query!("SELECT id FROM monitors WHERE id = $1", [uuid_dump(monitor_a.id)])

          rows
        end)

      assert {:ok, []} = result
    end
  end

  describe "WITH CHECK policy (write path, keyed on workspace_id)" do
    test "as holter_app, INSERTing a monitor for a different workspace_id raises 42501",
         %{workspace_a: workspace_a, workspace_b: workspace_b} do
      assert_raise Postgrex.Error, ~r/row-level security policy/i, fn ->
        run_as_app!(workspace_a.id, fn ->
          Repo.query!(
            """
            INSERT INTO monitors (id, workspace_id, url, method, interval_seconds, timeout_seconds, logical_state, health_status, inserted_at, updated_at)
            VALUES ($1, $2, 'https://leak.example', 'get', 60, 30, 'active', 'unknown', now(), now())
            """,
            [
              uuid_dump(Ecto.UUID.generate()),
              uuid_dump(workspace_b.id)
            ]
          )
        end)
      end
    end

    test "as holter_app, UPDATEing a monitor to point at a different workspace_id raises 42501",
         %{workspace_a: workspace_a, workspace_b: workspace_b, monitor_a: monitor_a} do
      assert_raise Postgrex.Error, ~r/row-level security policy/i, fn ->
        run_as_app!(workspace_a.id, fn ->
          Repo.query!(
            "UPDATE monitors SET workspace_id = $1 WHERE id = $2",
            [uuid_dump(workspace_b.id), uuid_dump(monitor_a.id)]
          )
        end)
      end
    end

    test "as holter_app, DELETing a monitor in another workspace affects 0 rows",
         %{workspace_a: workspace_a, monitor_b: monitor_b} do
      result =
        run_as_app(workspace_a.id, fn ->
          Repo.query!("DELETE FROM monitors WHERE id = $1", [uuid_dump(monitor_b.id)])
        end)

      assert {:ok, %Postgrex.Result{num_rows: 0}} = result

      assert Repo.get(Monitor, monitor_b.id)
    end
  end

  describe "USING policy (auth-time read keyed on app.current_user_id)" do
    test "as holter_app with the owner's user_id stamped, the monitor is visible",
         %{user: user, monitor_a: monitor_a} do
      expected = uuid_dump(monitor_a.id)

      result =
        run_as_app_with_user(user.id, fn ->
          %{rows: rows} =
            Repo.query!("SELECT id FROM monitors WHERE id = $1", [uuid_dump(monitor_a.id)])

          rows
        end)

      assert {:ok, [[^expected]]} = result
    end

    test "as holter_app with a non-member user_id stamped, the monitor is invisible",
         %{monitor_a: monitor_a} do
      stranger = user_fixture()

      result =
        run_as_app_with_user(stranger.id, fn ->
          %{rows: rows} =
            Repo.query!("SELECT id FROM monitors WHERE id = $1", [uuid_dump(monitor_a.id)])

          rows
        end)

      assert {:ok, []} = result
    end
  end

  describe "Monitors context (with_workspace! wrapper transparently passes through)" do
    test "Monitoring.list_monitors_by_workspace/1 returns the workspace's monitors",
         %{workspace_a: workspace_a, monitor_a: monitor_a} do
      ids =
        :system
        |> Monitoring.list_monitors_by_workspace(workspace_a.id)
        |> Enum.map(& &1.id)

      assert monitor_a.id in ids
    end

    test "Monitoring.count_monitors/1 counts only the requested workspace's monitors",
         %{workspace_a: workspace_a} do
      assert Monitoring.count_monitors(:system, workspace_a.id) == 1
    end

    test "Monitoring.update_monitor/2 stamps workspace before updating",
         %{monitor_a: monitor_a} do
      assert {:ok, updated} =
               Monitoring.update_monitor(:system, monitor_a, %{health_status: :degraded})

      assert updated.health_status == :degraded
    end
  end

  defp run_as_app(workspace_id, fun) do
    Repo.transaction(fn ->
      Repo.query!("SET LOCAL ROLE holter_app", [])
      Repo.query!("SELECT set_config('app.current_workspace_id', $1, true)", [workspace_id])
      result = fun.()
      Repo.query!("RESET ROLE", [])
      result
    end)
  end

  defp run_as_app!(workspace_id, fun) do
    case run_as_app(workspace_id, fun) do
      {:ok, value} -> value
      {:error, reason} -> raise reason
    end
  end

  defp run_as_app_with_user(user_id, fun) do
    Repo.transaction(fn ->
      Repo.query!("SET LOCAL ROLE holter_app", [])
      Repo.query!("SELECT set_config('app.current_user_id', $1, true)", [user_id])
      result = fun.()
      Repo.query!("RESET ROLE", [])
      result
    end)
  end

  defp uuid_dump(uuid) do
    {:ok, raw} = Ecto.UUID.dump(uuid)
    raw
  end
end

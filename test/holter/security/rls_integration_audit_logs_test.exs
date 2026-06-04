defmodule Holter.Security.RlsIntegrationAuditLogsTest do
  @moduledoc """
  Exercises the `integration_audit_logs` tenant-isolation policy under the
  `holter_app` Postgres role with RLS enforced. The default DataCase
  sandbox connects as a superuser that bypasses RLS, so these checks run
  the policy directly to prove that workspace-scoped audit rows are
  isolated on both read (USING) and write (WITH CHECK).
  """

  use Holter.DataCase, async: false

  alias Holter.Repo

  setup do
    user = user_fixture()
    workspace_a = workspace_fixture(%{owner: user, name: "Alpha"})
    workspace_b = workspace_fixture(%{owner: user, name: "Beta"})

    %{workspace_a: workspace_a, workspace_b: workspace_b}
  end

  describe "integration_audit_logs USING (read isolation)" do
    test "a workspace A row is invisible when scoped to workspace B",
         %{workspace_a: workspace_a, workspace_b: workspace_b} do
      id = insert_audit_row!(workspace_a.id)

      result =
        run_as_app(workspace_b.id, fn ->
          %{rows: rows} =
            Repo.query!("SELECT id FROM integration_audit_logs WHERE id = $1", [uuid_dump(id)])

          rows
        end)

      assert {:ok, []} = result
    end

    test "a workspace A row is visible when scoped to workspace A",
         %{workspace_a: workspace_a} do
      id = insert_audit_row!(workspace_a.id)
      expected = uuid_dump(id)

      result =
        run_as_app(workspace_a.id, fn ->
          %{rows: rows} =
            Repo.query!("SELECT id FROM integration_audit_logs WHERE id = $1", [uuid_dump(id)])

          rows
        end)

      assert {:ok, [[^expected]]} = result
    end
  end

  describe "integration_audit_logs WITH CHECK (write isolation)" do
    test "as holter_app, inserting a row for another workspace raises 42501",
         %{workspace_a: workspace_a, workspace_b: workspace_b} do
      assert_raise Postgrex.Error, ~r/row-level security policy/i, fn ->
        run_as_app!(workspace_a.id, fn ->
          insert_audit_sql!(workspace_b.id)
        end)
      end
    end

    test "as holter_app, inserting a row for the stamped workspace succeeds",
         %{workspace_a: workspace_a} do
      result =
        run_as_app(workspace_a.id, fn ->
          insert_audit_sql!(workspace_a.id)
        end)

      assert {:ok, %Postgrex.Result{num_rows: 1}} = result
    end
  end

  defp insert_audit_row!(workspace_id) do
    id = Ecto.UUID.generate()

    Repo.query!(
      """
      INSERT INTO integration_audit_logs
        (id, actor_type, workspace_id, resource, action, diff, occurred_at, inserted_at)
      VALUES ($1, 'system', $2, 'integration:x', 'integrations.connected', '{}', now(), now())
      """,
      [uuid_dump(id), uuid_dump(workspace_id)]
    )

    id
  end

  defp insert_audit_sql!(workspace_id) do
    Repo.query!(
      """
      INSERT INTO integration_audit_logs
        (id, actor_type, workspace_id, resource, action, diff, occurred_at, inserted_at)
      VALUES ($1, 'system', $2, 'integration:x', 'integrations.connected', '{}', now(), now())
      """,
      [uuid_dump(Ecto.UUID.generate()), uuid_dump(workspace_id)]
    )
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

  defp uuid_dump(uuid) do
    {:ok, raw} = Ecto.UUID.dump(uuid)
    raw
  end
end

defmodule Holter.Security.RlsIntegrationsTest do
  use Holter.DataCase, async: false

  alias Holter.Integrations.Models.Integration
  alias Holter.Repo

  setup do
    user = user_fixture()
    workspace_a = workspace_fixture(%{owner: user, name: "Alpha"})
    workspace_b = workspace_fixture(%{owner: user, name: "Beta"})

    integration_a = integration_fixture(%{workspace_id: workspace_a.id, provider: :google_ads})
    integration_b = integration_fixture(%{workspace_id: workspace_b.id, provider: :slack})

    %{
      user: user,
      workspace_a: workspace_a,
      workspace_b: workspace_b,
      integration_a: integration_a,
      integration_b: integration_b
    }
  end

  describe "integrations USING (workspace_id key)" do
    test "as holter_app with workspace A set, only A's integration is visible",
         %{workspace_a: workspace_a, integration_a: integration_a} do
      expected = uuid_dump(integration_a.id)

      result =
        run_as_app(workspace_a.id, fn ->
          %{rows: rows} = Repo.query!("SELECT id FROM integrations", [])
          rows
        end)

      assert {:ok, [[^expected]]} = result
    end

    test "as holter_app with workspace B set, workspace A integration is invisible",
         %{workspace_b: workspace_b, integration_a: integration_a} do
      result =
        run_as_app(workspace_b.id, fn ->
          %{rows: rows} =
            Repo.query!("SELECT id FROM integrations WHERE id = $1", [
              uuid_dump(integration_a.id)
            ])

          rows
        end)

      assert {:ok, []} = result
    end

    test "as holter_app with matching user_id, the integration is visible via membership branch",
         %{user: user, integration_a: integration_a} do
      expected = uuid_dump(integration_a.id)

      result =
        Repo.transaction(fn ->
          Repo.query!("SET LOCAL ROLE holter_app", [])
          Repo.query!("SELECT set_config('app.current_user_id', $1, true)", [user.id])

          %{rows: rows} =
            Repo.query!("SELECT id FROM integrations WHERE id = $1", [
              uuid_dump(integration_a.id)
            ])

          Repo.query!("RESET ROLE", [])
          rows
        end)

      assert {:ok, [[^expected]]} = result
    end
  end

  describe "integrations WITH CHECK (write path)" do
    test "as holter_app, INSERTing an integration for another workspace raises 42501",
         %{workspace_a: workspace_a, workspace_b: workspace_b} do
      assert_raise Postgrex.Error, ~r/row-level security policy/i, fn ->
        run_as_app!(workspace_a.id, fn ->
          Repo.query!(
            """
            INSERT INTO integrations
              (id, workspace_id, provider, status, settings, inserted_at, updated_at)
            VALUES ($1, $2, 'slack', 'active', '{}', now(), now())
            """,
            [
              uuid_dump(Ecto.UUID.generate()),
              uuid_dump(workspace_b.id)
            ]
          )
        end)
      end
    end

    test "as holter_app, DELETEing an integration from another workspace affects 0 rows",
         %{workspace_a: workspace_a, integration_b: integration_b} do
      result =
        run_as_app(workspace_a.id, fn ->
          Repo.query!("DELETE FROM integrations WHERE id = $1", [uuid_dump(integration_b.id)])
        end)

      assert {:ok, %Postgrex.Result{num_rows: 0}} = result
      assert Repo.get(Integration, integration_b.id)
    end
  end

  describe "integration_events (anchored on integrations.workspace_id)" do
    test "as holter_app with workspace A set, only A's events are visible",
         %{workspace_a: workspace_a, integration_a: integration_a} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      event_a = integration_event_fixture(integration: integration_a, occurred_at: now)
      expected = uuid_dump(event_a.id)

      result =
        run_as_app(workspace_a.id, fn ->
          %{rows: rows} = Repo.query!("SELECT id FROM integration_events", [])
          rows
        end)

      assert {:ok, [[^expected]]} = result
    end

    test "as holter_app with workspace B set, workspace A events are invisible",
         %{workspace_a: workspace_a, workspace_b: workspace_b, integration_a: integration_a} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      event_a = integration_event_fixture(integration: integration_a, occurred_at: now)

      result =
        run_as_app(workspace_b.id, fn ->
          %{rows: rows} =
            Repo.query!("SELECT id FROM integration_events WHERE id = $1", [
              uuid_dump(event_a.id)
            ])

          rows
        end)

      assert {:ok, []} = result

      _ = workspace_a
    end

    test "as holter_app, INSERTing an event for an integration in another workspace raises 42501",
         %{workspace_a: workspace_a, integration_b: integration_b} do
      assert_raise Postgrex.Error, ~r/row-level security policy/i, fn ->
        run_as_app!(workspace_a.id, fn ->
          Repo.query!(
            """
            INSERT INTO integration_events
              (id, integration_id, direction, action, status, occurred_at, inserted_at)
            VALUES ($1, $2, 'outbound', 'pause_campaign', 'success', now(), now())
            """,
            [
              uuid_dump(Ecto.UUID.generate()),
              uuid_dump(integration_b.id)
            ]
          )
        end)
      end
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

  defp uuid_dump(uuid) do
    {:ok, raw} = Ecto.UUID.dump(uuid)
    raw
  end
end

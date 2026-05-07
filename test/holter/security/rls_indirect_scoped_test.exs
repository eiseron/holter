defmodule Holter.Security.RlsIndirectScopedTest do
  use Holter.DataCase, async: false

  alias Holter.Delivery.WebhookChannels
  alias Holter.Repo

  setup do
    user = user_fixture()
    workspace_a = workspace_fixture(%{owner: user, name: "Alpha"})
    workspace_b = workspace_fixture(%{owner: user, name: "Beta"})

    monitor_a = monitor_fixture(%{workspace_id: workspace_a.id, url: "https://alpha.example"})
    monitor_b = monitor_fixture(%{workspace_id: workspace_b.id, url: "https://beta.example"})

    incident_a = incident_fixture(%{monitor_id: monitor_a.id})
    incident_b = incident_fixture(%{monitor_id: monitor_b.id})

    log_a = log_fixture(%{monitor_id: monitor_a.id})
    log_b = log_fixture(%{monitor_id: monitor_b.id})

    metric_a = daily_metric_fixture(%{monitor_id: monitor_a.id})

    metric_b =
      daily_metric_fixture(%{monitor_id: monitor_b.id, date: Date.add(Date.utc_today(), -1)})

    {:ok, channel_a} =
      WebhookChannels.create(%{
        workspace_id: workspace_a.id,
        name: "Alpha hook",
        url: "https://alpha.example/hook"
      })

    {:ok, channel_b} =
      WebhookChannels.create(%{
        workspace_id: workspace_b.id,
        name: "Beta hook",
        url: "https://beta.example/hook"
      })

    {:ok, _} = WebhookChannels.link_monitor(monitor_a.id, channel_a.id)
    {:ok, _} = WebhookChannels.link_monitor(monitor_b.id, channel_b.id)

    %{
      workspace_a: workspace_a,
      workspace_b: workspace_b,
      monitor_a: monitor_a,
      monitor_b: monitor_b,
      incident_a: incident_a,
      incident_b: incident_b,
      log_a: log_a,
      log_b: log_b,
      metric_a: metric_a,
      metric_b: metric_b,
      channel_a: channel_a,
      channel_b: channel_b
    }
  end

  describe "incidents (anchored on monitors.workspace_id)" do
    test "as holter_app with workspace A set, only A's incidents are visible",
         %{workspace_a: workspace_a, incident_a: incident_a} do
      expected = uuid_dump(incident_a.id)

      result =
        run_as_app(workspace_a.id, fn ->
          %{rows: rows} = Repo.query!("SELECT id FROM incidents", [])
          rows
        end)

      assert {:ok, [[^expected]]} = result
    end

    test "as holter_app, INSERTing an incident for a monitor in another workspace raises 42501",
         %{workspace_a: workspace_a, monitor_b: monitor_b} do
      assert_raise Postgrex.Error, ~r/row-level security policy/i, fn ->
        run_as_app!(workspace_a.id, fn ->
          Repo.query!(
            """
            INSERT INTO incidents (id, monitor_id, type, started_at, monitor_snapshot, inserted_at, updated_at)
            VALUES ($1, $2, 'downtime', now(), '{}', now(), now())
            """,
            [
              uuid_dump(Ecto.UUID.generate()),
              uuid_dump(monitor_b.id)
            ]
          )
        end)
      end
    end
  end

  describe "monitor_logs (anchored on monitors.workspace_id)" do
    test "as holter_app with workspace A set, only A's logs are visible",
         %{workspace_a: workspace_a, log_a: log_a} do
      expected = uuid_dump(log_a.id)

      result =
        run_as_app(workspace_a.id, fn ->
          %{rows: rows} = Repo.query!("SELECT id FROM monitor_logs", [])
          rows
        end)

      assert {:ok, [[^expected]]} = result
    end

    test "as holter_app, INSERTing a log for a monitor in another workspace raises 42501",
         %{workspace_a: workspace_a, monitor_b: monitor_b} do
      assert_raise Postgrex.Error, ~r/row-level security policy/i, fn ->
        run_as_app!(workspace_a.id, fn ->
          Repo.query!(
            """
            INSERT INTO monitor_logs (id, monitor_id, status, checked_at, inserted_at, updated_at)
            VALUES ($1, $2, 'up', now(), now(), now())
            """,
            [
              uuid_dump(Ecto.UUID.generate()),
              uuid_dump(monitor_b.id)
            ]
          )
        end)
      end
    end
  end

  describe "daily_metrics (anchored on monitors.workspace_id)" do
    test "as holter_app with workspace A set, only A's metrics are visible",
         %{workspace_a: workspace_a, metric_a: metric_a} do
      expected = uuid_dump(metric_a.id)

      result =
        run_as_app(workspace_a.id, fn ->
          %{rows: rows} = Repo.query!("SELECT id FROM daily_metrics", [])
          rows
        end)

      assert {:ok, [[^expected]]} = result
    end

    test "as holter_app, UPDATEing a metric to point at a monitor in another workspace raises 42501",
         %{workspace_a: workspace_a, monitor_b: monitor_b, metric_a: metric_a} do
      assert_raise Postgrex.Error, ~r/row-level security policy/i, fn ->
        run_as_app!(workspace_a.id, fn ->
          Repo.query!(
            "UPDATE daily_metrics SET monitor_id = $1 WHERE id = $2",
            [uuid_dump(monitor_b.id), uuid_dump(metric_a.id)]
          )
        end)
      end
    end
  end

  describe "monitor_webhook_channels (both monitor and channel must match workspace)" do
    test "as holter_app with workspace A set, only A's links are visible",
         %{workspace_a: workspace_a, monitor_a: monitor_a, channel_a: channel_a} do
      result =
        run_as_app(workspace_a.id, fn ->
          %{rows: rows} =
            Repo.query!(
              "SELECT monitor_id, webhook_channel_id FROM monitor_webhook_channels",
              []
            )

          rows
        end)

      expected_monitor = uuid_dump(monitor_a.id)
      expected_channel = uuid_dump(channel_a.id)
      assert {:ok, [[^expected_monitor, ^expected_channel]]} = result
    end

    test "as holter_app, INSERTing a link with a monitor from another workspace raises 42501",
         %{workspace_a: workspace_a, monitor_b: monitor_b, channel_a: channel_a} do
      assert_raise Postgrex.Error, ~r/row-level security policy/i, fn ->
        run_as_app!(workspace_a.id, fn ->
          Repo.query!(
            """
            INSERT INTO monitor_webhook_channels (monitor_id, webhook_channel_id, is_active, inserted_at)
            VALUES ($1, $2, true, now())
            """,
            [
              uuid_dump(monitor_b.id),
              uuid_dump(channel_a.id)
            ]
          )
        end)
      end
    end

    test "as holter_app, INSERTing a link with a channel from another workspace raises 42501",
         %{workspace_a: workspace_a, monitor_a: monitor_a, channel_b: channel_b} do
      assert_raise Postgrex.Error, ~r/row-level security policy/i, fn ->
        run_as_app!(workspace_a.id, fn ->
          Repo.query!(
            """
            INSERT INTO monitor_webhook_channels (monitor_id, webhook_channel_id, is_active, inserted_at)
            VALUES ($1, $2, true, now())
            """,
            [
              uuid_dump(monitor_a.id),
              uuid_dump(channel_b.id)
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

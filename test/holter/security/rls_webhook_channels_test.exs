defmodule Holter.Security.RlsWebhookChannelsTest do
  use Holter.DataCase, async: false

  alias Holter.Delivery.WebhookChannel
  alias Holter.Delivery.WebhookChannels
  alias Holter.Repo

  setup do
    user = user_fixture()
    workspace_a = workspace_fixture(%{owner: user, name: "Alpha"})
    workspace_b = workspace_fixture(%{owner: user, name: "Beta"})

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

    %{
      workspace_a: workspace_a,
      workspace_b: workspace_b,
      channel_a: channel_a,
      channel_b: channel_b
    }
  end

  describe "USING policy (read path, keyed on workspace_id)" do
    test "as holter_app with workspace A set, only A's channel is visible",
         %{workspace_a: workspace_a, channel_a: channel_a} do
      expected = uuid_dump(channel_a.id)

      result =
        run_as_app(workspace_a.id, fn ->
          %{rows: rows} = Repo.query!("SELECT id FROM webhook_channels", [])
          rows
        end)

      assert {:ok, [[^expected]]} = result
    end

    test "as holter_app with no workspace set, channels are invisible",
         %{channel_a: channel_a} do
      result =
        Repo.transaction(fn ->
          Repo.query!("SET LOCAL ROLE holter_app", [])

          %{rows: rows} =
            Repo.query!("SELECT id FROM webhook_channels WHERE id = $1", [
              uuid_dump(channel_a.id)
            ])

          Repo.query!("RESET ROLE", [])
          rows
        end)

      assert {:ok, []} = result
    end

    test "as holter_app with the wrong workspace set, the channel is invisible",
         %{workspace_b: workspace_b, channel_a: channel_a} do
      result =
        run_as_app(workspace_b.id, fn ->
          %{rows: rows} =
            Repo.query!("SELECT id FROM webhook_channels WHERE id = $1", [
              uuid_dump(channel_a.id)
            ])

          rows
        end)

      assert {:ok, []} = result
    end
  end

  describe "WITH CHECK policy (write path, keyed on workspace_id)" do
    test "as holter_app, INSERTing a channel for a different workspace_id raises 42501",
         %{workspace_a: workspace_a, workspace_b: workspace_b} do
      assert_raise Postgrex.Error, ~r/row-level security policy/i, fn ->
        run_as_app!(workspace_a.id, fn ->
          Repo.query!(
            """
            INSERT INTO webhook_channels (id, workspace_id, name, url, signing_token, inserted_at, updated_at)
            VALUES ($1, $2, 'Leak', 'https://leak.example/hook', 'tok', now(), now())
            """,
            [
              uuid_dump(Ecto.UUID.generate()),
              uuid_dump(workspace_b.id)
            ]
          )
        end)
      end
    end

    test "as holter_app, UPDATEing a channel to point at a different workspace_id raises 42501",
         %{workspace_a: workspace_a, workspace_b: workspace_b, channel_a: channel_a} do
      assert_raise Postgrex.Error, ~r/row-level security policy/i, fn ->
        run_as_app!(workspace_a.id, fn ->
          Repo.query!(
            "UPDATE webhook_channels SET workspace_id = $1 WHERE id = $2",
            [uuid_dump(workspace_b.id), uuid_dump(channel_a.id)]
          )
        end)
      end
    end

    test "as holter_app, DELETing a channel in another workspace affects 0 rows",
         %{workspace_a: workspace_a, channel_b: channel_b} do
      result =
        run_as_app(workspace_a.id, fn ->
          Repo.query!("DELETE FROM webhook_channels WHERE id = $1", [uuid_dump(channel_b.id)])
        end)

      assert {:ok, %Postgrex.Result{num_rows: 0}} = result

      assert Repo.get(WebhookChannel, channel_b.id)
    end
  end

  describe "WebhookChannels context (with_workspace! wrapper transparently passes through)" do
    test "WebhookChannels.list/1 returns the workspace's channels",
         %{workspace_a: workspace_a, channel_a: channel_a} do
      ids = workspace_a.id |> WebhookChannels.list() |> Enum.map(& &1.id)

      assert channel_a.id in ids
    end

    test "WebhookChannels.count/1 counts only the requested workspace's channels",
         %{workspace_a: workspace_a} do
      assert WebhookChannels.count(workspace_a.id) == 1
    end

    test "WebhookChannels.update/2 stamps workspace before updating",
         %{channel_a: channel_a} do
      assert {:ok, updated} = WebhookChannels.update(channel_a, %{name: "Renamed"})
      assert updated.name == "Renamed"
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

defmodule Holter.Security.RlsEmailChannelsTest do
  use Holter.DataCase, async: false

  alias Holter.Delivery.EmailChannels

  alias Holter.Delivery.Models.EmailChannel
  alias Holter.Repo

  setup do
    user = user_fixture()
    workspace_a = workspace_fixture(%{owner: user, name: "Alpha"})
    workspace_b = workspace_fixture(%{owner: user, name: "Beta"})

    monitor_a = monitor_fixture(%{workspace_id: workspace_a.id, url: "https://alpha.example"})
    monitor_b = monitor_fixture(%{workspace_id: workspace_b.id, url: "https://beta.example"})

    {:ok, channel_a} =
      EmailChannels.create(%{workspace_id: workspace_a.id, name: "Alpha email"})

    {:ok, channel_b} =
      EmailChannels.create(%{workspace_id: workspace_b.id, name: "Beta email"})

    {:ok, recipient_a} = EmailChannels.add_recipient(channel_a.id, "alice@alpha.example")
    {:ok, recipient_b} = EmailChannels.add_recipient(channel_b.id, "bob@beta.example")

    {:ok, _} = EmailChannels.link_monitor(monitor_a.id, channel_a.id)
    {:ok, _} = EmailChannels.link_monitor(monitor_b.id, channel_b.id)

    %{
      user: user,
      workspace_a: workspace_a,
      workspace_b: workspace_b,
      monitor_a: monitor_a,
      monitor_b: monitor_b,
      channel_a: channel_a,
      channel_b: channel_b,
      recipient_a: recipient_a,
      recipient_b: recipient_b
    }
  end

  describe "email_channels USING (workspace_id key)" do
    test "as holter_app with workspace A set, only A's channel is visible",
         %{workspace_a: workspace_a, channel_a: channel_a} do
      expected = uuid_dump(channel_a.id)

      result =
        run_as_app(workspace_a.id, fn ->
          %{rows: rows} = Repo.query!("SELECT id FROM email_channels", [])
          rows
        end)

      assert {:ok, [[^expected]]} = result
    end

    test "as holter_app with the wrong workspace set, the channel is invisible",
         %{workspace_b: workspace_b, channel_a: channel_a} do
      result =
        run_as_app(workspace_b.id, fn ->
          %{rows: rows} =
            Repo.query!("SELECT id FROM email_channels WHERE id = $1", [
              uuid_dump(channel_a.id)
            ])

          rows
        end)

      assert {:ok, []} = result
    end

    test "as holter_app with no workspace set but matching user_id, the channel is visible via membership branch",
         %{user: user, channel_a: channel_a} do
      expected = uuid_dump(channel_a.id)

      result =
        Repo.transaction(fn ->
          Repo.query!("SET LOCAL ROLE holter_app", [])
          Repo.query!("SELECT set_config('app.current_user_id', $1, true)", [user.id])

          %{rows: rows} =
            Repo.query!("SELECT id FROM email_channels WHERE id = $1", [
              uuid_dump(channel_a.id)
            ])

          Repo.query!("RESET ROLE", [])
          rows
        end)

      assert {:ok, [[^expected]]} = result
    end
  end

  describe "email_channels WITH CHECK (write path)" do
    test "as holter_app, INSERTing a channel for a different workspace_id raises 42501",
         %{workspace_a: workspace_a, workspace_b: workspace_b} do
      assert_raise Postgrex.Error, ~r/row-level security policy/i, fn ->
        run_as_app!(workspace_a.id, fn ->
          Repo.query!(
            """
            INSERT INTO email_channels
              (id, workspace_id, name, anti_phishing_code, settings, inserted_at, updated_at)
            VALUES ($1, $2, 'Leak', 'AAAA-BBBB', '{}', now(), now())
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
            "UPDATE email_channels SET workspace_id = $1 WHERE id = $2",
            [uuid_dump(workspace_b.id), uuid_dump(channel_a.id)]
          )
        end)
      end
    end

    test "as holter_app, DELETing a channel in another workspace affects 0 rows",
         %{workspace_a: workspace_a, channel_b: channel_b} do
      result =
        run_as_app(workspace_a.id, fn ->
          Repo.query!("DELETE FROM email_channels WHERE id = $1", [uuid_dump(channel_b.id)])
        end)

      assert {:ok, %Postgrex.Result{num_rows: 0}} = result
      assert Repo.get(EmailChannel, channel_b.id)
    end
  end

  describe "email_channel_recipients (anchored on email_channels.workspace_id)" do
    test "as holter_app with workspace A set, only A's recipients are visible",
         %{workspace_a: workspace_a, recipient_a: recipient_a} do
      expected = uuid_dump(recipient_a.id)

      result =
        run_as_app(workspace_a.id, fn ->
          %{rows: rows} = Repo.query!("SELECT id FROM email_channel_recipients", [])
          rows
        end)

      assert {:ok, [[^expected]]} = result
    end

    test "as holter_app, INSERTing a recipient against a channel from another workspace raises 42501",
         %{workspace_a: workspace_a, channel_b: channel_b} do
      assert_raise Postgrex.Error, ~r/row-level security policy/i, fn ->
        run_as_app!(workspace_a.id, fn ->
          Repo.query!(
            """
            INSERT INTO email_channel_recipients
              (id, email_channel_id, email, token, inserted_at, updated_at)
            VALUES ($1, $2, 'leak@example.com', 'tok', now(), now())
            """,
            [
              uuid_dump(Ecto.UUID.generate()),
              uuid_dump(channel_b.id)
            ]
          )
        end)
      end
    end

    test "as holter_app with no workspace set but matching user_id, the recipient is visible via membership branch",
         %{user: user, recipient_a: recipient_a} do
      expected = uuid_dump(recipient_a.id)

      result =
        Repo.transaction(fn ->
          Repo.query!("SET LOCAL ROLE holter_app", [])
          Repo.query!("SELECT set_config('app.current_user_id', $1, true)", [user.id])

          %{rows: rows} =
            Repo.query!("SELECT id FROM email_channel_recipients WHERE id = $1", [
              uuid_dump(recipient_a.id)
            ])

          Repo.query!("RESET ROLE", [])
          rows
        end)

      assert {:ok, [[^expected]]} = result
    end
  end

  describe "monitor_email_channels (both monitor and channel must match workspace)" do
    test "as holter_app with workspace A set, only A's links are visible",
         %{workspace_a: workspace_a, monitor_a: monitor_a, channel_a: channel_a} do
      result =
        run_as_app(workspace_a.id, fn ->
          %{rows: rows} =
            Repo.query!(
              "SELECT monitor_id, email_channel_id FROM monitor_email_channels",
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
            INSERT INTO monitor_email_channels (monitor_id, email_channel_id, is_active, inserted_at)
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
            INSERT INTO monitor_email_channels (monitor_id, email_channel_id, is_active, inserted_at)
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

    test "as holter_app with no workspace set but matching user_id, the link is visible via membership branch",
         %{user: user, monitor_a: monitor_a, channel_a: channel_a} do
      expected_monitor = uuid_dump(monitor_a.id)
      expected_channel = uuid_dump(channel_a.id)

      result =
        Repo.transaction(fn ->
          Repo.query!("SET LOCAL ROLE holter_app", [])
          Repo.query!("SELECT set_config('app.current_user_id', $1, true)", [user.id])

          %{rows: rows} =
            Repo.query!(
              """
              SELECT monitor_id, email_channel_id FROM monitor_email_channels
              WHERE monitor_id = $1 AND email_channel_id = $2
              """,
              [uuid_dump(monitor_a.id), uuid_dump(channel_a.id)]
            )

          Repo.query!("RESET ROLE", [])
          rows
        end)

      assert {:ok, [[^expected_monitor, ^expected_channel]]} = result
    end
  end

  describe "EmailChannels context (with_workspace! wrapper transparently passes through)" do
    test "EmailChannels.list/1 returns the workspace's channels",
         %{workspace_a: workspace_a, channel_a: channel_a} do
      ids = workspace_a.id |> EmailChannels.list() |> Enum.map(& &1.id)

      assert channel_a.id in ids
    end

    test "EmailChannels.count/1 counts only the requested workspace's channels",
         %{workspace_a: workspace_a} do
      assert EmailChannels.count(workspace_a.id) == 1
    end

    test "EmailChannels.update/2 stamps workspace before updating",
         %{channel_a: channel_a} do
      assert {:ok, updated} = EmailChannels.update(channel_a, %{name: "Renamed"})
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

defmodule Holter.Delivery.ChannelLogsTest do
  use Holter.DataCase, async: true

  alias Holter.Delivery
  alias Holter.Delivery.ChannelLogs

  defp channel_fixture(workspace_id, overrides \\ %{}) do
    {:ok, channel} =
      Delivery.create_channel(
        Map.merge(
          %{
            workspace_id: workspace_id,
            name: "Test Channel",
            type: :webhook,
            target: "https://example.com/hook"
          },
          overrides
        )
      )

    channel
  end

  defp channel_log_fixture(channel_id, attrs \\ %{}) do
    {:ok, log} =
      ChannelLogs.create_channel_log(
        Map.merge(
          %{
            notification_channel_id: channel_id,
            status: :success,
            event_type: "down",
            dispatched_at: DateTime.utc_now()
          },
          attrs
        )
      )

    log
  end

  setup do
    ws = workspace_fixture()
    channel = channel_fixture(ws.id)
    %{channel: channel}
  end

  describe "list_channel_logs/2 — pagination" do
    test "returns page 1 by default", %{channel: channel} do
      channel_log_fixture(channel.id)
      result = ChannelLogs.list_channel_logs(channel, %{})
      assert result.page_number == 1
    end

    test "total_pages is 1 when logs fit in one page", %{channel: channel} do
      channel_log_fixture(channel.id)
      result = ChannelLogs.list_channel_logs(channel, %{page_size: 50})
      assert result.total_pages == 1
    end

    test "clamps page to 1 when requested page is 0", %{channel: channel} do
      channel_log_fixture(channel.id)
      result = ChannelLogs.list_channel_logs(channel, %{page: 0})
      assert result.page_number == 1
    end

    test "clamps page to total_pages when requested page exceeds total", %{channel: channel} do
      channel_log_fixture(channel.id)
      result = ChannelLogs.list_channel_logs(channel, %{page: 9999, page_size: 50})
      assert result.page_number == result.total_pages
    end

    test "respects page_size", %{channel: channel} do
      for _ <- 1..5, do: channel_log_fixture(channel.id)
      result = ChannelLogs.list_channel_logs(channel, %{page_size: 2})
      assert length(result.logs) == 2
    end

    test "returns empty list when channel has no logs", %{channel: channel} do
      result = ChannelLogs.list_channel_logs(channel, %{})
      assert result.logs == []
    end
  end

  describe "list_channel_logs/2 — status filter" do
    test "returns only logs matching the given status", %{channel: channel} do
      channel_log_fixture(channel.id, %{status: :success})
      channel_log_fixture(channel.id, %{status: :failed})

      result = ChannelLogs.list_channel_logs(channel, %{status: "success"})
      assert Enum.all?(result.logs, &(&1.status == :success))
    end

    test "returns all logs when status filter is nil", %{channel: channel} do
      channel_log_fixture(channel.id, %{status: :success})
      channel_log_fixture(channel.id, %{status: :failed})

      result = ChannelLogs.list_channel_logs(channel, %{status: nil})
      assert length(result.logs) == 2
    end

    test "ignores invalid status and returns all logs", %{channel: channel} do
      channel_log_fixture(channel.id)

      result = ChannelLogs.list_channel_logs(channel, %{status: "unknown_status"})
      assert length(result.logs) == 1
    end

    test "filters for failed logs only", %{channel: channel} do
      channel_log_fixture(channel.id, %{status: :success})
      channel_log_fixture(channel.id, %{status: :failed})

      result = ChannelLogs.list_channel_logs(channel, %{status: "failed"})
      assert Enum.all?(result.logs, &(&1.status == :failed))
    end
  end

  describe "list_channel_logs/2 — date range filter" do
    test "returns only logs on or after start_date", %{channel: channel} do
      channel_log_fixture(channel.id, %{dispatched_at: ~U[2026-01-01 12:00:00.000000Z]})
      channel_log_fixture(channel.id, %{dispatched_at: ~U[2026-01-03 12:00:00.000000Z]})

      result = ChannelLogs.list_channel_logs(channel, %{start_date: "2026-01-02"})
      assert length(result.logs) == 1
      assert List.first(result.logs).dispatched_at == ~U[2026-01-03 12:00:00.000000Z]
    end

    test "returns only logs on or before end_date", %{channel: channel} do
      channel_log_fixture(channel.id, %{dispatched_at: ~U[2026-01-01 12:00:00.000000Z]})
      channel_log_fixture(channel.id, %{dispatched_at: ~U[2026-01-03 12:00:00.000000Z]})

      result = ChannelLogs.list_channel_logs(channel, %{end_date: "2026-01-02"})
      assert length(result.logs) == 1
      assert List.first(result.logs).dispatched_at == ~U[2026-01-01 12:00:00.000000Z]
    end

    test "applies both start_date and end_date when provided", %{channel: channel} do
      channel_log_fixture(channel.id, %{dispatched_at: ~U[2026-01-01 12:00:00.000000Z]})
      channel_log_fixture(channel.id, %{dispatched_at: ~U[2026-01-05 12:00:00.000000Z]})
      channel_log_fixture(channel.id, %{dispatched_at: ~U[2026-01-10 12:00:00.000000Z]})

      result =
        ChannelLogs.list_channel_logs(channel, %{start_date: "2026-01-03", end_date: "2026-01-07"})

      assert length(result.logs) == 1
    end

    test "ignores invalid date and returns all logs", %{channel: channel} do
      channel_log_fixture(channel.id)

      result = ChannelLogs.list_channel_logs(channel, %{start_date: "not-a-date"})
      assert length(result.logs) == 1
    end
  end

  describe "list_channel_logs/2 — sorting" do
    test "sorts by dispatched_at desc by default", %{channel: channel} do
      older = channel_log_fixture(channel.id, %{dispatched_at: ~U[2026-01-01 00:00:00.000000Z]})
      newer = channel_log_fixture(channel.id, %{dispatched_at: ~U[2026-01-10 00:00:00.000000Z]})

      result = ChannelLogs.list_channel_logs(channel, %{})
      assert List.first(result.logs).id == newer.id
      assert List.last(result.logs).id == older.id
    end

    test "sorts by dispatched_at asc when requested", %{channel: channel} do
      older = channel_log_fixture(channel.id, %{dispatched_at: ~U[2026-01-01 00:00:00.000000Z]})
      newer = channel_log_fixture(channel.id, %{dispatched_at: ~U[2026-01-10 00:00:00.000000Z]})

      result =
        ChannelLogs.list_channel_logs(channel, %{sort_by: "dispatched_at", sort_dir: "asc"})

      assert List.first(result.logs).id == older.id
      assert List.last(result.logs).id == newer.id
    end

    test "sorts by status asc when requested", %{channel: channel} do
      channel_log_fixture(channel.id, %{status: :success})
      channel_log_fixture(channel.id, %{status: :failed})

      result = ChannelLogs.list_channel_logs(channel, %{sort_by: "status", sort_dir: "asc"})
      assert List.first(result.logs).status == :failed
    end
  end

  describe "create_channel_log/1" do
    test "creates a log with valid attributes", %{channel: channel} do
      monitor = monitor_fixture()
      incident = incident_fixture(monitor_id: monitor.id)

      assert {:ok, log} =
               ChannelLogs.create_channel_log(%{
                 notification_channel_id: channel.id,
                 status: :success,
                 event_type: "down",
                 monitor_id: monitor.id,
                 incident_id: incident.id,
                 dispatched_at: DateTime.utc_now()
               })

      assert log.status == :success
      assert log.event_type == "down"
      assert log.monitor_id == monitor.id
      assert log.incident_id == incident.id
    end

    test "creates a test log with nil monitor_id and nil incident_id", %{channel: channel} do
      assert {:ok, log} =
               ChannelLogs.create_channel_log(%{
                 notification_channel_id: channel.id,
                 status: :success,
                 event_type: "test",
                 dispatched_at: DateTime.utc_now()
               })

      assert is_nil(log.monitor_id)
      assert is_nil(log.incident_id)
    end

    test "creates a failed log with error_message", %{channel: channel} do
      assert {:ok, log} =
               ChannelLogs.create_channel_log(%{
                 notification_channel_id: channel.id,
                 status: :failed,
                 event_type: "down",
                 error_message: "connection refused",
                 dispatched_at: DateTime.utc_now()
               })

      assert log.status == :failed
      assert log.error_message == "connection refused"
    end

    test "returns error changeset with invalid event_type", %{channel: channel} do
      assert {:error, changeset} =
               ChannelLogs.create_channel_log(%{
                 notification_channel_id: channel.id,
                 status: :success,
                 event_type: "bad_event",
                 dispatched_at: DateTime.utc_now()
               })

      assert "is invalid" in errors_on(changeset).event_type
    end

    test "returns error changeset when notification_channel_id is missing" do
      {:error, changeset} =
        ChannelLogs.create_channel_log(%{
          status: :success,
          event_type: "test",
          dispatched_at: DateTime.utc_now()
        })

      assert "can't be blank" in errors_on(changeset).notification_channel_id
    end
  end

  describe "get_channel_log!/1" do
    test "returns the log by id", %{channel: channel} do
      log = channel_log_fixture(channel.id)
      fetched = ChannelLogs.get_channel_log!(log.id)
      assert fetched.id == log.id
    end

    test "raises Ecto.NoResultsError on unknown id", %{channel: channel} do
      _other = channel_log_fixture(channel.id)

      assert_raise Ecto.NoResultsError, fn ->
        ChannelLogs.get_channel_log!(Ecto.UUID.generate())
      end
    end
  end
end

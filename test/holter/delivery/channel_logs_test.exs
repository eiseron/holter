defmodule Holter.Delivery.ChannelLogsTest do
  use Holter.DataCase, async: true

  alias Holter.Delivery.{ChannelLogs, WebhookChannels}
  alias Holter.Delivery.Workers.WebhookDispatcher

  defp channel_fixture(workspace_id) do
    {:ok, channel} =
      WebhookChannels.create(%{
        workspace_id: workspace_id,
        name: "Test Channel",
        url: "https://example.com/hook"
      })

    channel
  end

  defp job_fixture(channel, overrides \\ %{}) do
    args =
      Map.get(overrides, :args, %{
        "webhook_channel_id" => channel.id,
        "event" => "down",
        "monitor_id" => Ecto.UUID.generate(),
        "incident_id" => Ecto.UUID.generate()
      })

    state = Map.get(overrides, :state, "completed")
    attempted_at = Map.get(overrides, :attempted_at, DateTime.utc_now())

    {:ok, job} = WebhookDispatcher.new(args) |> Holter.Repo.insert()

    Holter.Repo.update!(Ecto.Changeset.change(job, state: state, attempted_at: attempted_at))
  end

  setup do
    ws = workspace_fixture()
    channel = channel_fixture(ws.id)
    %{channel: channel}
  end

  describe "list_channel_logs/2 — pagination" do
    test "returns page 1 by default", %{channel: channel} do
      job_fixture(channel)
      result = ChannelLogs.list_channel_logs(channel, %{})
      assert result.page_number == 1
    end

    test "total_pages is 1 when logs fit in one page", %{channel: channel} do
      job_fixture(channel)
      result = ChannelLogs.list_channel_logs(channel, %{page_size: 50})
      assert result.total_pages == 1
    end

    test "clamps page to 1 when requested page is 0", %{channel: channel} do
      job_fixture(channel)
      result = ChannelLogs.list_channel_logs(channel, %{page: 0})
      assert result.page_number == 1
    end

    test "clamps page to total_pages when requested page exceeds total", %{channel: channel} do
      job_fixture(channel)
      result = ChannelLogs.list_channel_logs(channel, %{page: 9999, page_size: 50})
      assert result.page_number == result.total_pages
    end

    test "respects page_size", %{channel: channel} do
      for _ <- 1..5, do: job_fixture(channel)
      result = ChannelLogs.list_channel_logs(channel, %{page_size: 2})
      assert length(result.logs) == 2
    end

    test "returns empty list when channel has no logs", %{channel: channel} do
      result = ChannelLogs.list_channel_logs(channel, %{})
      assert result.logs == []
    end

    test "excludes jobs from other channels", %{channel: channel} do
      ws = workspace_fixture()
      other_channel = channel_fixture(ws.id)
      job_fixture(channel)
      job_fixture(other_channel)

      result = ChannelLogs.list_channel_logs(channel, %{})
      assert length(result.logs) == 1
    end

    test "excludes in-progress jobs (non-terminal states)", %{channel: channel} do
      {:ok, available_job} =
        WebhookDispatcher.new(%{
          "webhook_channel_id" => channel.id,
          "event" => "down",
          "monitor_id" => Ecto.UUID.generate(),
          "incident_id" => Ecto.UUID.generate()
        })
        |> Holter.Repo.insert()

      assert available_job.state == "available"

      result = ChannelLogs.list_channel_logs(channel, %{})
      assert result.logs == []
    end
  end

  describe "list_channel_logs/2 — status filter" do
    test "returns only completed jobs when status is 'success'", %{channel: channel} do
      job_fixture(channel, %{state: "completed"})
      job_fixture(channel, %{state: "discarded"})

      result = ChannelLogs.list_channel_logs(channel, %{status: "success"})
      assert Enum.all?(result.logs, &(&1.state == "completed"))
    end

    test "returns only non-completed jobs when status is 'failed'", %{channel: channel} do
      job_fixture(channel, %{state: "completed"})
      job_fixture(channel, %{state: "discarded"})

      result = ChannelLogs.list_channel_logs(channel, %{status: "failed"})
      assert Enum.all?(result.logs, &(&1.state != "completed"))
    end

    test "returns all terminal jobs when status is nil", %{channel: channel} do
      job_fixture(channel, %{state: "completed"})
      job_fixture(channel, %{state: "discarded"})

      result = ChannelLogs.list_channel_logs(channel, %{status: nil})
      assert length(result.logs) == 2
    end

    test "ignores unknown status and returns all logs", %{channel: channel} do
      job_fixture(channel)

      result = ChannelLogs.list_channel_logs(channel, %{status: "pending"})
      assert length(result.logs) == 1
    end
  end

  describe "list_channel_logs/2 — date range filter" do
    test "returns only jobs on or after start_date", %{channel: channel} do
      job_fixture(channel, %{attempted_at: ~U[2026-01-01 12:00:00.000000Z]})
      job_fixture(channel, %{attempted_at: ~U[2026-01-03 12:00:00.000000Z]})

      result = ChannelLogs.list_channel_logs(channel, %{start_date: "2026-01-02"})
      assert length(result.logs) == 1
    end

    test "returns only jobs on or before end_date", %{channel: channel} do
      job_fixture(channel, %{attempted_at: ~U[2026-01-01 12:00:00.000000Z]})
      job_fixture(channel, %{attempted_at: ~U[2026-01-03 12:00:00.000000Z]})

      result = ChannelLogs.list_channel_logs(channel, %{end_date: "2026-01-02"})
      assert length(result.logs) == 1
    end

    test "ignores invalid date and returns all logs", %{channel: channel} do
      job_fixture(channel)

      result = ChannelLogs.list_channel_logs(channel, %{start_date: "not-a-date"})
      assert length(result.logs) == 1
    end
  end

  describe "list_channel_logs/2 — sorting" do
    test "sorts by attempted_at desc by default", %{channel: channel} do
      older = job_fixture(channel, %{attempted_at: ~U[2026-01-01 00:00:00.000000Z]})
      newer = job_fixture(channel, %{attempted_at: ~U[2026-01-10 00:00:00.000000Z]})

      result = ChannelLogs.list_channel_logs(channel, %{})
      assert List.first(result.logs).id == newer.id
      assert List.last(result.logs).id == older.id
    end

    test "sorts by attempted_at asc when requested", %{channel: channel} do
      older = job_fixture(channel, %{attempted_at: ~U[2026-01-01 00:00:00.000000Z]})
      newer = job_fixture(channel, %{attempted_at: ~U[2026-01-10 00:00:00.000000Z]})

      result = ChannelLogs.list_channel_logs(channel, %{sort_by: "attempted_at", sort_dir: "asc"})
      assert List.first(result.logs).id == older.id
      assert List.last(result.logs).id == newer.id
    end
  end

  describe "classify_delivery_status/1" do
    test "returns 'success' for a completed job" do
      job = %Oban.Job{state: "completed"}
      assert ChannelLogs.classify_delivery_status(job) == "success"
    end

    test "returns 'failed' for a discarded job" do
      job = %Oban.Job{state: "discarded"}
      assert ChannelLogs.classify_delivery_status(job) == "failed"
    end

    test "returns 'failed' for a cancelled job" do
      job = %Oban.Job{state: "cancelled"}
      assert ChannelLogs.classify_delivery_status(job) == "failed"
    end
  end

  describe "format_event_type/1" do
    test "returns 'test' for test jobs" do
      job = %Oban.Job{args: %{"test" => true}}
      assert ChannelLogs.format_event_type(job) == "test"
    end

    test "returns the event for incident jobs" do
      job = %Oban.Job{args: %{"event" => "down"}}
      assert ChannelLogs.format_event_type(job) == "down"
    end
  end
end

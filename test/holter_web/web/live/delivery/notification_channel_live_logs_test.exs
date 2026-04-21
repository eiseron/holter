defmodule HolterWeb.Web.Delivery.NotificationChannelLiveLogsTest do
  use HolterWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Holter.Delivery
  alias Holter.Delivery.ChannelLogs

  defp channel_fixture(workspace_id, overrides \\ %{}) do
    {:ok, channel} =
      Delivery.create_channel(
        Map.merge(
          %{
            workspace_id: workspace_id,
            name: "Hook Channel",
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

  describe "delivery logs list page" do
    test "renders the page title and channel name", %{conn: conn, channel: channel} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}/logs")

      assert html =~ "data-role=\"page-title\""
      assert html =~ channel.name
    end

    test "renders log entries with status indicators", %{conn: conn, channel: channel} do
      channel_log_fixture(channel.id, %{status: :success, event_type: "down"})

      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}/logs")

      assert html =~ "data-role=\"log-status\""
      assert html =~ "data-status=\"success\""
    end

    test "back link points to channel show page", %{conn: conn, channel: channel} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}/logs")

      assert has_element?(
               view,
               "a.h-btn-back[href='/delivery/notification-channels/#{channel.id}']"
             )
    end

    test "renders empty state when channel has no logs", %{conn: conn, channel: channel} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}/logs")

      assert html =~ "data-role=\"page-info\""
      refute html =~ "data-role=\"log-status\""
    end
  end

  describe "status filter" do
    setup %{channel: channel} do
      channel_log_fixture(channel.id, %{status: :success})
      channel_log_fixture(channel.id, %{status: :failed})
      :ok
    end

    test "filters to show only success logs", %{conn: conn, channel: channel} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}/logs?status=success")

      assert html =~ "data-status=\"success\""
      refute html =~ "data-status=\"failed\""
    end

    test "filters to show only failed logs", %{conn: conn, channel: channel} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}/logs?status=failed")

      assert html =~ "data-status=\"failed\""
      refute html =~ "data-status=\"success\""
    end

    test "renders both statuses when no filter is applied", %{conn: conn, channel: channel} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}/logs")

      assert html =~ "data-status=\"success\""
      assert html =~ "data-status=\"failed\""
    end

    test "filter form change patches URL with status param", %{conn: conn, channel: channel} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}/logs")

      view
      |> form("form[phx-change=\"filter_updated\"]")
      |> render_change(%{filters: %{status: "failed"}})

      patched = assert_patch(view)
      assert patched =~ "status=failed"
    end

    test "empty status selection in filter form removes status param", %{
      conn: conn,
      channel: channel
    } do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}/logs?status=failed")

      view
      |> form("form[phx-change=\"filter_updated\"]")
      |> render_change(%{filters: %{status: ""}})

      patched = assert_patch(view)
      refute patched =~ "status="
    end
  end

  describe "sorting" do
    test "default page has dispatched_at sort link in header", %{conn: conn, channel: channel} do
      {:ok, _view, html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}/logs")

      assert html =~ "sort_by=dispatched_at"
    end

    test "sort_by=dispatched_at&sort_dir=asc renders oldest log first", %{
      conn: conn,
      channel: channel
    } do
      channel_log_fixture(channel.id, %{dispatched_at: ~U[2026-01-01 00:00:00.000000Z]})
      channel_log_fixture(channel.id, %{dispatched_at: ~U[2026-01-10 00:00:00.000000Z]})

      {:ok, view, _html} =
        live(
          conn,
          ~p"/delivery/notification-channels/#{channel.id}/logs?sort_by=dispatched_at&sort_dir=asc"
        )

      html = render(view)
      pos_old = :binary.match(html, "2026-01-01")
      pos_new = :binary.match(html, "2026-01-10")
      assert pos_old != :nomatch
      assert pos_new != :nomatch
      assert elem(pos_old, 0) < elem(pos_new, 0)
    end

    test "clicking Time header from default (desc) patches URL to asc", %{
      conn: conn,
      channel: channel
    } do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}/logs")

      view |> element("thead a[href*='sort_by=dispatched_at']") |> render_click()

      patched = assert_patch(view)
      assert patched =~ "sort_by=dispatched_at"
      assert patched =~ "sort_dir=asc"
    end

    test "active sort column shows direction indicator", %{conn: conn, channel: channel} do
      {:ok, _view, html} =
        live(
          conn,
          ~p"/delivery/notification-channels/#{channel.id}/logs?sort_by=dispatched_at&sort_dir=asc"
        )

      assert html =~ "h-sort-indicator"
      assert html =~ "↑"
    end
  end

  describe "pagination" do
    test "can change page size via the select dropdown", %{conn: conn, channel: channel} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}/logs")

      assert has_element?(view, "select[name='filters[page_size]']")

      view
      |> form("form[phx-change=\"filter_updated\"]")
      |> render_change(%{filters: %{page_size: "25"}})

      patched = assert_patch(view)
      assert patched =~ "page_size=25"
    end

    test "handles out of bounds page by resetting to last valid page", %{
      conn: conn,
      channel: channel
    } do
      for _ <- 1..3, do: channel_log_fixture(channel.id)

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}/logs?page=999&page_size=2")

      page_info = view |> element("[data-role='page-info']") |> render()
      assert page_info =~ "2"
    end
  end

  describe "log detail page" do
    test "View Details link appears in the logs table", %{conn: conn, channel: channel} do
      log = channel_log_fixture(channel.id)

      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}/logs")

      assert has_element?(view, "a[href='/delivery/channel-logs/#{log.id}']")
    end

    test "renders log detail with status, event type, and channel name", %{
      conn: conn,
      channel: channel
    } do
      log =
        channel_log_fixture(channel.id, %{
          status: :failed,
          event_type: "test",
          error_message: "connection timeout"
        })

      {:ok, _view, html} = live(conn, ~p"/delivery/channel-logs/#{log.id}")

      assert html =~ "failed"
      assert html =~ "test"
      assert html =~ "connection timeout"
      assert html =~ channel.name
    end

    test "back link on detail page points to the channel logs list", %{
      conn: conn,
      channel: channel
    } do
      log = channel_log_fixture(channel.id)

      {:ok, _view, html} = live(conn, ~p"/delivery/channel-logs/#{log.id}")

      assert html =~ ~p"/delivery/notification-channels/#{channel.id}/logs"
    end

    test "does not show error section when log has no error_message", %{
      conn: conn,
      channel: channel
    } do
      log = channel_log_fixture(channel.id, %{status: :success, error_message: nil})

      {:ok, _view, html} = live(conn, ~p"/delivery/channel-logs/#{log.id}")

      refute html =~ "Error Message"
    end

    test "shows monitor link when log has a monitor_id", %{conn: conn, channel: channel} do
      monitor = monitor_fixture()

      log =
        channel_log_fixture(channel.id, %{
          event_type: "down",
          monitor_id: monitor.id
        })

      {:ok, _view, html} = live(conn, ~p"/delivery/channel-logs/#{log.id}")

      assert html =~ ~p"/monitoring/monitor/#{monitor.id}"
    end
  end

  describe "channel show page" do
    test "View Logs link points to channel logs list", %{conn: conn, channel: channel} do
      {:ok, view, _html} =
        live(conn, ~p"/delivery/notification-channels/#{channel.id}")

      assert has_element?(
               view,
               "a[href='/delivery/notification-channels/#{channel.id}/logs']"
             )
    end
  end
end

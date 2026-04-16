defmodule HolterWeb.Web.Monitoring.MonitorRunNowTest do
  use HolterWeb.ConnCase
  import Phoenix.LiveViewTest
  use Oban.Testing, repo: Holter.Repo

  alias Holter.Monitoring
  alias Holter.Monitoring.Monitor

  use Gettext, backend: HolterWeb.Gettext

  setup do
    monitor =
      monitor_fixture(%{
        url: "https://example.com",
        last_manual_check_at: nil
      })

    %{monitor: monitor}
  end

  describe "Run Now Button" do
    test "triggers a manual check and starts the cooldown immediately", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      view |> element("button[phx-click=\"run_now\"]") |> render_click()

      updated_monitor = Monitoring.get_monitor!(monitor.id)
      assert updated_monitor.last_manual_check_at != nil

      assert_enqueued(worker: Holter.Monitoring.Workers.HTTPCheck, args: %{"id" => monitor.id})
      assert_enqueued(worker: Holter.Monitoring.Workers.SSLCheck, args: %{"id" => monitor.id})

      assert render(view) =~ "disabled"
    end

    test "respects the cooldown period and prevents duplicate clicks", %{
      conn: conn,
      monitor: monitor
    } do
      {:ok, monitor} =
        Monitoring.update_monitor(monitor, %{
          last_manual_check_at: DateTime.add(DateTime.utc_now(), -30, :second)
        })

      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert render(view) =~ "disabled"

      render_click(view, "run_now", %{})

      refute_enqueued(worker: Holter.Monitoring.Workers.HTTPCheck)
    end

    test "re-enables the button after the cooldown expires", %{
      conn: conn,
      monitor: monitor
    } do
      last_check =
        DateTime.add(DateTime.utc_now(), -(Monitor.manual_check_cooldown() - 10), :second)

      {:ok, monitor} = Monitoring.update_monitor(monitor, %{last_manual_check_at: last_check})

      {:ok, view, _html} =
        live(conn, ~p"/monitoring/monitor/#{monitor.id}")

      assert render(view) =~ "disabled"

      expired_check =
        DateTime.add(DateTime.utc_now(), -(Monitor.manual_check_cooldown() + 1), :second)

      Monitoring.update_monitor(monitor, %{last_manual_check_at: expired_check})

      send(view.pid, {:monitor_updated, nil})

      html = render(view)
      refute html =~ "disabled"
    end
  end
end

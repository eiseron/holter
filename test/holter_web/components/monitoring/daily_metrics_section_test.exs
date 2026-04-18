defmodule HolterWeb.Components.Monitoring.DailyMetricsSectionTest do
  use HolterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import HolterWeb.Components.Monitoring.DailyMetricsSection

  alias Holter.Monitoring.DailyMetric

  test "renders empty state message" do
    html = render_component(&daily_metrics_section/1, metrics: [])
    assert html =~ "No history recorded yet"
  end

  test "renders metrics table headers" do
    metrics = [
      %DailyMetric{
        monitor_id: Ecto.UUID.generate(),
        date: ~D[2026-04-18],
        uptime_percent: Decimal.new("100.0"),
        avg_latency_ms: 150,
        total_downtime_minutes: 0
      }
    ]

    html = render_component(&daily_metrics_section/1, metrics: metrics)
    assert html =~ "Uptime (%)"
  end

  test "renders metric data" do
    metrics = [
      %DailyMetric{
        monitor_id: Ecto.UUID.generate(),
        date: ~D[2026-04-18],
        uptime_percent: Decimal.new("100.0"),
        avg_latency_ms: 150,
        total_downtime_minutes: 0
      }
    ]

    html = render_component(&daily_metrics_section/1, metrics: metrics)
    assert html =~ "2026-04-18"
  end

  test "renders healthy uptime class" do
    metrics = [
      %DailyMetric{
        monitor_id: Ecto.UUID.generate(),
        date: ~D[2026-04-18],
        uptime_percent: Decimal.new("99.9"),
        avg_latency_ms: 150,
        total_downtime_minutes: 0
      }
    ]

    html = render_component(&daily_metrics_section/1, metrics: metrics)
    assert html =~ "h-text-success"
  end
end

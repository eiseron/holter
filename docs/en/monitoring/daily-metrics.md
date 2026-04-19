# Daily Metrics

The Daily Metrics page shows an aggregated uptime summary for a monitor, broken down by day.

## Accessing the Page

From the Monitor Settings page, click **Daily Metrics**, or navigate to `/monitoring/monitor/{monitor_id}/daily_metrics`.

## Chart

A chart at the top visualises daily uptime percentage over time, giving a quick visual indication of periods with degraded reliability.

## Metrics Table

Each row represents one calendar day:

| Column | Description |
|--------|-------------|
| Date | The calendar day (UTC) |
| Uptime % | Percentage of checks that returned a successful status that day. Displayed in green when high, red when low. |
| Avg Latency | Mean response time in milliseconds across all checks that day |
| Downtime | Total minutes of confirmed downtime that day |

## Sorting

Click any column header to sort by that column. Click again to reverse the sort order.

## Pagination

The table shows 30 days per page. Use the pagination controls at the bottom to navigate to earlier periods.

## Empty State

If no checks have been run yet, the table is empty and a message indicates that metrics will appear after the first check cycle.

## Real-Time Updates

The page updates automatically when new daily metrics are aggregated (once per day by default).

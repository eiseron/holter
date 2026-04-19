---
title: Technical Logs
description: Full log of every check run with filtering by status and date range, and log retention policy.
---

# Technical Logs

The Technical Logs page lists every check run for a monitor, with filtering and sorting options.

## Accessing the Page

From the Monitor Settings page, click **Technical Logs**, or navigate to `/monitoring/monitor/{monitor_id}/logs`.

## Scatter Chart

The chart at the top plots check results over time. Each dot represents one check; position on the Y-axis corresponds to latency and colour reflects status. This gives an at-a-glance view of performance patterns and outage windows.

## Filters

Use the filter bar to narrow results:

| Filter | Description |
|--------|-------------|
| Status | Filter by check result: Up, Down, Degraded, Compromised, Unknown |
| From | Show only checks after this date and time |
| To | Show only checks before this date and time |

Filters apply immediately when changed.

## Log Table

Each row represents one check:

| Column | Description |
|--------|-------------|
| Time | When the check ran (your local timezone) |
| Status | Health status of the check, shown as a coloured pill. Includes the HTTP response code when available (e.g. `UP 200`, `DOWN 503`). |
| Latency | Response time in milliseconds |

Click **View Details** on any row to open the [Log Detail](log-detail.md) page for full evidence.

## Sorting

Click a column header to sort ascending; click again for descending.

## Pagination

The table shows 50 entries per page. Use the pagination controls to navigate.

## Real-Time Updates

New check results appear automatically at the top of the list without a page reload.

## Log Retention

Logs are automatically deleted after the retention period configured for your workspace. Deletion runs once per day, triggered after the daily metrics aggregation job. Logs are removed in chunks to avoid long-running database operations, so very large backlogs may take a few cycles to clear completely.

Once a log entry is deleted it cannot be recovered. If you need to preserve evidence beyond the retention window, export the relevant [Log Detail](log-detail.md) pages before they are purged.

Even after logs are deleted, aggregated uptime data remains available on the [Daily Metrics](daily-metrics.md) page, which provides a historical summary of uptime percentage, average latency, and downtime minutes per day.

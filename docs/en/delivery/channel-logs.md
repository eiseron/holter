---
title: Delivery Logs
description: Per-channel history of every notification dispatch attempt, with filtering by status and date range.
---

# Delivery Logs

The Delivery Logs page lists every notification dispatch attempt for a channel, with filtering and sorting options.

## Accessing the Page

From the channel settings page, click **View Logs**, or navigate to `/delivery/notification-channels/{id}/logs`.

## Filters

Use the filter bar to narrow results:

| Filter | Description |
|--------|-------------|
| Results | Number of entries per page: 25, 50, or 100 |
| Status | Filter by outcome: Success or Failed |
| From | Show only dispatches on or after this date |
| To | Show only dispatches on or before this date |

Filters apply immediately when changed.

## Log Table

Each row represents one dispatch attempt:

| Column | Description |
|--------|-------------|
| Time | When the dispatch was attempted (your local timezone) |
| Status | Outcome of the dispatch: `success` or `failed` |
| Event | The event type that triggered the dispatch: `down`, `up`, or `test` |

## Sorting

Click the **Time** or **Status** column header to sort. Click again to reverse the direction.

## Pagination

Use the pagination controls below the table to navigate between pages.

## Log Retention

Delivery logs are retained for 90 days. After this period they are automatically removed and cannot be recovered.

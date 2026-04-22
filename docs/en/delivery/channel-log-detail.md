---
title: Delivery Log Detail
description: Full detail for a single notification dispatch attempt — status, event type, error message, and links to the related monitor and incident.
---

# Delivery Log Detail

The Delivery Log Detail page shows the full detail for a single notification dispatch attempt.

## Accessing the Page

Click **View Details** on any row in the [Delivery Logs](channel-logs.md) list, or navigate to `/delivery/channel-logs/{log_id}`.

## Fields

| Field | Description |
|-------|-------------|
| Status | Outcome of the dispatch: `success` or `failed` |
| Event Type | The event that triggered the dispatch: `down`, `up`, or `test` |
| Dispatched At | Exact timestamp of the dispatch attempt |
| Channel | The notification channel used, with a link to its settings page |
| Monitor | Link to the monitor that triggered the alert (when applicable) |
| Incident | Link to the incident that triggered the alert (when applicable) |

## Error Message

If the dispatch failed, the error message section shows the reason. For webhook channels this is typically an HTTP error or a connection failure. This section is hidden when the dispatch was successful.

## Related

- [Delivery Logs](channel-logs.md) — full list of dispatch attempts for a channel
- [Notification Channels](notification-channels.md) — channel settings

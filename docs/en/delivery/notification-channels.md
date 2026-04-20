---
title: Notification Channels
description: Create and manage notification channels to receive alerts when monitors change state.
---

# Notification Channels

A notification channel is a destination where Holter sends alerts. Each channel belongs to a workspace and can be linked to multiple monitors.

## Creating a Channel

1. Click **Channels** in the left sidebar.
2. Click **New Channel**.
3. Fill in the fields below and click **Create Channel**.

## Fields

| Field | Required | Description |
|-------|----------|-------------|
| Name | Yes | A human-readable label for the channel (e.g. "Ops Slack"). |
| Type | Yes | One of: `webhook`, `email`, `slack`, `discord`. |
| Target | Yes | The delivery destination. See format rules by type below. |

### Target format by type

| Type | Expected format |
|------|----------------|
| `webhook` | A valid `http://` or `https://` URL. |
| `slack` | A valid Slack incoming webhook URL (`https://hooks.slack.com/…`). |
| `discord` | A valid Discord webhook URL (`https://discord.com/api/webhooks/…`). |
| `email` | A valid email address (e.g. `ops@example.com`). |

## Editing a Channel

Click the channel name in the Channels list (`/workspaces/{workspace_slug}/channels`) to open its settings page at `/delivery/notification-channels/{id}`. You can update the name and target. The channel type cannot be changed after creation.

## Sending a Test Notification

On the channel settings page, click **Send Test** to enqueue a test notification. The test payload includes the channel name and a timestamp. This is useful to verify that the target is reachable before linking the channel to a monitor.

## Deleting a Channel

On the channel list page, click **Delete** next to the channel. This removes the channel and all monitor links. Monitors linked to a deleted channel will no longer receive notifications for that channel.

## Linking Channels to Monitors

Channels own the link to monitors. To connect a channel to one or more monitors:

1. Open the channel settings page.
2. In the **Linked Monitors** section, check each monitor that should trigger notifications through this channel.
3. Click **Save Changes**.

Unchecking a monitor and saving immediately stops future notifications for that monitor through this channel.

You can also manage links via the API — include a `notification_channel_ids` array in the monitor create or update request body.

## Payload Shape

When a monitor goes down or recovers, Holter sends the following JSON payload to webhook, Slack, and Discord channels:

```json
{
  "version": "1",
  "event": "monitor_down",
  "timestamp": "2026-04-20T10:00:00Z",
  "monitor": {
    "id": "...",
    "url": "https://example.com",
    "method": "get"
  },
  "incident": {
    "id": "...",
    "type": "downtime",
    "started_at": "2026-04-20T10:00:00Z",
    "resolved_at": null
  }
}
```

Events: `monitor_down`, `monitor_up`. For SSL expiry incidents the event is `ssl_expiry_down` / `ssl_expiry_up`.

## Related

- [Monitoring module](../monitoring/index.md) — incidents that trigger delivery
- [API reference](../../api/openapi.yml) — REST endpoints for notification channels

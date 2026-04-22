---
title: Delivery
description: Overview of the Holter delivery module — notification channels and alert dispatch.
---

# Delivery Module

The delivery module lets you receive alerts when monitors go down or recover. You define notification channels once and link them to as many monitors as you want.

## Pages

| Page | Description |
|------|-------------|
| [Notification Channels](notification-channels.md) | Create, edit, test, and delete notification channels for your workspace |
| [Delivery Logs](channel-logs.md) | Per-channel history of every notification dispatch attempt |

## How It Works

1. Create a notification channel (webhook, email, Slack, or Discord).
2. Link the channel to one or more monitors from the channel settings page (Linked Monitors section).
3. When a monitor detects a failure, Holter enqueues a notification job and delivers the alert.
4. When the monitor recovers, Holter sends a recovery alert automatically.

## Channel Types

| Type | Delivery method |
|------|----------------|
| Webhook | HTTP POST with a JSON payload to any URL |
| Email | Email sent via the configured mail provider |

## Related

- [Monitoring module](../monitoring/index.md) — incidents that trigger delivery

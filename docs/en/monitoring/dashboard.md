---
title: Monitors
description: Overview of all monitors in your workspace, ranked by severity, with real-time status updates.
---

# Monitors

The Monitors page is the main view of the monitoring module. It shows all monitors belonging to a workspace in a card grid, ranked so the most critical issues appear at the top.

## Accessing the Page

Click **Monitors** in the left sidebar, or navigate directly to `/workspaces/{workspace_slug}/monitors`.

## Monitor Cards

Each card displays:

- **URL** — the address being monitored
- **Method and interval** — e.g. `GET • 300s`
- **Health badge** — the current status of the monitor (see [Health Status](#health-status))
- **Sparkline chart** — a mini history of recent check results
- **Details link** — navigates to the Monitor Settings page for that monitor

## Health Status

The badge on each card reflects the monitor's current health:

| Badge | Meaning |
|-------|---------|
| UP | The last check succeeded and no open incidents exist |
| DEGRADED | The monitor is responding but with elevated latency or partial failures |
| COMPROMISED | An SSL issue or defacement incident is open |
| DOWN | The last check failed or a downtime incident is open |
| UNKNOWN | No checks have been run yet |
| PAUSED | Monitoring is suspended; the monitor is not being checked |

## Ranking Order

Monitors are automatically sorted so the most actionable items appear first:

1. Active DOWN monitors
2. Active COMPROMISED monitors
3. Active DEGRADED monitors
4. Active UP monitors
5. Active UNKNOWN monitors
6. Paused monitors (any health status)

Within each group, more recently created monitors appear before older ones.

## Monitor Quota

The header shows your workspace quota, e.g. **3 / 10 monitors**. When the quota is full, the **New Monitor** button is disabled and you must delete or archive an existing monitor before adding a new one.

## Creating a New Monitor

Click **New Monitor** in the top-right corner to open the creation form. See [New Monitor](new-monitor.md) for full details.

## Empty State

If no monitors have been created yet, the page shows a prompt to create the first one.

## Real-Time Updates

The dashboard updates automatically via a live connection — you do not need to refresh the page to see status changes.

---
title: Monitor Settings
description: Edit a monitor, trigger a manual check, view health history, and delete the monitor.
---

# Monitor Settings

The Monitor Settings page lets you view and edit a monitor's configuration, trigger a manual check, and delete the monitor.

## Accessing the Page

Click **Details** on a monitor card from the Dashboard, or navigate to `/monitoring/monitor/{monitor_id}`.

## Header

The page header shows:

- **Monitor URL** — the address being monitored
- **UUID** — the monitor's unique identifier (useful for API calls)
- **Health badge** — current health and logical state (see [Alert & Incidents](alert-incidents.md))
- **Daily Metrics** — link to the uptime history page
- **Technical Logs** — link to the check log list
- **Run Now** button — triggers an immediate check (see below)

## Overview Chart

A chart below the header shows the history of recent check results. Each data point represents one check, color-coded by status.

## Configuration Form

The form has the same fields as the [New Monitor](new-monitor.md) form. Changes are validated live and saved only when you click **Save Changes**.

## Run Now

Clicking **Run Now** enqueues an immediate HTTP check outside the normal schedule. After triggering, the button shows a **Wait 60s** countdown — manual checks are rate-limited to one per minute per monitor.

The page updates automatically when the check completes: the health badge and overview chart refresh without a page reload.

## Pausing and Resuming

To pause monitoring, set the **State** field to **Paused** and save. The health badge switches to a PAUSED indicator and the monitor stops being checked. Set it back to **Active** to resume.

## Deleting a Monitor

Click **Delete Monitor** at the bottom of the form. A confirmation dialog appears. Click **Yes, Delete Completely** to permanently remove the monitor and all its associated logs, metrics, and incidents. This action cannot be undone.

## Real-Time Updates

The page subscribes to live events. When an automatic check completes, the health badge, overview chart, and header update automatically.

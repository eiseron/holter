---
title: Monitor Settings
description: Edit a monitor, trigger a manual check, view health history, and delete the monitor.
---

# Monitor Settings

The Monitor Settings page lets you view and edit a monitor's configuration, trigger a manual check, and delete the monitor.

## Accessing the Page

Click **Details** on a monitor card from the Dashboard, or navigate to `/monitoring/monitor/{monitor_id}`.

## Navigation Bar

A sub-navigation bar below the header links to all monitor-related pages. The current page is omitted from the bar:

- **Monitor Details** — this page
- **Daily Metrics** — uptime history
- **Technical Logs** — check log list
- **Incidents** — incident history

## Header

The page header shows:

- **Monitor URL** — the address being monitored
- **UUID** — the monitor's unique identifier (useful for API calls)
- **Health badge** — current health and logical state (see [Alerts & Incidents](alert-incidents.md))
- **Run Now** button — triggers an immediate check (see below)

## Active Incidents Panel

If the monitor has any open incidents, a panel is displayed below the navigation bar listing each one with its type, when it started, and a short root cause. Click the incident row to open the [Incident Detail](incident-detail.md) page.

The panel disappears automatically once all incidents are resolved.

## Overview Chart

A chart below the header shows the history of recent check results. Each data point represents one check, color-coded by status.

## Configuration Form

The form has the same fields as the [New Monitor](new-monitor.md) form. Changes are validated live and saved only when you click **Save Changes**.

## Run Now

Clicking **Run Now** enqueues an immediate HTTP check outside the normal schedule. After triggering, the button shows a **Wait 60s** countdown — manual checks are rate-limited to one per minute per monitor.

The page updates automatically when the check completes: the health badge and overview chart refresh without a page reload.

## SSL Ignore

The **Ignore SSL Errors** toggle in the configuration form instructs Holter to skip SSL certificate checks for this monitor. When enabled:

- No SSL expiry incidents are opened.
- Any existing open SSL expiry incident is resolved the next time **Run Now** is clicked or a scheduled check runs.
- HTTP checks still run normally.

This is useful for monitors on internal services that intentionally use self-signed certificates.

## Skip Domain Expiration Checks

The **Skip Domain Expiration Checks** toggle disables WHOIS/RDAP lookups for the monitor's domain. When enabled:

- No domain expiry incidents are opened.
- Any existing open domain expiry incident is resolved the next time a scheduled check runs.
- SSL and HTTP checks still run normally.

Domain checks run at most once every 24 hours per monitor and are silently skipped when the URL points at an IP literal or an internal host. Disable this toggle for monitors where the registration date is irrelevant (e.g. internal staging endpoints).

## Pausing and Resuming

To pause monitoring, set the **State** field to **Paused** and save. The health badge switches to a PAUSED indicator and the monitor stops being checked. Set it back to **Active** to resume.

## Deleting a Monitor

Click **Delete Monitor** at the bottom of the form. A confirmation dialog appears. Click **Yes, Delete Completely** to permanently remove the monitor and all its associated logs, metrics, and incidents. This action cannot be undone.

## Real-Time Updates

The page subscribes to live events. When an automatic check completes, the health badge, overview chart, and header update automatically.

---
title: Incident History
description: Browse, filter, and paginate the full incident history for a monitor.
---

# Incident History

The Incident History page lists every incident ever opened for a monitor — open and resolved — with filtering, pagination, and links to individual incident detail pages.

## Accessing the Page

From any monitor sub-page, click **Incidents** in the navigation bar, or navigate to `/monitoring/monitor/{monitor_id}/incidents`.

## Filters

Use the filter bar at the top to narrow results:

| Filter | Description |
|--------|-------------|
| Type | Filter by incident type: Downtime, Defacement, SSL Expiry |
| State | Filter by lifecycle state: Open, Resolved |
| From | Show only incidents that started on or after this date |
| To | Show only incidents that started on or before this date |

Filters apply immediately when changed.

## Incident Table

Each row represents one incident:

| Column | Description |
|--------|-------------|
| Since | Date and time the incident was opened |
| Type | Category of the problem (Downtime, Defacement, or SSL Expiry) |
| State | **Open** (problem is active) or **Resolved** (problem was closed) |
| Duration | How long the incident lasted, in minutes. Shows a dash (—) for incidents that are still open |
| Root Cause | Short description of why the incident was opened, truncated to fit the row |

Click **Details** on any row to open the [Incident Detail](incident-detail.md) page with the full root cause and the monitor snapshot captured at the time.

## Pagination

The table shows 25 incidents per page by default. Use the pagination controls to navigate between pages.

## Real-Time Updates

New incidents appear automatically when they are opened. Existing rows update when an incident is resolved, without a page reload.

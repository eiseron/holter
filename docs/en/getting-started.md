# Getting Started with Holter

Holter monitors your URLs on a recurring schedule, tracks uptime history, and opens incidents when problems are detected. This guide walks you through the core concepts and your first monitor.

## Core Concepts

### Workspace

A workspace is an isolated environment that groups monitors together. Each workspace has a monitor quota — the maximum number of monitors allowed under your plan. All monitoring URLs are scoped to a workspace slug (e.g. `/monitoring/workspaces/my-company/dashboard`).

### Monitor

A monitor is a configured check against a single URL. It runs on a fixed interval (e.g. every 5 minutes) and records the result of each check as a log entry. A monitor has two independent pieces of state:

- **Health status** — what the last check found: `up`, `degraded`, `compromised`, `down`, or `unknown`
- **Logical state** — whether checking is active: `active`, `paused`, or `archived`

### Check

Each time a monitor runs, it makes an HTTP request to the configured URL and evaluates the response against your rules (status code, keywords, SSL validity). The result is stored as a log entry and used to update the monitor's health status.

### Incident

An incident is an open problem that persists until resolved. Holter opens incidents automatically for downtime, SSL issues, and defacement (negative keyword matches). The monitor's health status reflects the highest-severity open incident.

## Setting Up Your First Monitor

1. Open the [Dashboard](monitoring/dashboard.md) for your workspace.
2. Click **New Monitor**.
3. Enter the URL you want to monitor (e.g. `https://example.com`).
4. Choose an HTTP **Method** (GET is the default for most sites).
5. Set a **Check Interval** — 300 seconds (5 minutes) is a reasonable starting point.
6. Optionally add **Positive Keywords** — words that must appear in the response body, such as `login` or `home`.
7. Click **Create Monitor**.

The monitor appears on the dashboard and begins checking within the next minute.

## Reading the Dashboard

Monitors are sorted by urgency: DOWN monitors appear first, followed by COMPROMISED, DEGRADED, UP, and finally PAUSED. The health badge on each card updates in real time — no refresh needed.

See [Dashboard](monitoring/dashboard.md) for a full explanation of the card layout and quota indicator.

## Investigating a Problem

When a monitor turns DOWN or DEGRADED:

1. Click **Details** on the monitor card.
2. Review the **Overview Chart** for the pattern (sudden vs. gradual).
3. Click **Technical Logs** to see individual check results.
4. Click **View Details** on a failed log to see the full HTTP evidence: status code, redirect chain, response headers, and body content.

See [Log Detail](monitoring/log-detail.md) for a full explanation of the evidence page.

## Pausing and Resuming

If you need to take a service offline for maintenance, set the monitor's **State** to **Paused** on the Monitor Settings page. Paused monitors are moved to the bottom of the dashboard and are excluded from incident detection until resumed.

## Next Steps

- [Monitoring Module Overview](monitoring/index.md)
- [Alert & Incident Reference](monitoring/alert-incidents.md)

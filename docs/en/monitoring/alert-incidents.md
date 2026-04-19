# Alerts & Incidents

This document explains how Holter determines the health of a monitor, what incidents are, and how the two interact.

## Health Status

Every monitor has a `health_status` field that summarises its current condition:

| Status | Severity | Meaning |
|--------|----------|---------|
| DOWN | 4 (highest) | The last check failed or a downtime incident is open |
| COMPROMISED | 3 | An SSL error or defacement incident is open |
| DEGRADED | 2 | The monitor is reachable but performing below expectations |
| UP | 1 | All checks pass and no open incidents exist |
| UNKNOWN | 0 | No checks have been run yet |

When multiple signals disagree, the highest severity wins.

## Logical State

`logical_state` is separate from health and controls whether the monitor is actively running:

| State | Meaning |
|-------|---------|
| active | Checks run on schedule |
| paused | Checks are suspended; the monitor is not evaluated |
| archived | The monitor is disabled and excluded from quota counts |

A paused monitor retains its last known health status but is not re-evaluated until resumed.

## Incidents

An incident is an open problem detected by the system. There are three types:

### Downtime

Opened when an HTTP check fails. The monitor's health is set to **DOWN** for the duration. The incident closes when a subsequent successful check is recorded.

### Defacement

Opened when the response body contains a negative keyword, suggesting the page content has been tampered with. The monitor's health is set to **COMPROMISED**.

### SSL Expiry

Opened when an SSL certificate check detects a problem:

| Root Cause | Resulting Health |
|------------|-----------------|
| Certificate expired | COMPROMISED |
| Critical expiry warning | COMPROMISED |
| SSL connection error | COMPROMISED |
| Other (e.g. approaching expiry) | DEGRADED |

## Health Recalculation

After every check, Holter recalculates the monitor's health by combining two signals:

1. **Latest log status** — the result of the most recent HTTP check
2. **Open incidents** — the highest-severity status implied by any open incident

The final `health_status` is whichever of these two signals has the higher severity.

## Dashboard Ranking

Monitors are ranked on the Dashboard so the most actionable items appear first:

1. Active monitors ordered by severity (DOWN → COMPROMISED → DEGRADED → UP → UNKNOWN)
2. Paused monitors (always last, regardless of their health status)

Within the same severity tier, more recently created monitors appear above older ones.

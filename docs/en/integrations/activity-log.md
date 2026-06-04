---
title: Activity Log
description: How to read the integration activity log in Holter.
---

# Activity Log

The activity log records every action Holter dispatched through an integration — both outbound dispatches (Holter → provider) and inbound webhook events (provider → Holter).

## Accessing the Log

Open an integration from the Integrations list and click the **Activity** tab.

## Log Columns

| Column | Description |
|--------|-------------|
| Time | When the action occurred |
| Direction | `outbound` (Holter sent to provider) or `inbound` (provider sent to Holter) |
| Action | The action dispatched (e.g., `pause_campaign`) |
| Target | The provider target ID and label |
| Status | `success`, `failed`, or `retrying` |
| Duration | Time the provider API call took |

## Statuses

- **success** — the provider accepted the request.
- **failed** — the request failed and will not be retried (e.g., invalid target ID, token permanently revoked).
- **retrying** — a transient error occurred; Holter will retry with exponential backoff (5 min, 15 min, 60 min).

## Related

- [Automation Rules](rules.md) — rules that produce activity log entries
- [Connect a Provider](connect-provider.md) — integration status that affects dispatches

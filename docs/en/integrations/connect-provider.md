---
title: Connect a Provider
description: How to connect and disconnect an external provider in Holter integrations.
---

# Connect a Provider

## Browse the Catalog

Navigate to **Integrations → New** inside your workspace. Providers are grouped by category (Ads, Notifications, Issue Tracking, Status Page, Calendar). Each card shows the provider name, a short description, and its current connection status.

If your workspace plan does not include a provider, the card displays an "Upgrade required" badge and the connect button is disabled.

## Connecting

1. Click **Connect** on the provider card.
2. You are redirected to the provider's authorization page.
3. Authorize Holter to act on your behalf.
4. After authorization, you are redirected back to Holter and the integration is created with status **Active**.

The authorization uses OAuth 2.0. Holter stores only the access token (encrypted at rest) — it never stores your provider password.

## Reconnecting

If the integration status becomes **Re-authentication required**, the access token has been revoked or expired and cannot be refreshed automatically. Click **Reconnect** to go through the OAuth flow again.

## Disconnecting

1. Open the integration from the Integrations list.
2. Click **Disconnect** at the bottom of the page.
3. Holter revokes the token with the provider and removes the integration.

Disconnecting deletes all rules associated with the integration. The activity log entries are kept for audit purposes.

## Related

- [Automation Rules](rules.md) — set up actions after connecting
- [Activity Log](activity-log.md) — review what Holter dispatched

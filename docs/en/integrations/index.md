---
title: Integrations
description: Overview of the Holter integrations module — connect external providers and automate actions during incidents.
---

# Integrations Module

The integrations module lets you connect third-party services to your workspace and automate actions when monitor incidents occur — for example, pausing ad campaigns when a monitor goes down and resuming them automatically when it recovers.

## Pages

| Page | Description |
|------|-------------|
| [Connect a Provider](connect-provider.md) | Browse the provider catalog and authorize Holter to act on your behalf |
| [Automation Rules](rules.md) | Define which events trigger which actions on which targets |
| [Activity Log](activity-log.md) | Per-integration history of every automated action dispatched |

## How It Works

1. Browse the catalog and connect a provider (OAuth authorization).
2. Create rules that map monitoring events to provider actions (e.g., `incident_opened` → pause campaign).
3. When a monitor incident opens, Holter dispatches the matching actions automatically.
4. When the incident resolves, Holter dispatches the corresponding recovery actions.
5. Every dispatch — success or failure — is recorded in the integration's activity log.

## Supported Providers

| Provider | Category | Actions |
|----------|----------|---------|
| Google Ads | Ads | Pause / resume campaigns |
| Meta Ads | Ads | Pause / resume campaigns and ad sets |

## Related

- [Monitoring module](../monitoring/index.md) — incidents that trigger integrations
- [Settings — API Tokens](../settings/api-tokens.md) — manage tokens for the Integrations API

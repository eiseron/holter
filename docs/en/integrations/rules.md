---
title: Automation Rules
description: How to create and manage automation rules in Holter integrations.
---

# Automation Rules

A rule binds a monitoring event to a provider action on a specific target. When the event occurs, Holter dispatches the action automatically.

## Creating a Rule

1. Open an active integration from the Integrations list.
2. Click **Add Rule**.
3. Select the **Monitor** the rule applies to.
4. Select the **Event** that triggers the rule:
   - `incident_opened` — a monitor transitions to failing
   - `incident_resolved` — a monitor recovers
   - `monitor_paused` — a monitor is manually paused
   - `monitor_resumed` — a monitor is manually resumed
5. Select the **Action** to dispatch:
   - `pause_campaign` / `resume_campaign` — Google Ads or Meta Ads campaigns
   - `pause_ad_set` / `resume_ad_set` — Meta Ads ad sets
6. Enter the **Target ID** — the provider's identifier for the campaign or ad set.
7. Optionally enter a **Target Label** to help you identify the target in the activity log.
8. Click **Save**.

## Safe Resume

When an `incident_resolved` event triggers a `resume_campaign` action, Holter only resumes campaigns that it previously paused — it will not resume a campaign that was already paused before the incident. This prevents Holter from unintentionally activating campaigns you had stopped for other reasons.

## Deleting a Rule

Open the rule from the integration page and click **Delete**. Existing dispatches in the activity log are not affected.

## Related

- [Activity Log](activity-log.md) — see which rules fired and their outcomes
- [Connect a Provider](connect-provider.md) — a rule requires an active integration

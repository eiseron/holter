---
title: Releases
description: Changelog of user-facing changes in each Holter release.
---

# Releases

This page lists user-facing changes in each Holter release, newest first. The version selector in the top navigation lets you switch between frozen snapshots of past versions.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Holter uses [Semantic Versioning](https://semver.org/).

## v0.1.0 — Initial release

_Release date will be filled in when v0.1.0 ships._

### Added

#### Identity

- **Account sign-up and sign-in** — create an account with email and password and reach your workspace dashboard. See [Sign Up](identity/sign-up.md) and [Sign In](identity/sign-in.md).
- **Email verification** — single-use, short-lived activation link emailed at sign-up. See [Email Verification](identity/email-verification.md).
- **Forgot password** — recover access through an emailed reset link with a 15-minute TTL that revokes existing sessions. See [Forgot Password](identity/forgot-password.md).
- **Default workspace on sign-up** — every new account gets a workspace and is linked as `owner`. See [Identity overview](identity/index.md).

#### Monitoring

- **Monitors** — recurring HTTP checks against a single URL, with configurable method, interval, positive and negative keywords, and SSL validation. See [Monitors](monitoring/dashboard.md) and [New Monitor](monitoring/new-monitor.md).
- **Health status** — every monitor reports `up`, `degraded`, `compromised`, `down`, or `unknown`, derived from the most recent check and any open incidents. See [Alerts & Incidents](monitoring/alert-incidents.md).
- **Logical state** — monitors can be `active`, `paused`, or `archived` independently of their health status. See [Monitor Settings](monitoring/monitor-settings.md).
- **Daily metrics** — uptime percentage, average latency, and downtime minutes per day for each monitor. See [Daily Metrics](monitoring/daily-metrics.md).
- **Technical logs** — full log of every check run, filterable by status and date range, with HTTP evidence (status code, redirect chain, headers, body) per entry. See [Technical Logs](monitoring/logs.md) and [Log Detail](monitoring/log-detail.md).
- **Incident history** — downtime, SSL, and defacement incidents opened automatically when checks fail, with a root-cause snapshot per incident. See [Incident History](monitoring/incidents.md) and [Incident Detail](monitoring/incident-detail.md).

#### Delivery

- **Notification channels** — workspace-level channels that receive alerts when monitors fail or recover. Channels can be linked to multiple monitors. See [Notification Channels](delivery/notification-channels.md).
- **Webhook channel** — HTTP POST with a JSON payload to any URL.
- **Email channel** — alerts delivered through the configured mail provider.
- **Delivery logs** — per-channel history of every notification dispatch attempt. See [Delivery Logs](delivery/channel-logs.md).

#### Settings

- **User settings** — account-level page listing the workspaces you belong to. See [User](settings/user.md).
- **Workspace settings** — workspace configuration, editable by members with `Owner` or `Admin` role. See [Workspace](settings/workspace.md).
- **API tokens** — workspace tokens for the public API, managed by the workspace owner. See [API tokens](settings/api-tokens.md).

---
title: Workspace Settings
description: Workspace-wide preferences. Owner/admin only.
---

# Workspace Settings

Open Workspace settings from the **Settings** entry in the workspace sidebar (visible only to admins and owners) or by clicking your workspace's name from the [User settings](user.md) page. The page lives at `/identity/workspaces/{workspace-slug}`.

Only members whose role is `Owner` or `Admin` can edit this page. The sidebar entry is hidden from regular members; opening the URL directly sends them back to the dashboard.

## Language

The **Language** field is the workspace's default UI language. It applies to:

1. **Members without a personal preference** — when a member visits a workspace-scoped page and has not set a language on their own User settings, the workspace's default is used.
2. **New notification channels** — email and webhook channels created without an explicit language inherit this default at notification dispatch time. See [Notification Channels](../delivery/notification-channels.md) for how to override per channel.

Choose **Portuguese (Brazil)** or **English** and click **Save**. The change applies on the next render.

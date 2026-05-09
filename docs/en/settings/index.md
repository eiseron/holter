---
title: Settings
description: User and workspace configuration in Holter.
---

# Settings

Holter splits settings between two top-level pages:

| Page | Where to find it | Who can edit |
|------|------------------|--------------|
| [User](user.md) | **My account** in the workspace sidebar | The user themselves |
| [Workspace](workspace.md) | **Workspace settings** in the workspace sidebar | Members with `Owner` or `Admin` role |

Each page lives at the top of its own resource:

- The user page is at `/identity/user/{user-id}` and is independent of any workspace.
- A workspace page is at `/workspaces/{workspace-slug}` and applies to that specific workspace.

The user page lists every workspace you belong to so you can jump to a workspace's settings without going back to the workspace dashboard. Inside any settings page, the inner navigation shows your account plus one entry per workspace you administer, so you can flip between admin contexts in one click.

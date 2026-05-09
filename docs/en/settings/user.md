---
title: User Settings
description: Personal preferences for your Holter account.
---

# User Settings

Open your User settings from the **My account** entry in the workspace sidebar. The page lives at `/identity/user/{user-id}` — it is private; only the user themselves can open their own page, and it does not depend on which workspace you are visiting.

The page also lists every workspace you belong to. Click a workspace whose role is `Owner` or `Admin` to open its [Workspace settings](workspace.md).

## Language

The **Language** field controls the language of the UI for *your* account, regardless of which workspace you are visiting.

- Choose **Portuguese (Brazil)** or **English** to override every other source.
- Choose **Use workspace default** (the empty option) to fall through to the workspace's default language. If that is also unset, your browser's `Accept-Language` header is used; finally Holter falls back to Brazilian Portuguese.

Click **Save** and the page reloads in the new language. To go back to the workspace default later, return here, pick the empty option and Save again.

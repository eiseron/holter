---
title: API Tokens
description: Mint, scope and revoke programmatic access tokens for a workspace from the dashboard.
---

# API Tokens

The **API tokens** page lets you mint workspace-scoped tokens that an external script, CI job, or third-party service can use to act on your workspace without logging in as you.

Open it from the workspace sidebar (**API tokens**, below **Settings**) or directly at `/identity/workspaces/{workspace-slug}/api-tokens`.

## Who can see this page

| Role | Can open the page | Can create tokens | Can revoke tokens |
|------|-------------------|-------------------|-------------------|
| Owner | Yes | Yes | Yes |
| Admin | Yes — list only | No | No |
| Member | No (the URL bounces back to the dashboard) | — | — |

If you cannot see the entry in the sidebar, ask a workspace owner to grant you the role you need.

## Creating a token

1. Type a **name** that future-you will recognise — for example `CI / read-only dashboard` or `release-bot`. Names live alongside the token in the active list, so a clear label makes revoking later easy.
2. Pick the **permissions** the token should grant. Each checkbox shows a plain-language label, the technical scope identifier (in case the integration you are setting up asks for it), and a one-line description of what enabling it does. Tick only what the integration actually needs — a token with no write permissions cannot accidentally delete a monitor.
3. Click **Generate token**.

The token is **shown exactly once** in a panel at the top of the page. Copy it into your secret manager (1Password, Vault, GitHub Actions secrets, etc.) right away — once you dismiss the panel, Holter has no way to show it to you again. If you lose it, the only path forward is to revoke it and mint a new one.

After dismissal the form is cleared so you can keep going if you need a second token with a different set of permissions.

## Permissions, in plain language

When you create a token, each permission carries a label and a one-line description. The UI is the source of truth — these are the same labels that appear on the page:

* **View workspace** — read the workspace's name and basic metadata
* **View monitors** / **Manage monitors** — list and watch monitor health, or create/edit/delete monitors
* **View logs** / **View metrics** / **View incidents** — read raw checks, daily uptime numbers, and incident timelines
* **View notification channels** / **Manage notification channels** — list webhook and email channels, or create/edit/delete them (and rotate their signing secrets)
* **Send test pings** — fire a test delivery through a channel
* **View delivery history** — read the delivery log of past notifications

Pick the smallest set that lets the integration do its job. If you discover later that you need more, mint a new token with the broader scope and revoke the narrow one.

## The active tokens list

Every token you have created in this workspace appears in the **Active tokens** table:

* **Name** — what you called it
* **Permissions** — the labels you ticked when minting
* **Last used** — the moment Holter most recently saw the token on a request, or **Never** if it has not been used yet
* **Status** — **Active** or **Revoked**
* **Revoke** — the action button to retire a token

The list is workspace-scoped: tokens minted in another workspace will not show up here.

## Revoking a token

Click **Revoke** on the row, confirm in the prompt, and the token is dead from the next request onward. The row stays in the list with status **Revoked** so there is a paper trail. Revocation cannot be undone — if you want the token back, mint a new one.

You should revoke a token when:

* The script or CI job that used it has been retired
* You suspect the token has leaked (committed to git by accident, posted in a chat, etc.)
* The integration is being rotated to a different scope set
* The person who minted the token no longer needs to mint tokens

## What happens when membership changes

If a workspace owner removes you from the workspace, every token you minted against that workspace is **revoked automatically** at the same moment. You do not need to revoke them manually before leaving — Holter handles it. The reverse is also true: you cannot keep a token alive after losing access.

## Best practices

* **Name tokens after the consumer**, not the day. `release-bot` and `staging-uptime-dashboard` age better than `2026-05-09`.
* **One token per integration.** Sharing a single token across systems makes revocation an all-or-nothing decision.
* **Mint with the narrowest permissions you can.** A read-only token cannot be turned into a write tool by an attacker.
* **Treat the plaintext like a password.** Paste it directly into your secret manager; do not save it to a notes app, do not put it in a `.env` file you might commit.
* **Audit the list periodically.** A token sitting at **Last used: Never** for months is a candidate for revocation.

## Using the token from a script

Holter's REST API is what consumes these tokens, but the API surface itself — endpoints, request bodies, error formats, rate limits — has its own documentation that lives separately. This page only covers the UI for managing the tokens; once you have one in hand, head to the API reference for how to send it.

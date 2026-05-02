---
title: Identity
description: Account, sign-up, sign-in, and email verification in Holter.
---

# Identity Module

The identity module governs how you create a Holter account, prove that an email address is yours, and stay signed in across the dashboard. Every workspace, monitor and notification channel is owned by an identity in this module.

## Pages

| Page | Description |
|------|-------------|
| [Sign Up](sign-up.md) | Create your account, accept the terms, and trigger the verification email |
| [Email Verification](email-verification.md) | Activate your account by clicking the link sent to your inbox |
| [Sign In](sign-in.md) | Authenticate with email and password and reach your workspace dashboard |

## Account States

Each account has an `onboarding_status` field that controls what you can do:

- **pending_verification** — the account has been created but the email has not been verified. You can sign in but cannot reach the workspace dashboard.
- **active** — the email is verified, the workspace dashboard is reachable, and monitors and channels can be created.
- **pending_billing** — reserved for future paid plans.
- **banned** — administrative block. All sessions are revoked immediately and signing in is rejected.

## Workspace Membership

Signing up automatically creates a default workspace and links you to it as `owner`. Future iterations will allow inviting additional users; the join model already supports `owner | admin | member` roles. See the [Monitoring overview](../monitoring/index.md) for what a workspace contains.

## Security Notes

- Passwords are hashed with Argon2ID and salted with a server-side pepper, so a database leak alone is not enough to brute-force passwords offline.
- Sessions are stored as random tokens whose SHA-256 digest is the only thing persisted; cookies are HTTP-only and `SameSite: Lax` to defend against CSRF and JavaScript theft.
- Verification links are single-use and short-lived. Clicking the same link twice fails on the second attempt with a neutral error.

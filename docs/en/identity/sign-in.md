---
title: Sign In
description: Authenticate against Holter with email and password.
---

# Sign In

Once your account is verified you can sign in at any time.

## Signing In

1. Open `/identity/login`.
2. Enter the email address you used at signup.
3. Enter your password.
4. Click **Sign in**.

On success Holter lands you on the monitor list of your default workspace. If you tried to reach a specific page before signing in, the post-login redirect takes you back there.

## Failed Sign-In

A wrong password or an unknown email both produce the same neutral message — *Invalid email or password.* — and the same response time. This is intentional: it stops attackers from probing whether a particular email is registered.

## Sign-In Sessions

A successful sign-in stores a random session token in a HTTP-only cookie. The token rotates forward as you keep using the dashboard, so an active session does not need a hard cut-off. Signing out (top-right menu) deletes the token immediately on the server side.

## Account Locked or Banned

A `banned` account is rejected at sign-in with the same neutral message. If you believe this is a mistake, contact support.

## Next Steps

- [Workspace dashboard](../monitoring/dashboard.md)
- [Notification channels](../delivery/notification-channels.md)

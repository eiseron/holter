---
title: Forgot Password
description: Recover access to your Holter account through an emailed reset link.
---

# Forgot Password

If you forget your password, Holter sends a reset link to the email on file. The link is short-lived and single-use.

## Requesting a reset

1. Open `/identity/login` and click **Forgot your password?**.
2. Enter the email address on your account.
3. Click **Send instructions**.

Whether or not the email actually exists, the screen returns the same neutral message — *"If this email exists, you will receive instructions."* This is intentional: it prevents an attacker from probing whether a specific address is registered.

## The email and the link

If the address belongs to an account, you receive an email with the subject **"Holter password reset"** and a link in the form `/identity/reset-password/<token>`. The link:

- expires in **15 minutes**;
- is **single-use** — once a reset succeeds, any further attempt with the same link is rejected;
- the **most recent link** stays valid if you ask for a new one (still within the 15-minute window).

If the link is expired or already used, the system sends you back to `/identity/forgot-password` with the message *"This reset link is invalid or has expired."* — just request a new one.

## Setting the new password

The link opens the **Set a new password** form. The new password must satisfy the same policy as signup: at least 12 characters with upper case, lower case, and a digit. The confirmation field must match.

On confirm:

1. The password is hashed (Argon2ID with a server-side pepper) and stored on your account.
2. **All active sessions on other devices are revoked** — any tab open in another browser is signed out on the next request. This is the "Session Sovereignty" guarantee: changing your password invalidates anything that came before it.
3. You are redirected to `/identity/login` with the message *"Your password has been updated. Sign in with the new password."*
4. A security-alert email lands in your inbox with the subject **"Your password has been changed"**, announcing the session revocation and what to do if you did not perform the change.

## Security notes

- The token stored in the database is a **SHA-256 digest of the plaintext** — the server never persists the plaintext of the link.
- A weak password **does not consume** the token: you can retry on the same link as long as it is still within the 15-minute window.
- The post-change alert email is your chance to spot an unauthorized change. If you receive this email without having requested a reset, change the password immediately and contact support.

## Next steps

- [Sign in](sign-in.md)
- [Email verification](email-verification.md)

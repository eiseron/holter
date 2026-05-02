---
title: Sign Up
description: How to create a Holter account.
---

# Sign Up

Creating an account is the first step before you can configure monitors or notification channels.

## Creating Your Account

1. Open `/identity/new`.
2. Enter the email address you want to use as your login.
3. Pick a strong password. The minimum policy is 12 characters with at least one lowercase letter, one uppercase letter, and one digit.
4. Tick **I have read and agree to the Terms of Use and Privacy Policy**. The form will not submit without explicit consent.
5. Click **Create account**.

When the form is accepted you land on the sign-in page with a flash that asks you to check your email. Until you verify your email the account is in `pending_verification` and the workspace dashboard is not reachable.

## What Happens Behind the Scenes

- A new user record is created with `onboarding_status: pending_verification`.
- A default workspace is created and you become its `owner`.
- A verification email is sent to the address you provided.
- The exact moment you accepted the terms is recorded so it can be replayed during legal review.

## If You Don't Receive the Email

Check the spam folder first. If it does not arrive, contact support — automatic resend will land in a future release.

## Next Steps

- [Verify your email](email-verification.md)
- [Sign in](sign-in.md)

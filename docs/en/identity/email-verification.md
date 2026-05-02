---
title: Email Verification
description: Activate your Holter account by clicking the link sent to your inbox.
---

# Email Verification

After you sign up, Holter sends a verification email to the address on the account. The link inside that email is the only way to activate the account.

## Verifying Your Email

1. Open the email from `noreply@holter.dev` with the subject "Verify your Holter account".
2. Click the verification link in the body.
3. Holter activates the account and redirects you to `/identity/login` with a confirmation message.

## Link Behaviour

- The link is single-use. Clicking it a second time fails with a neutral error.
- The link is short-lived (1 hour from the moment of signup). If it expires you will see the same neutral error.
- The link is bound to the user that originally requested it; you cannot share it with someone else to verify their address.

If you didn't request a Holter account but received the verification email, you can safely ignore it. Without your click, no account becomes active.

## Troubleshooting

- **"This verification link is invalid or has expired."** — either the link was already used, or more than an hour has passed. Sign up again with the same email; this is intentional behaviour to keep verification windows tight.

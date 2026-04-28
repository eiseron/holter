---
title: Notification Channels
description: Create and manage notification channels to receive alerts when monitors change state.
---

# Notification Channels

A notification channel is a destination where Holter sends alerts. Each channel belongs to a workspace and can be linked to multiple monitors.

## Creating a Channel

1. Click **Channels** in the left sidebar.
2. Click **New Channel**.
3. Fill in the fields below and click **Create Channel**.

## Fields

| Field | Required | Description |
|-------|----------|-------------|
| Name | Yes | A human-readable label for the channel (e.g. "Ops Webhook"). |
| Type | Yes | One of: `webhook`, `email`. |
| Target | Yes | The delivery destination. See format rules by type below. |

### Target format by type

| Type | Expected format |
|------|----------------|
| `webhook` | A valid `http://` or `https://` URL. |
| `email` | A valid email address (e.g. `ops@example.com`). |

## Editing a Channel

Click the channel name in the Channels list (`/delivery/workspaces/{workspace_slug}/channels`) to open its settings page at `/delivery/notification-channels/{id}`. You can update the name and target. The channel type cannot be changed after creation.

## Delivery Logs

Every notification dispatch attempt is recorded and visible from the channel settings page. Click **View Logs** to open the [Delivery Logs](channel-logs.md) list, which shows the outcome of each dispatch with filters by status and date range.

Logs are retained for 90 days.

## Sending a Test Notification

On the channel settings page, click **Send Test** to enqueue a test notification. The test payload includes the channel name and a timestamp. This is useful to verify that the target is reachable before linking the channel to a monitor.

## Webhook Signing

Webhook channels carry an auto-generated signing token that authenticates Holter to your receiver. Every outbound delivery is signed with HMAC-SHA256 and sent in the `X-Holter-Signature` header — the secret never travels the wire.

### Header format

```
X-Holter-Signature: t=<unix>,v1=<hex>
```

- `t=<unix>`: the dispatch timestamp as a Unix integer.
- `v1=<hex>`: lowercase hex of `HMAC-SHA256(token, "<unix>.<body>")`.

The leading timestamp lets you reject stale deliveries on the receiver side.

### Verifying a signature

Read the channel's signing token from the channel settings page (see [Managing the token](#managing-the-token) below), then on every incoming POST:

1. Read the `X-Holter-Signature` header and split it into `t` and `v1` parts.
2. Optionally reject the request if `t` is more than your tolerance window away from "now" (5 minutes is a reasonable default).
3. Compute `HMAC-SHA256(token, "<t>.<raw_body>")` and lowercase-hex encode it.
4. Compare in constant time with `v1`. Reject on mismatch.

Sample verifiers:

```js
// Node 18+
import crypto from "node:crypto"

function verify(rawBody, header, token, toleranceSec = 300) {
  const parts = Object.fromEntries(header.split(",").map((p) => p.split("=")))
  const t = Number(parts.t)
  if (!Number.isInteger(t)) return false
  if (Math.abs(Date.now() / 1000 - t) > toleranceSec) return false

  const expected = crypto
    .createHmac("sha256", token)
    .update(`${t}.${rawBody}`)
    .digest("hex")

  return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(parts.v1))
}
```

```python
# Python 3.6+
import hmac, hashlib, time

def verify(raw_body: bytes, header: str, token: str, tolerance_sec: int = 300) -> bool:
    parts = dict(p.split("=", 1) for p in header.split(","))
    try:
        t = int(parts["t"])
    except (KeyError, ValueError):
        return False
    if abs(time.time() - t) > tolerance_sec:
        return False

    signed = f"{t}.".encode() + raw_body
    expected = hmac.new(token.encode(), signed, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, parts.get("v1", ""))
```

```sh
# Quick check from the shell
printf '%s.%s' "$T" "$BODY" | openssl dgst -sha256 -hmac "$TOKEN"
```

Always verify against the **raw** request body — re-serialised JSON with reordered keys or different whitespace will not match.

### Managing the token

On the channel settings page, the **Webhook signing** section shows a "Show signing token" toggle. Click to reveal, **Copy** to copy the value to the clipboard, and **Regenerate** to rotate the token.

Rotation is **immediate**: once you confirm, the previous token stops working at the next dispatch. Update your receiver's stored copy before regenerating, or expect a brief window of failed verifications until both sides match.

::: danger Security disclaimer
The signing token is a shared secret between Holter and your receiver. If it leaks — emailed in plain text, committed to source control, captured by an unauthorised viewer of this page, etc. — anyone with the value can sign requests **indistinguishable from Holter's**. Holter cannot detect such leaks and has no recovery path other than regeneration.

You are responsible for protecting the value once it is generated. If you suspect the token has been exposed, **regenerate it immediately**.

If you lose the token (forgot to save it after creation, lost the password manager entry, etc.), you must regenerate it — Holter does not store the value in any retrievable form for you, and stores it only as the live signing key.

Holter accepts no liability for losses, breaches, or misuse resulting from a compromised or lost signing token.
:::

## Email Anti-phishing Code

Every email channel carries an auto-generated, human-readable code (e.g. `A7K9-X2B3`) drawn from a no-confusion alphabet (no `0`/`O`/`1`/`I`/`L`). The code is printed at the bottom of every email Holter sends through that channel:

```
Verification code: A7K9-X2B3
If you did not expect this email, do not trust messages claiming to be from
Holter that omit this code.
Do not forward this email to anyone you do not trust — the verification code
above is a shared secret that lets the recipient impersonate Holter.
```

Treat the code like a shared secret you can recognise at a glance: an email impersonating Holter that does not include this exact code is almost certainly a phishing attempt.

::: warning
**Do not forward Holter alerts to untrusted parties.** Anyone who reads the verification code above can craft a phishing email that passes your visual check. If you need to share an alert externally, redact the verification code line or paste only the relevant body text — never the full message including the footer.
:::

### Managing the code

On the channel settings page, the **Anti-phishing code** section shows a "Show anti-phishing code" toggle plus **Copy** and **Regenerate** buttons.

Rotation is **immediate**: the next email Holter sends through this channel will carry the new code. Recipients who memorised or saved the previous code will see the new one in the next email — train them again or warn them in advance.

::: danger Security disclaimer
The anti-phishing code is a shared visual secret. If it leaks (forwarded alerts, screenshots posted publicly, email archive exfiltration), anyone with the value can forge phishing emails that **pass your recipients' visual check**. Holter cannot detect such leaks and has no recovery path other than regeneration.

You are responsible for protecting the code once it is generated. If you suspect exposure, **regenerate it immediately**.

If you lose track of the current code, regenerate it — the next email will carry the new value, and you can train recipients on it.

Holter accepts no liability for losses, breaches, or phishing impersonation resulting from a compromised or lost anti-phishing code.
:::

## Email Address Verification

Every email channel must verify the address it points at before Holter delivers any alert through it. Without this gate, a workspace member could create an email channel pointing at a third party's inbox and use Holter to deliver tests or alerts there.

### How it works

1. Creating an email channel sends a verification email from the Holter info address to the target. The link in that email expires in 48 hours.
2. The recipient clicks the link and lands on a small confirmation page. The address is now marked **Verified** on the channel settings page.
3. Until verification completes, alerts targeting that address are dropped at the delivery layer. The channel still dispatches to **verified CC recipients**; if no addresses on the channel are verified, the dispatch is cancelled and recorded in the [delivery logs](channel-logs.md) with reason `no_verified_recipients`.

### Resending verification

Open the channel settings page. Below the channel name, the **Primary email verification** section shows the current state:

- **Verified** — alerts will be delivered to this address.
- **Pending verification** — alerts will not be delivered. Click **Resend verification** to send a fresh email; the previous link is invalidated.

::: danger Security disclaimer
Verification confirms only that *someone with access to the inbox* clicked the link. It does **not** prove the address belongs to the workspace, the team, or any specific individual. Treat email channels as best-effort delivery: anyone with the inbox open at click time will start receiving alerts.

If a recipient leaves the team or loses access to their inbox, **delete the channel or rotate the address and re-verify** — Holter has no way to invalidate verification automatically.
:::

## Deleting a Channel

On the channel list page, click **Delete** next to the channel. This removes the channel and all monitor links. Monitors linked to a deleted channel will no longer receive notifications for that channel.

## Linking Channels to Monitors

Channels own the link to monitors. To connect a channel to one or more monitors:

1. Open the channel settings page.
2. In the **Linked Monitors** section, check each monitor that should trigger notifications through this channel.
3. Click **Save Changes**.

Unchecking a monitor and saving immediately stops future notifications for that monitor through this channel.

You can also manage links via the API — include a `notification_channel_ids` array in the monitor create or update request body.

## Payload Shape

When a monitor goes down or recovers, Holter sends the following JSON payload to webhook channels:

```json
{
  "version": "1",
  "event": "monitor_down",
  "timestamp": "2026-04-20T10:00:00Z",
  "monitor": {
    "id": "...",
    "url": "https://example.com",
    "method": "get"
  },
  "incident": {
    "id": "...",
    "type": "downtime",
    "started_at": "2026-04-20T10:00:00Z",
    "resolved_at": null
  }
}
```

Events: `monitor_down`, `monitor_up`. For SSL expiry incidents the event is `ssl_expiry_down` / `ssl_expiry_up`.

## Related

- [Monitoring module](../monitoring/index.md) — incidents that trigger delivery
- [API reference](../../api/openapi.yml) — REST endpoints for notification channels

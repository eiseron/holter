# Log Detail

The Log Detail page shows the full evidence captured during a single check run.

## Accessing the Page

Click **View Details** on any row in the [Technical Logs](logs.md) list, or navigate to `/monitoring/logs/{log_id}`.

## Header

The header shows:

- **Status badge** — the check result (UP, DOWN, DEGRADED, etc.)
- **Latency** — response time in milliseconds
- **Region** — the datacenter region from which the check was executed
- **Checked at** — exact timestamp of the check

## Redirect Chain

When the monitor is configured to follow redirects and the server redirected the request, a numbered list shows each hop:

| Field | Description |
|-------|-------------|
| URL | The URL at this hop |
| IP Address | The resolved IP address |
| Status Code | HTTP status code returned at this hop |

The final entry is the destination response.

## Error Message

If the check failed with a network error (e.g. connection refused, DNS failure, timeout) or an unexpected HTTP error, the error message is shown here.

## Response Headers

The HTTP response headers returned by the server, formatted as a JSON object.

## Content Snippet

The first portion of the response body (up to 100 KB). If the body is valid JSON it is formatted for readability; otherwise it is shown as plain text.

## Monitor Configuration Snapshot

The configuration of the monitor at the time of the check (URL, method, timeout, keywords, etc.). This snapshot is immutable — changing the monitor settings later does not alter historical log entries.

## Inherited Evidence

When the response body is identical to the immediately preceding check, the system records the evidence once and marks subsequent logs as inheriting it. An **Inherited evidence** notice appears with a link to the original log entry where the full content is stored. This reduces storage without losing any information.

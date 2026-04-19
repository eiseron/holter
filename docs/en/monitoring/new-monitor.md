---
title: New Monitor
description: Create a monitor and configure its URL, method, keywords, SSL settings, and check schedule.
---

# New Monitor

The New Monitor form lets you configure a URL to be checked on a recurring schedule.

## Accessing the Form

Click **New Monitor** on the Dashboard, or navigate directly to `/monitoring/workspaces/{workspace_slug}/monitor/new`.

If your workspace is at quota, the button is disabled. Delete or archive an existing monitor first.

## Technical Settings

| Field | Description |
|-------|-------------|
| URL | The full HTTP or HTTPS address to check. Must start with `http://` or `https://`. |
| Method | HTTP method: GET, POST, PUT, PATCH, DELETE, HEAD. |
| Timeout | Maximum seconds to wait for a response before marking the check as failed. |
| Follow Redirects | When enabled, the checker follows HTTP redirects. Disable to assert an exact status code at the given URL. |
| Max Redirects | Maximum number of redirects to follow (only visible when Follow Redirects is on). |
| Request Body | Request payload sent with the request (only visible for POST, PUT, PATCH). |
| Headers | Custom HTTP headers as a JSON object, e.g. `{"Authorization": "Bearer token"}`. |
| Positive Keywords | Words separated by commas or semicolons that must appear in the response body. A missing keyword marks the check as failed. |
| Negative Keywords | Words separated by commas or semicolons that must **not** appear in the response body. A found keyword marks the check as failed. |

## Security Settings

| Field | Description |
|-------|-------------|
| Ignore SSL Errors | When enabled, SSL certificate issues (expired, invalid, self-signed) do not cause check failures. Useful for internal services with self-signed certs. |

## Interval Settings

| Field | Description |
|-------|-------------|
| Check Interval | How often the monitor runs, in seconds. The minimum allowed interval is set by your workspace plan. |
| State | Initial state: **Active** (checks run immediately) or **Paused** (monitoring suspended). |

## Validation

The form validates in real time as you type. Errors appear inline below each field. The **Create Monitor** button is disabled until all required fields are valid.

## After Creation

On success, you are redirected to the Dashboard. The new monitor begins checking on the next dispatch cycle (within one minute for active monitors).

# Contributing to Holter

Project conventions for AI agents are in [AGENTS.md](AGENTS.md) and `agents/`.
This file documents conventions used by humans during issue triage and review.

## Issue labels

Issues are classified along **module** lines using two complementary scopes:

- `domain:*` — vertical DDD slices that span the full stack (API, UI, docs,
  persistence, tests). An issue belongs to a domain when its scope is bounded
  by that domain's ubiquitous language.
- `app:*` — application-wide concerns that don't fit inside any one domain.
  Cross-cutting infrastructure (build, layout chrome, locale plumbing,
  external machine interfaces).

Layers (API, UI, docs) are **not** labels — they're slices of every domain.
An API change inside a domain stays under the domain label, not under a
hypothetical `module:api`.

### Domains

| Label | Scope |
|---|---|
| `domain:delivery` | Notification channels, webhooks, email — outbound messaging surface. |
| `domain:monitoring` | Monitors, checks, incidents, charts — observation surface. |
| `domain:accounts` | Identity, ownership, account-level confirmations. |

### Application-level

| Label | Scope |
|---|---|
| `app:build` | CI/CD, releases, GitHub mirror sync. |
| `app:docs` | Docs site infrastructure (release logs, publish workflow). In-domain documentation stays under the domain. |
| `app:i18n` | Global locale infrastructure (LocalePlug, language selector). Domain-specific copy stays inside the domain. |
| `app:ui` | App shell, layout, cross-domain UX patterns. Domain-specific UI stays inside the domain. |
| `app:integration` | External machine interfaces — SDK, CLI, MCP — that expose the API surface to outside agents. |
| `app:architecture` | Codebase-wide patterns: ubiquitous language, layering, module boundaries. |

### Rules

- **Multiple `domain:*` labels are allowed** when an issue genuinely cuts
  across domains (e.g. linking a delivery channel to a specific monitor
  carries both `domain:delivery` and `domain:monitoring`). Resist using
  multi-domain labels as a substitute for splitting the issue.
- **`app:*` and `domain:*` rarely co-occur.** If you need both, the issue is
  probably two issues — extract the cross-cutting half into its own.
- **No layer labels.** API/UI/docs are dimensions of every domain, not
  modules. Don't introduce `module:api`, `module:ui`, etc.
- **No `type:bug` / `type:feature`.** Issue type lives in GitLab's native
  issue type field, not in labels.

# Holter DRY Rules

This document defines the project-specific "Don't Repeat Yourself" rules for `holter`, extending the global [Eiseron DRY Standards](https://github.com/eiseron/eiseron-agents/blob/main/skills/11-dry-standards.md).

## 1. Phoenix & LiveView Abstractions
- **Layouts:** Always use `<Layouts.app>` as defined in `project_specializations.md`.
- **Components:** Favor `CoreComponents` for common UI elements.
- **Form Handling:** Always use `to_form/2` and the `@form` assign as specified in the local Phoenix guidelines.

## 2. Domain Abstractions
- **Shared Logic:** Extract re-usable business logic into the `Holter` core module (e.g., `lib/holter/`) and expose it through a clear internal API.
- **HTTP Client:** Use `Req` exclusively as the HTTP client. Avoid duplicating client configurations.

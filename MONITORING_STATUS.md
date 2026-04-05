# Monitoring Domain Status

Current status of the Multi-Tenant Monitoring implementation.

## Features
- [x] **Workspace Refactoring**: All monitoring resources are now scoped to a `Workspace` entity.
- [x] **Merged Limits**: Tenant limit fields (`retention_days`, `max_monitors`, `min_interval_seconds`) are merged into the `Workspace` schema to simplify architecture.
- [x] **REST API v1**: Clean route structure at `/api/v1/workspaces/:workspace_slug/monitors`.
- [x] **LiveView Dashboard**: Modernized dashboard at `/monitoring/workspaces/:workspace_slug/dashboard`.
- [x] **OpenAPI Documentation**: Automatically generated spec at `docs/openapi.yml`.
- [x] **Automated Testing**: 100% pass rate for all 183 business and system tests.

## API Specification
The API follows the OpenAPI 3.0 standard. You can view the full specification in [docs/openapi.yml](file:///home/guilherme/Documents/eiseron/holter/docs/openapi.yml).

### Interactive Documentation
In development mode, you can access the interactive Swagger UI at:
- `http://localhost:4000/api/swagger`
- `http://localhost:4000/api/openapi` (JSON Spec)

## Database Schema
- **Workspaces**: `id` (UUID), `name`, `slug` (Unique/Indexed), `retention_days`, `max_monitors`, `min_interval_seconds`.
- **Monitors**: Belong to `Workspace`.

## Implementation Details
- **Slug-based Routing**: Workspaces are identified by their immutable `slug` in the URL.
- **DDD Alignment**: Pragmatic approach with `Workspace` inside the `Monitoring` domain as the primary tenant.
- **REST Logic**: Unified in `HolterWeb.MonitorController` with `v1` prefix.
- **JSON Formatting**: Handled by `MonitorJSON` and `ChangesetJSON`.

---
*Updated: 2026-04-05 (Workspace Refactoring Complete)*

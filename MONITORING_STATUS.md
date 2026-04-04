# Monitoring Domain Status

Current status of the Multi-Tenant Monitoring implementation.

## Features
- [x] **Multi-Tenancy**: All monitors are scoped to an `Organization`.
- [x] **LiveView Dashboard**: Scoped to `/orgs/:org_slug/monitoring/dashboard`.
- [x] **REST API**: Full CRUD support for Monitors at `/api/orgs/:org_slug/monitoring/monitors`.
- [x] **Pagination & Filtering**: API supports `page`, `page_size`, `health_status`, and `logical_state`.
- [x] **OpenAPI Documentation**: Automatically generated spec at `docs/openapi.yml`.
- [x] **Automated Testing**: 100% pass rate for all 174 business tests.

## API Specification
The API follows the OpenAPI 3.0 standard. You can view the full specification in [docs/openapi.yml](file:///home/guilherme/Documents/eiseron/holter/docs/openapi.yml).

### Interactive Documentation
In development mode, you can access the interactive Swagger UI at:
- `http://localhost:4000/api/swagger`
- `http://localhost:4000/api/openapi` (JSON Spec)

## Database Schema
- **Organizations**: `id` (UUID), `name`, `slug` (Unique/Indexed).
- **Monitors**: Belong to `Organization`.
- **TenantLimits**: Belong to `Organization`.

## Implementation Details
- **Slug-based Routing**: Organizations are identified by their immutable `slug` in the URL.
- **REST Logic**: Implemented in `HolterWeb.MonitorController` with `action_fallback` to `FallbackController`.
- **JSON Formatting**: Handled by `MonitorJSON` and `ChangesetJSON`.
- **Validation**: Strict schema validation with `OpenApiSpex`.

---
*Updated: 2026-04-03*

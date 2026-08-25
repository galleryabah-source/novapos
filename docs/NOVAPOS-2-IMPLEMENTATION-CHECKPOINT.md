# NovaPOS 2.0 — Backend Foundation Checkpoint

## Implemented on this branch

- Modular Express application entrypoint.
- Environment validation.
- Server-only Supabase client.
- Bearer-token authentication middleware.
- Organization membership scope.
- Outlet scope.
- Centralized 404/error handling.
- Health and database readiness endpoints.
- Organization-scoped product read endpoints.
- Atomic checkout endpoint backed by PostgreSQL RPC.
- Foundation PostgreSQL schema migration.
- Inventory movement ledger.
- Idempotency constraint and atomic checkout design.
- Initial RLS policies for authenticated direct access.

## Intentionally not done yet

- No production database migration has been executed by this repository change.
- No credentials are committed.
- No frontend has been rebuilt yet.
- No payment gateway integration is enabled.
- No automated CI workflow has been added yet.
- No production deployment has been declared.

## Required next gates

1. Install dependencies and run tests locally/CI.
2. Validate SQL syntax and migration order against a disposable Supabase/PostgreSQL database.
3. Add role/permission matrix tests.
4. Add tenant/outlet isolation integration tests.
5. Add concurrent checkout/inventory tests.
6. Add audit and idempotency regression tests.
7. Review migration and RLS policies before execution.
8. Only after all critical tests pass, merge to `main` and execute migrations through the approved environment.

## GO/NO-GO

Current branch status: **NO-GO for production**.

Reason: foundation code exists, but database execution, integration tests, security regression and deployment verification are still outstanding.

# NovaPOS 2.0 — Backend & Database Foundation

Status: **FOUNDATION SPECIFICATION — NOT YET MIGRATED**

This document is the implementation guardrail for the NovaPOS backend/database foundation.

## Objectives

1. Make the server the source of truth for business transactions.
2. Establish organization and outlet isolation from the beginning.
3. Use PostgreSQL/Supabase as the transactional source of truth.
4. Make inventory auditable through an append-only movement ledger.
5. Make sales idempotent and atomic.
6. Keep AI out of the MVP critical path.
7. Require tests and security gates before production.

## Architecture

```text
Web/POS Client
    -> HTTPS
Express API
    -> authentication / authorization / validation
Domain services
    -> Supabase/PostgreSQL
    -> atomic SQL RPC for critical transactions
PostgreSQL
    -> transactional tables
    -> inventory ledger
    -> audit log
    -> reporting views
```

## Rules

- `products` is catalog data. It is NOT the stock source of truth.
- `inventories` represents current stock by outlet/product.
- `inventory_movements` is the stock ledger.
- Sales, payments, stock changes and audit events for a checkout must commit atomically.
- Every critical write must have an idempotency key where retries are possible.
- Every request must be scoped to an authenticated organization and, where applicable, outlet.
- Authorization is server-side. Hiding UI controls is not authorization.
- Database migrations are reviewed artifacts. They are not executed automatically by this repository change.
- Service-role credentials must never reach a browser/client bundle.

## Initial domain model

- organizations
- profiles
- organization_members
- outlets
- categories
- products
- inventories
- inventory_movements
- customers
- sales
- sale_items
- payments
- idempotency_keys
- audit_logs

Future domains: suppliers, purchases, returns, loyalty, cash shifts, transfers, subscriptions, analytics materialization.

## Checkout contract

Client submits product identifiers, quantities, payment method and an idempotency key. The server resolves authoritative product prices and inventory, validates the organization/outlet scope, locks relevant inventory rows, calculates totals, creates the sale/payment/ledger/audit records and commits as one PostgreSQL transaction.

A repeated idempotency key must return the original transaction rather than create a duplicate sale.

## Inventory invariant

For each `(outlet_id, product_id)`:

`inventory.quantity >= 0`

Every stock-changing event must produce one corresponding `inventory_movements` record. Reconciliation must be possible from the ledger.

## Security baseline

- Bearer token authentication via Supabase Auth.
- Organization membership required for protected endpoints.
- Outlet access checked for outlet-scoped operations.
- Strict CORS allowlist from environment configuration.
- JSON body size limit.
- Rate limiting at the API edge/middleware layer.
- Consistent error envelope; no stack traces or secrets in production responses.
- Audit critical mutations.

## Production gates

Before production:

- build PASS
- lint PASS
- unit tests PASS
- database migration validation PASS
- authentication PASS
- RBAC/tenant isolation PASS
- inventory concurrency PASS
- transaction/idempotency PASS
- audit integrity PASS
- health/readiness PASS
- production smoke test PASS

If any critical gate fails: **NO-GO**.

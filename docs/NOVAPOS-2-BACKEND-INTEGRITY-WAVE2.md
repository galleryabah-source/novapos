# NovaPOS 2.0 — Backend Integrity Wave 2

## Purpose

This document records the backend hardening rules implemented before NovaPOS is allowed into production.

## Request pipeline

`Request Context → CORS/Body Limits/Rate Limit → Authentication → Organization Scope → Outlet Scope → Permission → Domain Validation → Database Transaction → Audit`

Every mutation must preserve this ordering unless an Architecture Decision Record explicitly approves an exception.

## Authorization

Authorization is deny-by-default. The current permission matrix is enforced server-side. UI visibility is not an authorization mechanism.

Roles:

- `owner`
- `admin`
- `manager`
- `cashier`
- `inventory_operator`
- `viewer`
- `auditor`

## Checkout invariants

1. Organization, outlet and cashier must be valid.
2. Customer, when supplied, must belong to the same organization.
3. Every product must be active and belong to the same organization.
4. Every checkout item must have a positive quantity.
5. Duplicate products in one payload are rejected.
6. Inventory rows are locked before stock validation.
7. Inventory locks are acquired in deterministic product order.
8. Negative stock is rejected by business logic and database constraints.
9. Payment method must be from the supported allow-list.
10. Payment must cover the calculated server-side total.
11. Sale, sale items, payment, inventory update, inventory movement and audit event commit atomically.
12. A retry with the same organization/idempotency key returns the original result.

## Concurrency strategy

The checkout function uses a transaction-scoped advisory lock for the organization/idempotency key and row locks for inventory. This closes the most important duplicate-request race and reduces deadlock risk for multi-item sales by locking products in deterministic order.

## Inventory ledger

`inventories.quantity` is the operational current quantity. `inventory_movements.quantity_delta` is the audit ledger. The `inventory_reconciliation` view exposes variance between the current quantity and ledger-derived quantity.

A non-zero reconciliation variance is a data-integrity incident and must not be silently corrected by application code.

## Database boundary rules

Organization and outlet relationships are checked at the database boundary for sales, inventory and inventory movements. These checks supplement—not replace—application authorization and RLS.

## Production gates

NovaPOS remains **NO-GO** until all of the following pass against a disposable PostgreSQL/Supabase environment:

- migration apply/rollback validation
- unit tests
- API integration tests
- RBAC negative tests
- cross-organization isolation tests
- cross-outlet isolation tests
- concurrent checkout tests
- idempotency retry tests
- rollback tests
- inventory reconciliation tests
- RLS tests
- production smoke test

## Migration policy

Migration files are review artifacts until explicitly approved. Never execute these migrations against production merely because they exist in Git.

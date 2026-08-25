# NovaPOS 2.0 Development Guide

This repository is being evolved into NovaPOS 2.0: a production-grade Smart POS and Business Intelligence platform.

## Current engineering direction

- Backend: Node.js + Express
- Database: PostgreSQL through Supabase
- Auth: Supabase Auth bearer tokens
- Multi-tenant model: organization -> outlet
- Inventory source of truth: inventories + inventory_movements
- Critical checkout: atomic PostgreSQL RPC
- AI: optional and outside the MVP critical path

## Read first

1. `docs/NOVAPOS-2-BACKEND-FOUNDATION.md`
2. `docs/NOVAPOS-2-IMPLEMENTATION-CHECKPOINT.md`
3. `database/migrations/001_novapos_v2_foundation.sql`
4. `database/migrations/002_atomic_checkout.sql`

## Important

The migration files are reviewed artifacts. They must be validated against a disposable database before execution in any real environment.

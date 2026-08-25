-- NovaPOS 2.0 foundation schema
-- REVIEW ONLY: execute through the approved Supabase migration workflow.

create extension if not exists pgcrypto;

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  status text not null default 'active' check (status in ('active','suspended','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','manager','cashier','inventory_operator','viewer','auditor')),
  status text not null default 'active' check (status in ('active','invited','suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

create table if not exists public.outlets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  code text not null,
  address text,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  slug text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, slug)
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  sku text not null,
  barcode text,
  name text not null,
  description text,
  unit text not null default 'pcs',
  sell_price numeric(14,2) not null default 0 check (sell_price >= 0),
  cost_price numeric(14,2) not null default 0 check (cost_price >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, sku)
);

create unique index if not exists products_org_barcode_uq
  on public.products(organization_id, barcode)
  where barcode is not null;

create table if not exists public.inventories (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  outlet_id uuid not null references public.outlets(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity numeric(14,3) not null default 0 check (quantity >= 0),
  reserved_quantity numeric(14,3) not null default 0 check (reserved_quantity >= 0),
  reorder_level numeric(14,3) not null default 0 check (reorder_level >= 0),
  updated_at timestamptz not null default now(),
  unique (outlet_id, product_id)
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  phone text,
  email text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  outlet_id uuid not null references public.outlets(id) on delete restrict,
  customer_id uuid references public.customers(id) on delete set null,
  cashier_id uuid not null references auth.users(id) on delete restrict,
  sale_number text not null,
  status text not null default 'completed' check (status in ('completed','voided','refunded','pending')),
  subtotal numeric(14,2) not null check (subtotal >= 0),
  discount numeric(14,2) not null default 0 check (discount >= 0),
  tax numeric(14,2) not null default 0 check (tax >= 0),
  total numeric(14,2) not null check (total >= 0),
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  unique (organization_id, sale_number),
  unique (organization_id, idempotency_key)
);

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity numeric(14,3) not null check (quantity > 0),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  discount numeric(14,2) not null default 0 check (discount >= 0),
  line_total numeric(14,2) not null check (line_total >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  method text not null check (method in ('cash','card','bank_transfer','qris','ewallet','other')),
  amount numeric(14,2) not null check (amount > 0),
  reference text,
  created_at timestamptz not null default now()
);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  outlet_id uuid not null references public.outlets(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  movement_type text not null check (movement_type in ('opening','purchase','sale','return_in','return_out','adjustment_in','adjustment_out','transfer_in','transfer_out','opname')),
  quantity_delta numeric(14,3) not null check (quantity_delta <> 0),
  reference_type text,
  reference_id uuid,
  actor_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.idempotency_keys (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  key text not null,
  endpoint text not null,
  response jsonb,
  status_code integer,
  created_at timestamptz not null default now(),
  unique (organization_id, key, endpoint)
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  request_id text,
  ip_address inet,
  user_agent text,
  created_at timestamptz not null default now()
);

create index if not exists idx_members_user on public.organization_members(user_id);
create index if not exists idx_outlets_org on public.outlets(organization_id);
create index if not exists idx_products_org on public.products(organization_id);
create index if not exists idx_inventory_org_outlet on public.inventories(organization_id, outlet_id);
create index if not exists idx_inventory_movements_product on public.inventory_movements(organization_id, outlet_id, product_id, created_at desc);
create index if not exists idx_sales_org_outlet_created on public.sales(organization_id, outlet_id, created_at desc);
create index if not exists idx_sales_customer on public.sales(customer_id, created_at desc);
create index if not exists idx_audit_org_created on public.audit_logs(organization_id, created_at desc);

-- Prevent a product from referencing a category belonging to another organization.
create or replace function public.validate_product_org()
returns trigger
language plpgsql
as $$
begin
  if new.category_id is not null and not exists (
    select 1 from public.categories c
    where c.id = new.category_id and c.organization_id = new.organization_id
  ) then
    raise exception 'category organization mismatch';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_validate_product_org on public.products;
create trigger trg_validate_product_org
before insert or update on public.products
for each row execute function public.validate_product_org();

-- Prevent inventory rows from crossing organization boundaries.
create or replace function public.validate_inventory_org()
returns trigger
language plpgsql
as $$
begin
  if not exists (select 1 from public.outlets o where o.id = new.outlet_id and o.organization_id = new.organization_id) then
    raise exception 'outlet organization mismatch';
  end if;
  if not exists (select 1 from public.products p where p.id = new.product_id and p.organization_id = new.organization_id) then
    raise exception 'product organization mismatch';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_validate_inventory_org on public.inventories;
create trigger trg_validate_inventory_org
before insert or update on public.inventories
for each row execute function public.validate_inventory_org();

-- RLS is enabled for future direct Supabase access. The backend may use the service role,
-- but it must still enforce organization/outlet authorization in application code.
alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.organization_members enable row level security;
alter table public.outlets enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.inventories enable row level security;
alter table public.customers enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.payments enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.idempotency_keys enable row level security;
alter table public.audit_logs enable row level security;

-- Policy helper. SECURITY DEFINER is deliberately not used here; the policy remains
-- dependent on authenticated membership and can be reviewed independently.
create or replace function public.is_org_member(target_org uuid)
returns boolean
language sql
stable
security invoker
as $$
  select exists (
    select 1 from public.organization_members m
    where m.organization_id = target_org
      and m.user_id = auth.uid()
      and m.status = 'active'
  );
$$;

create policy organizations_member_select on public.organizations
for select to authenticated using (public.is_org_member(id));

create policy members_self_or_org_select on public.organization_members
for select to authenticated using (user_id = auth.uid() or public.is_org_member(organization_id));

create policy outlets_member_select on public.outlets
for select to authenticated using (public.is_org_member(organization_id));

create policy categories_member_select on public.categories
for select to authenticated using (public.is_org_member(organization_id));

create policy products_member_select on public.products
for select to authenticated using (public.is_org_member(organization_id));

create policy inventories_member_select on public.inventories
for select to authenticated using (public.is_org_member(organization_id));

create policy customers_member_select on public.customers
for select to authenticated using (public.is_org_member(organization_id));

create policy sales_member_select on public.sales
for select to authenticated using (public.is_org_member(organization_id));

create policy sale_items_member_select on public.sale_items
for select to authenticated using (
  exists (select 1 from public.sales s where s.id = sale_id and public.is_org_member(s.organization_id))
);

create policy payments_member_select on public.payments
for select to authenticated using (
  exists (select 1 from public.sales s where s.id = sale_id and public.is_org_member(s.organization_id))
);

create policy inventory_movements_member_select on public.inventory_movements
for select to authenticated using (public.is_org_member(organization_id));

create policy audit_logs_member_select on public.audit_logs
for select to authenticated using (public.is_org_member(organization_id));

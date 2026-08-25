-- NovaPOS 2.0 deep integrity hardening.
-- REVIEW ONLY. Execute only through the approved database migration workflow.

-- Prevent duplicate products in a single checkout payload and serialize retries
-- for the same organization/idempotency key before checking for an existing sale.
-- Advisory locks are transaction-scoped and do not survive COMMIT.

create or replace function public.create_sale_transaction(
  p_organization_id uuid,
  p_outlet_id uuid,
  p_cashier_id uuid,
  p_customer_id uuid,
  p_idempotency_key text,
  p_items jsonb,
  p_payment_method text,
  p_payment_amount numeric
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_sale_id uuid;
  v_sale_number text;
  v_subtotal numeric(14,2) := 0;
  v_total numeric(14,2) := 0;
  v_payment_amount numeric(14,2);
  v_item jsonb;
  v_product_id uuid;
  v_quantity numeric(14,3);
  v_unit_price numeric(14,2);
  v_line_total numeric(14,2);
  v_inventory_id uuid;
  v_current_stock numeric(14,3);
  v_existing jsonb;
  v_duplicate_count integer;
begin
  if p_organization_id is null or p_outlet_id is null or p_cashier_id is null then
    raise exception 'organization, outlet and cashier are required';
  end if;

  if p_idempotency_key is null or length(trim(p_idempotency_key)) < 8 or length(p_idempotency_key) > 128 then
    raise exception 'invalid idempotency key';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 200 then
    raise exception 'sale items must contain between 1 and 200 entries';
  end if;

  if p_payment_method is null or p_payment_method not in ('cash','card','bank_transfer','qris','ewallet','other') then
    raise exception 'invalid payment method';
  end if;

  if p_payment_amount is null or p_payment_amount <= 0 then
    raise exception 'payment amount must be positive';
  end if;

  -- Serialize concurrent retries using the same business key.
  perform pg_advisory_xact_lock(hashtextextended(p_organization_id::text || ':' || p_idempotency_key, 0));

  if not exists (
    select 1 from public.organization_members m
    where m.organization_id = p_organization_id
      and m.user_id = p_cashier_id
      and m.status = 'active'
      and m.role in ('owner','admin','manager','cashier')
  ) then
    raise exception 'cashier is not authorized for organization';
  end if;

  if not exists (
    select 1 from public.outlets o
    where o.id = p_outlet_id
      and o.organization_id = p_organization_id
      and o.status = 'active'
  ) then
    raise exception 'outlet is not valid for organization';
  end if;

  if p_customer_id is not null and not exists (
    select 1 from public.customers c
    where c.id = p_customer_id and c.organization_id = p_organization_id
  ) then
    raise exception 'customer organization mismatch';
  end if;

  select jsonb_build_object(
    'id', s.id,
    'sale_number', s.sale_number,
    'status', s.status,
    'subtotal', s.subtotal,
    'discount', s.discount,
    'tax', s.tax,
    'total', s.total,
    'created_at', s.created_at
  ) into v_existing
  from public.sales s
  where s.organization_id = p_organization_id
    and s.idempotency_key = p_idempotency_key;

  if v_existing is not null then
    return jsonb_build_object('idempotent', true, 'sale', v_existing);
  end if;

  select count(*) - count(distinct (value->>'product_id')) into v_duplicate_count
  from jsonb_array_elements(p_items);

  if v_duplicate_count > 0 then
    raise exception 'duplicate product in sale payload';
  end if;

  -- First pass: validate and lock every inventory row in deterministic product order.
  -- Deterministic locking reduces deadlock probability when two checkouts contain
  -- overlapping products in different client-side order.
  for v_item in
    select value
    from jsonb_array_elements(p_items)
    order by (value->>'product_id')
  loop
    begin
      v_product_id := (v_item->>'product_id')::uuid;
      v_quantity := (v_item->>'quantity')::numeric;
    exception when others then
      raise exception 'invalid product_id or quantity in sale payload';
    end;

    if v_quantity is null or v_quantity <= 0 or v_quantity > 100000 then
      raise exception 'invalid quantity for product %', v_product_id;
    end if;

    select p.sell_price into v_unit_price
    from public.products p
    where p.id = v_product_id
      and p.organization_id = p_organization_id
      and p.is_active = true;

    if not found then
      raise exception 'product % is not active or does not belong to organization', v_product_id;
    end if;

    select i.id, i.quantity
      into v_inventory_id, v_current_stock
    from public.inventories i
    where i.organization_id = p_organization_id
      and i.outlet_id = p_outlet_id
      and i.product_id = v_product_id
    for update;

    if not found then
      raise exception 'inventory record missing for product %', v_product_id;
    end if;

    if v_current_stock < v_quantity then
      raise exception 'insufficient stock for product %: available %, requested %', v_product_id, v_current_stock, v_quantity;
    end if;

    v_line_total := round(v_unit_price * v_quantity, 2);
    v_subtotal := v_subtotal + v_line_total;
  end loop;

  v_total := v_subtotal;
  v_payment_amount := p_payment_amount;

  if v_payment_amount < v_total then
    raise exception 'payment amount % is below total %', v_payment_amount, v_total;
  end if;

  v_sale_number := 'NP-' || to_char(current_date, 'YYYYMMDD') || '-' || lpad(nextval('public.sale_number_seq')::text, 8, '0');

  insert into public.sales (
    organization_id, outlet_id, customer_id, cashier_id,
    sale_number, status, subtotal, discount, tax, total, idempotency_key
  ) values (
    p_organization_id, p_outlet_id, p_customer_id, p_cashier_id,
    v_sale_number, 'completed', v_subtotal, 0, 0, v_total, p_idempotency_key
  ) returning id into v_sale_id;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_quantity := (v_item->>'quantity')::numeric;

    select p.sell_price into v_unit_price
    from public.products p
    where p.id = v_product_id and p.organization_id = p_organization_id;

    v_line_total := round(v_unit_price * v_quantity, 2);

    insert into public.sale_items (sale_id, product_id, quantity, unit_price, discount, line_total)
    values (v_sale_id, v_product_id, v_quantity, v_unit_price, 0, v_line_total);

    update public.inventories
    set quantity = quantity - v_quantity,
        updated_at = now()
    where organization_id = p_organization_id
      and outlet_id = p_outlet_id
      and product_id = v_product_id;

    insert into public.inventory_movements (
      organization_id, outlet_id, product_id, movement_type,
      quantity_delta, reference_type, reference_id, actor_user_id
    ) values (
      p_organization_id, p_outlet_id, v_product_id, 'sale',
      -v_quantity, 'sale', v_sale_id, p_cashier_id
    );
  end loop;

  insert into public.payments (sale_id, method, amount)
  values (v_sale_id, p_payment_method, v_payment_amount);

  insert into public.audit_logs (
    organization_id, actor_user_id, action, entity_type, entity_id, after_data
  ) values (
    p_organization_id, p_cashier_id, 'SALE_CREATED', 'sale', v_sale_id,
    jsonb_build_object('sale_number', v_sale_number, 'total', v_total, 'outlet_id', p_outlet_id)
  );

  return jsonb_build_object(
    'idempotent', false,
    'sale', jsonb_build_object(
      'id', v_sale_id,
      'sale_number', v_sale_number,
      'status', 'completed',
      'subtotal', v_subtotal,
      'discount', 0,
      'tax', 0,
      'total', v_total,
      'payment_amount', v_payment_amount,
      'change', round(v_payment_amount - v_total, 2)
    )
  );
end;
$$;

-- Stronger invariants for sales and payments.
create or replace function public.validate_sale_consistency()
returns trigger
language plpgsql
as $$
begin
  if not exists (
    select 1 from public.outlets o
    where o.id = new.outlet_id and o.organization_id = new.organization_id
  ) then
    raise exception 'sale outlet organization mismatch';
  end if;

  if new.customer_id is not null and not exists (
    select 1 from public.customers c
    where c.id = new.customer_id and c.organization_id = new.organization_id
  ) then
    raise exception 'sale customer organization mismatch';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_sale_consistency on public.sales;
create trigger trg_validate_sale_consistency
before insert or update on public.sales
for each row execute function public.validate_sale_consistency();

create or replace function public.validate_inventory_movement_consistency()
returns trigger
language plpgsql
as $$
begin
  if not exists (
    select 1 from public.outlets o
    where o.id = new.outlet_id and o.organization_id = new.organization_id
  ) then
    raise exception 'inventory movement outlet organization mismatch';
  end if;

  if not exists (
    select 1 from public.products p
    where p.id = new.product_id and p.organization_id = new.organization_id
  ) then
    raise exception 'inventory movement product organization mismatch';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_inventory_movement_consistency on public.inventory_movements;
create trigger trg_validate_inventory_movement_consistency
before insert or update on public.inventory_movements
for each row execute function public.validate_inventory_movement_consistency();

-- Reconciliation query for operational audits.
create or replace view public.inventory_reconciliation as
select
  i.organization_id,
  i.outlet_id,
  i.product_id,
  i.quantity as current_quantity,
  coalesce(sum(m.quantity_delta), 0)::numeric(14,3) as ledger_quantity,
  (i.quantity - coalesce(sum(m.quantity_delta), 0))::numeric(14,3) as variance
from public.inventories i
left join public.inventory_movements m
  on m.organization_id = i.organization_id
 and m.outlet_id = i.outlet_id
 and m.product_id = i.product_id
group by i.organization_id, i.outlet_id, i.product_id, i.quantity;

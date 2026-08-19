-------------------------------------------------------------------------------
-- Hatchery vaccination cost per chick
-- Function : hat_lot_cos_new
--
-- Replace the existing hat_lot_cos_new body (Ajay P[2274] 20260309) with this
-- version. If the function lives in a package, add the two optional parameters
-- to the package spec as well (defaults keep existing 3-argument calls valid).
--
-- Business rules
--   1. Normal broiler placement : actual vaccine cost of the hatchery WIP batch
--      (existing practice).
--   2. Chicks held at the hatchery : weighted average vaccine cost of the
--      previous three hatchery production days (pass p_held_yn = 'Y').
--   3. Offline / delayed farm-code : physical placement date and farm-code
--      creation date differ. Do not apply the empty hatchery batch created on
--      the farm-code date (that batch has no vaccine issues, so cost is zero).
--      Use the physical date's hatchery cost, or look back on the same lot, or
--      fall back to the 3-day weighted average.
--
-- Example (rule 3)
--   Physical placement 17-Jul-26, farm code created 21-Jul-26.
--   Old logic used the 21-Jul hatchery batch for the 17-Jul chicks. That batch
--   has no hatchery / vaccine cost, so BOTH the delayed 17-Jul farm AND the
--   genuine 21-Jul placements received ZERO vaccine cost.
--
-- Call
--   hat_lot_cos_new(p_hat_lot, p_hat_orgn_id, p_hatch_date)
--   hat_lot_cos_new(p_hat_lot, p_hat_orgn_id, p_hatch_date, 'Y')              -- held
--   hat_lot_cos_new(p_hat_lot, p_hat_orgn_id, p_hatch_date, 'N', p_phys_dt)  -- delayed
--
-- Run as APPS after compiling into the existing package / standalone function.
-- Walkthrough and test SQL: sql/hat_lot_cos_new_setup_notes.sql
-------------------------------------------------------------------------------

-- Package spec (add / replace). Skip this block if the function is standalone.
--
-- function hat_lot_cos_new(
--   p_hat_lot       varchar2,
--   p_hat_orgn_id   number,
--   p_hatch_date    date,
--   p_held_yn       varchar2 default 'N',
--   p_physical_date date    default null
-- ) return number;

create or replace function hat_lot_cos_new(
  p_hat_lot       varchar2,
  p_hat_orgn_id   number,
  p_hatch_date    date,
  p_held_yn       varchar2 default 'N',
  p_physical_date date    default null
) return number is

  -- 00 - 20260309 - Ajay P[2274] - Development: New Function For Vaccine Cost Calculation
  -- 01 - 20260819 - Hatchery vaccination cost: actual / 3-day WA / delayed farm-code

  c_chick_item_id  constant number := 25197;
  c_lookback_days  constant number := 10;
  c_wa_days        constant number := 3;

  l_ret_val        number := 0;
  l_from_date      date;
  l_to_date        date;
  l_phys_date      date;
  l_as_of_date     date;

  cursor cur_lot_batches(p_from date, p_to date) is
    select mtl.transaction_source_id
    from   mtl_transaction_lot_numbers mtl,
           mtl_material_transactions   mmt
    where  mtl.lot_number like p_hat_lot || '%'
    and    p_hat_lot is not null
    and    mtl.transaction_id = mmt.transaction_id
    and    mmt.transaction_type_id = 44
    and    mmt.organization_id = p_hat_orgn_id
    and    mmt.transaction_date between p_from and p_to
    group  by mtl.transaction_source_id;

  cursor cur_org_batches(p_from date, p_to date) is
    select mmt.transaction_source_id
    from   mtl_material_transactions mmt
    where  mmt.transaction_type_id = 44
    and    mmt.organization_id = p_hat_orgn_id
    and    mmt.inventory_item_id = c_chick_item_id
    and    mmt.transaction_date between p_from and p_to
    group  by mmt.transaction_source_id;

  cursor xb(l_batch number) is
    select item_no,
           item_id,
           organization_id,
           max(transaction_date) transaction_date,
           sum(med_qty) * -1 med_qty
    from   (select distinct mmt.transaction_id trans_id,
                            msi.segment1 item_no,
                            msi.inventory_item_id item_id,
                            mmt.organization_id,
                            (mmt.transaction_quantity) med_qty,
                            trunc(mmt.transaction_date) transaction_date
            from   mtl_material_transactions mmt,
                   mtl_system_items_b        msi,
                   mtl_item_categories       mic,
                   mtl_categories            mc
            where  mmt.transaction_type_id in (35, 43)
            and    mmt.transaction_source_type_id = 5
            and    mmt.inventory_item_id = msi.inventory_item_id
            and    msi.inventory_item_id = mic.inventory_item_id
            and    msi.organization_id = mic.organization_id
            and    mic.category_id = mc.category_id
            and    msi.organization_id = p_hat_orgn_id
            and    (p_hat_orgn_id <> 1433 or
                   (p_hat_orgn_id = 1433 and
                    msi.segment1 in
                    ('NDKILLEDGENTYP7', 'XNEL4GM', 'IBHKD1000', 'GENTAMINJ')))
            and    mc.segment1 in ('VACCINES', 'VACCINES.LIVE')
            and    mic.category_set_id = 1
            and    mmt.transaction_source_id = l_batch)
    group  by item_no, item_id, organization_id;

  function f_item_cost(p_item_id number, p_org_id number, p_date date)
    return number is
    l_cost number := 0;
  begin
    l_cost := sug_cst_pkg.getItemCost(p_item_id, p_org_id, p_date);
    if nvl(l_cost, 0) = 0 then
      l_cost := sug_cst_pkg.getItemCost(p_item_id, p_org_id, p_date - 30);
    end if;
    if nvl(l_cost, 0) = 0 then
      l_cost := sug_cst_pkg.getItemCost(p_item_id, p_org_id, p_date - 60);
    end if;
    return nvl(l_cost, 0);
  end f_item_cost;

  procedure add_batch(p_batch_id number,
                      io_tot_cost  in out number,
                      io_tot_chick in out number) is
    l_flag      number := 0;
    l_chick_qty number := 0;
    l_item_cost number := 0;
    l_qty_cost  number := 0;
  begin
    select nvl(sum(mmt.transaction_quantity), 0)
    into   l_chick_qty
    from   mtl_material_transactions mmt
    where  mmt.transaction_type_id = 44
    and    mmt.organization_id = p_hat_orgn_id
    and    mmt.inventory_item_id = c_chick_item_id
    and    mmt.transaction_source_id = p_batch_id;

    for j in xb(p_batch_id) loop
      l_item_cost := f_item_cost(j.item_id, j.organization_id, j.transaction_date);
      l_qty_cost  := j.med_qty * nvl(l_item_cost, 0);
      io_tot_cost := nvl(io_tot_cost, 0) + nvl(l_qty_cost, 0);
      l_flag      := 1;
    end loop;

    -- Only include chick qty when the batch actually issued vaccine.
    -- Empty delayed farm-code batches must not dilute / zero the rate.
    if l_flag = 1 then
      io_tot_chick := nvl(io_tot_chick, 0) + nvl(l_chick_qty, 0);
    end if;
  end add_batch;

  function f_rate(p_tot_cost number, p_tot_chick number) return number is
  begin
    if nvl(p_tot_chick, 0) <> 0 then
      return p_tot_cost / p_tot_chick;
    end if;
    return 0;
  end f_rate;

  -- Actual cost for this hatchery lot in a date window (rule 1).
  -- All matching WIP completion batches are used (not FETCH FIRST only).
  function f_lot_window_cost(p_from date, p_to date) return number is
    l_cost  number := 0;
    l_chick number := 0;
  begin
    for i in cur_lot_batches(p_from, p_to) loop
      add_batch(i.transaction_source_id, l_cost, l_chick);
    end loop;
    return f_rate(l_cost, l_chick);
  end f_lot_window_cost;

  -- Hatchery-level actual cost for a single production day.
  -- Batches with no vaccine issues are skipped (rule 3 dummy batch).
  function f_org_day_cost(p_date date) return number is
    l_cost  number := 0;
    l_chick number := 0;
    l_from  date := trunc(p_date);
    l_to    date := trunc(p_date) + 0.99999;
  begin
    for i in cur_org_batches(l_from, l_to) loop
      add_batch(i.transaction_source_id, l_cost, l_chick);
    end loop;
    return f_rate(l_cost, l_chick);
  end f_org_day_cost;

  -- Weighted average of the previous three hatchery production days (rule 2).
  -- Pooling vaccine value and chick qty is the chick-weighted average.
  function f_three_day_wa(p_as_of date) return number is
    l_cost  number := 0;
    l_chick number := 0;
    l_dcost number := 0;
    l_dchik number := 0;
    l_from  date;
    l_to    date;
  begin
    for d in 1 .. c_wa_days loop
      l_from  := trunc(p_as_of) - d;
      l_to    := trunc(p_as_of) - d + 0.99999;
      l_dcost := 0;
      l_dchik := 0;
      for i in cur_org_batches(l_from, l_to) loop
        add_batch(i.transaction_source_id, l_dcost, l_dchik);
      end loop;
      l_cost  := nvl(l_cost, 0) + nvl(l_dcost, 0);
      l_chick := nvl(l_chick, 0) + nvl(l_dchik, 0);
    end loop;
    return f_rate(l_cost, l_chick);
  end f_three_day_wa;

begin
  -- Cached non-zero rate (same GTT as the original function).
  -- Skip the cache for held / delayed calls so optional parameters can
  -- change the result for the same lot.
  if upper(trim(nvl(p_held_yn, 'N'))) <> 'Y'
     and p_physical_date is null then
    begin
      select a.rate
      into   l_ret_val
      from   sug_rpt_common_gtt a
      where  a.set_code = 'HAT_LOT_CST'
      and    a.organization_id = p_hat_orgn_id
      and    a.lot_number = p_hat_lot
      and    nvl(a.rate, 0) <> 0;
      return l_ret_val;
    exception
      when others then
        null;
    end;
  end if;

  if p_hat_lot is null or p_hat_orgn_id is null or p_hatch_date is null then
    return 0;
  end if;

  l_phys_date  := trunc(nvl(p_physical_date, p_hatch_date));
  l_as_of_date := trunc(p_hatch_date);

  -- Rule 2: held at hatchery — never use the current day's actual batch.
  if upper(trim(nvl(p_held_yn, 'N'))) = 'Y' then
    return f_three_day_wa(l_as_of_date);
  end if;

  -- Rule 3: delayed farm-code with a known physical placement date.
  -- Cost the chicks at the hatchery rate of the physical day, not the
  -- farm-code creation day's empty batch.
  if p_physical_date is not null
     and trunc(p_physical_date) <> trunc(p_hatch_date) then
    l_ret_val := f_org_day_cost(l_phys_date);
    if nvl(l_ret_val, 0) = 0 then
      l_ret_val := f_lot_window_cost(trunc(l_phys_date) - 1,
                                     trunc(l_phys_date) + 0.99999);
    end if;
    if nvl(l_ret_val, 0) = 0 then
      l_ret_val := f_three_day_wa(l_phys_date);
    end if;
    return nvl(l_ret_val, 0);
  end if;

  -- Rule 1: actual lot cost on hatch date (existing ±1 day window).
  l_from_date := trunc(p_hatch_date) - 1;
  l_to_date   := trunc(p_hatch_date) + 0.99999;
  l_ret_val   := f_lot_window_cost(l_from_date, l_to_date);

  -- Same lot produced earlier (offline placement, farm code delayed).
  -- Example: type 44 + vaccine issues on 17-Jul, function called with 21-Jul.
  if nvl(l_ret_val, 0) = 0 then
    l_ret_val := f_lot_window_cost(trunc(p_hatch_date) - c_lookback_days,
                                   trunc(p_hatch_date) + 0.99999);
  end if;

  -- Other hatchery batches on the same day (dummy empty batch on this lot).
  if nvl(l_ret_val, 0) = 0 then
    l_ret_val := f_org_day_cost(l_as_of_date);
  end if;

  -- Last resort: previous three days (also covers held chicks not flagged).
  if nvl(l_ret_val, 0) = 0 then
    l_ret_val := f_three_day_wa(l_as_of_date);
  end if;

  return nvl(l_ret_val, 0);
end hat_lot_cos_new;
/
show errors

-- Grant / synonym only if this is compiled as a standalone function.
-- Skip when the function is inside an existing package.
-- grant execute on hat_lot_cos_new to apps with grant option;

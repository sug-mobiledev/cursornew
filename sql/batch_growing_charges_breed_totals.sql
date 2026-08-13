-- Detail + Sub Total (per breed) + Grand Total
-- zone shows 'Sub Total' / 'Grand Total' on summary rows (as in report layout)
-- row_type: 1 = detail, 2 = sub total, 3 = grand total
-- color_grp kept for report print formatting only: 1 / 0 / -1

with a as
 (select nvl(g.attribute16, c.breed)                              as breed,
         c.branch_code,
         sum(feed_consumed)                                       as feed_consumed,
         sum(c.std_feed_cons_gm) / 1000                           as feed_consumption_std,
         sum(c.birds_lifted)                                      as birds_lifted,
         sum(nvl(c.chicks_housed, 0))                             as chicks_housed,
         sum(nvl(c.mortality_no, 0))                              as mort,
         sum(sug_live_farm_intake.sug_agewise_mort(c.mean_age - 7,
                                                    c.mean_age - 1,
                                                    c.batch_id,
                                                    c.hatch_date)) as mort7,
         sum(birds_weight)                                        as lifted_wt,
         sum(mean_age * birds_lifted) / sum(birds_lifted)         as mean_age,
         sum(nvl(c.mean_age, 0))                                  as mean_age_new,
         sum(chick_cost)                                          as ch,
         sum(nvl(feed_cost, 0))                                   as fc,
         sum(nvl(medic_cost, 0))                                  as mc,
         sum(nvl(admin_cost, 0))                                  as ac,
         sum(nvl(min_gc, 0))                                      as mgc,
         sum(earn_gc)                                             as earn_gc,
         sum(nvl(birds_lifted, 0))                                as sold_no,
         sum(nvl(birds_weight, 0))                                as sold_kgs,
         sum(nvl(c.add_gc, 0))                                    as add_gc,
         avg(nvl(return_feed_pct, 0))                             as feed_trt,
         count(distinct(c.farm_code))                             as no_of_farms,
         sum(c.avg_selling_price)                                 as avg_selling_price
    from sug_batch_growing_charges c,
         gme_batch_header          g,
         sug_organization_mv       d
   where 1 = 1
     and c.gc_date between l_from_date and l_to_date
     and c.status <> 'CANCELLED'
     and c.birds_weight <> 0
     and g.batch_id = c.batch_id
     and d.branch_code = c.branch_code
     and d.region_code not in ('RB', 'RD', 'GF')
     and d.ledger_id = cp_ledger_id
     and nvl(d.opm_zone, 'NA') = nvl(cp_zone, nvl(d.opm_zone, 'NA'))
     and d.region_id = nvl(cp_org_id, d.region_id)
     and nvl(d.cluster_name, 'NA') = nvl(cp_cluster, nvl(d.cluster_name, 'NA'))
     and d.branch_id = nvl(cp_orgn_id, d.branch_id)
     and exists
   (select 1
            from fnd_lookup_values a
           where 1 = 1
             and a.lookup_type = 'SUG_BREED_DETAILS'
             and a.enabled_flag = 'Y'
             and trunc(sysdate) between a.start_date_active and
                 nvl(a.end_date_active, trunc(sysdate))
             and ((p_group = 0 and a.attribute_category = 'Country Bird') or
                 (p_group = 1 and a.attribute_category <> 'Country Bird'))
             and a.lookup_code = nvl(g.attribute16, c.breed))
   group by nvl(g.attribute16, c.breed), c.branch_code),
mid as
 (select nvl(b.opm_zone, 'NA') as zone,
         b.zone_seq,
         b.region,
         b.region_code,
         b.branch_name,
         b.location_name,
         a.breed,
         a.feed_consumed,
         a.feed_consumption_std,
         a.birds_lifted,
         a.chicks_housed,
         a.mort,
         a.mort7,
         a.lifted_wt,
         a.mean_age,
         a.mean_age_new,
         a.ch,
         a.fc,
         a.mc,
         a.ac,
         a.mgc,
         a.earn_gc,
         a.sold_no,
         a.sold_kgs,
         a.add_gc,
         a.feed_trt,
         a.no_of_farms,
         a.avg_selling_price
    from a, sug_organization_mv b
   where b.branch_code(+) = a.branch_code),
agg as
 (
  /* ---------- DETAIL ---------- */
  select zone,
         zone_seq,
         region,
         region_code,
         branch_name,
         location_name,
         breed,
         breed as sort_breed,
         1 as row_type,
         sum(feed_consumed) as feed_consumed,
         sum(no_of_farms) as no_of_farms,
         sum(chicks_housed) as chicks_housed,
         round(((sum(feed_consumed) /
               sum(feed_consumption_std * sold_no)) * 100),
               2) as feed_intake_perc,
         round(sum(feed_consumed * 1000) / nullif(sum(sold_no), 0)) as feed_gms,
         round((avg(feed_consumed) / nullif(avg(sold_kgs), 0)) +
               (2 - (avg(sold_kgs) / nullif(avg(sold_no), 0))) / 0.04 * 0.01,
               2) as cfcr,
         round(avg(sold_kgs) / nullif(avg(sold_no), 0), 2) as avg_wt,
         round((avg(mean_age_new * sold_no)) / nullif(avg(sold_no), 0)) as mean_age,
         round(((sum(lifted_wt) / nullif(sum(birds_lifted), 0)) /
               nullif((avg(mean_age_new * sold_no) / nullif(avg(sold_no), 0)), 0)) * 1000,
               2) as day_gain,
         round(avg(mort) / nullif(avg(chicks_housed), 0) * 100, 2) as mort_perc,
         round(avg(mort7) / nullif(avg(chicks_housed), 0) * 100, 2) as mort_perc7,
         round(((((100 - ((sum(mort) / nullif(sum(chicks_housed), 0)) * 100)) *
               (sum(lifted_wt) / nullif(sum(birds_lifted), 0))) /
               nullif(((sum(mean_age * birds_lifted) / nullif(sum(birds_lifted), 0)) *
               (sum(feed_consumed) / nullif(sum(lifted_wt), 0))),
                      0)) * 100),
               2) as eef,
         sug_gn.round_2(avg(mc) / nullif(avg(sold_kgs), 0)) as med_cost,
         round((avg(fc) + avg(mc) + avg(ch) + avg(ac) + avg(mgc)) /
               nullif(avg(sold_kgs), 0),
               2) as prod_cost,
         round(sum(earn_gc) / nullif(sum(sold_kgs), 0), 2) as actual_gc,
         round(sum(add_gc) / nullif(sum(sold_kgs), 0), 2) as add_gc_per_kg,
         round((sum(earn_gc) + sum(add_gc)) / nullif(sum(sold_kgs), 0), 2) as tot_gc_per_kg,
         sum(sold_no) as no_of_birds_sold,
         sum(sold_kgs) as no_of_kg_sold,
         round(avg(feed_trt), 2) as return_feed_perc,
         sum(sold_kgs * avg_selling_price) / nullif(sum(sold_kgs), 0) as avg_sales_price,
         sum(mean_age_new) as mean_age_new,
         sum(birds_lifted) as birds_lifted,
         sum(lifted_wt) as lifted_wt,
         avg(mort) as mort
    from mid
   group by zone,
            zone_seq,
            region,
            region_code,
            branch_name,
            location_name,
            breed

  union all

  /* ---------- SUB TOTAL (per breed) ---------- */
  select 'Sub Total' as zone,
         null as zone_seq,
         null as region,
         null as region_code,
         null as branch_name,
         null as location_name,
         null as breed,
         breed as sort_breed,
         2 as row_type,
         sum(feed_consumed) as feed_consumed,
         sum(no_of_farms) as no_of_farms,
         sum(chicks_housed) as chicks_housed,
         round(((sum(feed_consumed) /
               sum(feed_consumption_std * sold_no)) * 100),
               2) as feed_intake_perc,
         round(sum(feed_consumed * 1000) / nullif(sum(sold_no), 0)) as feed_gms,
         round((avg(feed_consumed) / nullif(avg(sold_kgs), 0)) +
               (2 - (avg(sold_kgs) / nullif(avg(sold_no), 0))) / 0.04 * 0.01,
               2) as cfcr,
         round(avg(sold_kgs) / nullif(avg(sold_no), 0), 2) as avg_wt,
         round((avg(mean_age_new * sold_no)) / nullif(avg(sold_no), 0)) as mean_age,
         round(((sum(lifted_wt) / nullif(sum(birds_lifted), 0)) /
               nullif((avg(mean_age_new * sold_no) / nullif(avg(sold_no), 0)), 0)) * 1000,
               2) as day_gain,
         round(avg(mort) / nullif(avg(chicks_housed), 0) * 100, 2) as mort_perc,
         round(avg(mort7) / nullif(avg(chicks_housed), 0) * 100, 2) as mort_perc7,
         round(((((100 - ((sum(mort) / nullif(sum(chicks_housed), 0)) * 100)) *
               (sum(lifted_wt) / nullif(sum(birds_lifted), 0))) /
               nullif(((sum(mean_age * birds_lifted) / nullif(sum(birds_lifted), 0)) *
               (sum(feed_consumed) / nullif(sum(lifted_wt), 0))),
                      0)) * 100),
               2) as eef,
         sug_gn.round_2(avg(mc) / nullif(avg(sold_kgs), 0)) as med_cost,
         round((avg(fc) + avg(mc) + avg(ch) + avg(ac) + avg(mgc)) /
               nullif(avg(sold_kgs), 0),
               2) as prod_cost,
         round(sum(earn_gc) / nullif(sum(sold_kgs), 0), 2) as actual_gc,
         round(sum(add_gc) / nullif(sum(sold_kgs), 0), 2) as add_gc_per_kg,
         round((sum(earn_gc) + sum(add_gc)) / nullif(sum(sold_kgs), 0), 2) as tot_gc_per_kg,
         sum(sold_no) as no_of_birds_sold,
         sum(sold_kgs) as no_of_kg_sold,
         round(avg(feed_trt), 2) as return_feed_perc,
         sum(sold_kgs * avg_selling_price) / nullif(sum(sold_kgs), 0) as avg_sales_price,
         sum(mean_age_new) as mean_age_new,
         sum(birds_lifted) as birds_lifted,
         sum(lifted_wt) as lifted_wt,
         avg(mort) as mort
    from mid
   group by breed

  union all

  /* ---------- GRAND TOTAL ---------- */
  select 'Grand Total' as zone,
         null as zone_seq,
         null as region,
         null as region_code,
         null as branch_name,
         null as location_name,
         null as breed,
         null as sort_breed,
         3 as row_type,
         sum(feed_consumed) as feed_consumed,
         sum(no_of_farms) as no_of_farms,
         sum(chicks_housed) as chicks_housed,
         round(((sum(feed_consumed) /
               sum(feed_consumption_std * sold_no)) * 100),
               2) as feed_intake_perc,
         round(sum(feed_consumed * 1000) / nullif(sum(sold_no), 0)) as feed_gms,
         round((avg(feed_consumed) / nullif(avg(sold_kgs), 0)) +
               (2 - (avg(sold_kgs) / nullif(avg(sold_no), 0))) / 0.04 * 0.01,
               2) as cfcr,
         round(avg(sold_kgs) / nullif(avg(sold_no), 0), 2) as avg_wt,
         round((avg(mean_age_new * sold_no)) / nullif(avg(sold_no), 0)) as mean_age,
         round(((sum(lifted_wt) / nullif(sum(birds_lifted), 0)) /
               nullif((avg(mean_age_new * sold_no) / nullif(avg(sold_no), 0)), 0)) * 1000,
               2) as day_gain,
         round(avg(mort) / nullif(avg(chicks_housed), 0) * 100, 2) as mort_perc,
         round(avg(mort7) / nullif(avg(chicks_housed), 0) * 100, 2) as mort_perc7,
         round(((((100 - ((sum(mort) / nullif(sum(chicks_housed), 0)) * 100)) *
               (sum(lifted_wt) / nullif(sum(birds_lifted), 0))) /
               nullif(((sum(mean_age * birds_lifted) / nullif(sum(birds_lifted), 0)) *
               (sum(feed_consumed) / nullif(sum(lifted_wt), 0))),
                      0)) * 100),
               2) as eef,
         sug_gn.round_2(avg(mc) / nullif(avg(sold_kgs), 0)) as med_cost,
         round((avg(fc) + avg(mc) + avg(ch) + avg(ac) + avg(mgc)) /
               nullif(avg(sold_kgs), 0),
               2) as prod_cost,
         round(sum(earn_gc) / nullif(sum(sold_kgs), 0), 2) as actual_gc,
         round(sum(add_gc) / nullif(sum(sold_kgs), 0), 2) as add_gc_per_kg,
         round((sum(earn_gc) + sum(add_gc)) / nullif(sum(sold_kgs), 0), 2) as tot_gc_per_kg,
         sum(sold_no) as no_of_birds_sold,
         sum(sold_kgs) as no_of_kg_sold,
         round(avg(feed_trt), 2) as return_feed_perc,
         sum(sold_kgs * avg_selling_price) / nullif(sum(sold_kgs), 0) as avg_sales_price,
         sum(mean_age_new) as mean_age_new,
         sum(birds_lifted) as birds_lifted,
         sum(lifted_wt) as lifted_wt,
         avg(mort) as mort
    from mid)
select zone,
       region,
       region_code,
       branch_name,
       location_name,
       breed,
       no_of_farms,
       case row_type
         when 3 then -1
         when 2 then 0
         else 1
       end as color_grp,
       sug_gn.round_2(chicks_housed / 100000) as chicks_housed,
       sug_gn.round_x(nvl(feed_gms, 0), 0) as feed_gms,
       sug_gn.round_x(nvl(feed_intake_perc, 0), 0) as feed_intake_perc,
       sug_gn.round_2(cfcr) as cfcr,
       sug_gn.round_2(avg_wt) as avg_wt,
       mean_age,
       sug_gn.round_x(nvl(day_gain, 0), 1) as day_gain,
       sug_gn.round_x(nvl(mort_perc, 0), 1) as mort_perc,
       sug_gn.round_x(nvl(mort_perc7, 0), 1) as mort_perc7,
       sug_gn.round_x(nvl(eef, 0), 0) as eef,
       sug_gn.round_2(nvl(med_cost, 0)) as med_cost,
       sug_gn.round_x(nvl(prod_cost, 0), 1) as prod_cost,
       sug_gn.round_2(nvl(actual_gc, 0)) as actual_gc,
       sug_gn.round_2(nvl(add_gc_per_kg, 0)) as add_gc_per_kg,
       sug_gn.round_2(nvl(tot_gc_per_kg, 0)) as tot_gc_per_kg,
       sug_gn.round_2(nvl(round(avg_wt, 2) * round(tot_gc_per_kg, 2), 0)) as tot_gc_per_bird,
       sug_gn.round_2(nvl(avg_wt * actual_gc, 0)) as gc_per_kgs,
       sug_gn.round_x(no_of_kg_sold / 1000, 0) as no_of_kg_sold,
       sug_gn.round_x(return_feed_perc, 1) as return_feed_perc,
       nvl(zone_seq, 9) as zone_seq,
       sug_gn.round_2(avg_sales_price) as avg_sales_price,
       sug_gn.round_2(feed_consumed) as feed_consumed,
       sug_gn.round_2(no_of_birds_sold) as no_of_birds_sold,
       sug_gn.round_2(mean_age_new) as mean_age_new,
       sug_gn.round_2(birds_lifted) as birds_lifted,
       sug_gn.round_2(lifted_wt) as lifted_wt,
       sug_gn.round_2(mort) as mort
  from agg
 order by sort_breed nulls last,
          row_type,
          nvl(zone_seq, 9),
          branch_name,
          no_of_farms desc;

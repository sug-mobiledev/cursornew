-- Growing charges report: detail + Sub Total (per breed) + Grand Total
-- Uses GROUP BY ROLLUP with a composite column group, so the branch-level
-- detail collapses to one breed subtotal, then to one grand total.
--
-- grouping_id(breed, branch_name):
--   0 -> detail row
--   1 -> Sub Total (breed level, branch grouped away)
--   3 -> Grand Total
-- color_grp is derived from it for report formatting: 1 / 0 / -1

select case gid
         when 3 then 'Grand Total'
         when 1 then 'Sub Total'
         else nvl(zone, 'NA')
       end                                                                   as zone,
       region,
       region_code,
       branch_name,
       location_name,
       breed,
       no_of_farms,
       case gid
         when 3 then -1
         when 1 then 0
         else 1
       end                                                                   as color_grp,
       sug_gn.round_2(chicks_housed / 100000)                                as chicks_housed,
       sug_gn.round_x(nvl(feed_gms, 0), 0)                                   as feed_gms,
       sug_gn.round_x(nvl(feed_intake_perc, 0), 0)                           as feed_intake_perc,
       sug_gn.round_2(cfcr)                                                  as cfcr,
       sug_gn.round_2(avg_wt)                                                as avg_wt,
       mean_age,
       sug_gn.round_x(nvl(day_gain, 0), 1)                                   as day_gain,
       sug_gn.round_x(nvl(mort_perc, 0), 1)                                  as mort_perc,
       sug_gn.round_x(nvl(mort_perc7, 0), 1)                                 as mort_perc7,
       sug_gn.round_x(nvl(eef, 0), 0)                                        as eef,
       sug_gn.round_2(nvl(med_cost, 0))                                      as med_cost,
       sug_gn.round_x(nvl(prod_cost, 0), 1)                                  as prod_cost,
       sug_gn.round_2(nvl(actual_gc, 0))                                     as actual_gc,
       sug_gn.round_2(nvl(add_gc_per_kg, 0))                                 as add_gc_per_kg,
       sug_gn.round_2(nvl(tot_gc_per_kg, 0))                                 as tot_gc_per_kg,
       sug_gn.round_2(nvl(round(avg_wt, 2) * round(tot_gc_per_kg, 2), 0))    as tot_gc_per_bird,
       sug_gn.round_2(nvl(avg_wt * actual_gc, 0))                            as gc_per_kgs,
       sug_gn.round_x(no_of_kg_sold / 1000, 0)                               as no_of_kg_sold,
       sug_gn.round_x(return_feed_perc, 1)                                   as return_feed_perc,
       nvl(zone_seq, 9)                                                      as zone_seq,
       sug_gn.round_2(avg_sales_price)                                       as avg_sales_price,
       sug_gn.round_2(feed_consumed)                                         as feed_consumed,
       sug_gn.round_2(no_of_birds_sold)                                      as no_of_birds_sold,
       sug_gn.round_2(mean_age_new)                                          as mean_age_new,
       sug_gn.round_2(birds_lifted)                                          as birds_lifted,
       sug_gn.round_2(lifted_wt)                                             as lifted_wt,
       sug_gn.round_2(mort)                                                  as mort
  from (select b.opm_zone                                                                as zone,
               b.zone_seq,
               b.region,
               b.region_code,
               b.branch_name,
               b.location_name,
               a.breed,
               grouping_id(a.breed, b.branch_name)                                       as gid,
               sum(a.feed_consumed)                                                      as feed_consumed,
               sum(a.no_of_farms)                                                        as no_of_farms,
               sum(a.chicks_housed)                                                      as chicks_housed,
               round(((sum(a.feed_consumed) /
                     sum(a.feed_consumption_std * a.sold_no)) * 100), 2)                 as feed_intake_perc,
               round(sum(a.feed_consumed * 1000) / sum(a.sold_no))                       as feed_gms,
               round((avg(a.feed_consumed) / avg(a.sold_kgs)) +
                     (2 - (avg(a.sold_kgs) / avg(a.sold_no))) / 0.04 * 0.01, 2)          as cfcr,
               round(avg(a.sold_kgs) / avg(a.sold_no), 2)                                as avg_wt,
               round((avg(a.mean_age_new * a.sold_no)) / avg(a.sold_no))                 as mean_age,
               round(((sum(a.lifted_wt) / sum(a.birds_lifted)) /
                     ((avg(a.mean_age_new * a.sold_no) / avg(a.sold_no)))) * 1000, 2)    as day_gain,
               round(avg(a.mort) / avg(a.chicks_housed) * 100, 2)                        as mort_perc,
               round(avg(a.mort7) / avg(a.chicks_housed) * 100, 2)                       as mort_perc7,
               round(((((100 - ((sum(a.mort) / sum(a.chicks_housed)) * 100)) *
                     (sum(a.lifted_wt) / sum(a.birds_lifted))) /
                     ((sum(a.mean_age * a.birds_lifted) /
                     sum(a.birds_lifted)) *
                     (sum(a.feed_consumed) / sum(a.lifted_wt)))) * 100), 2)              as eef,
               sug_gn.round_2(avg(a.mc) / avg(a.sold_kgs))                               as med_cost,
               round((avg(a.fc) + avg(a.mc) + avg(a.ch) + avg(a.ac) +
                     avg(a.mgc)) / avg(a.sold_kgs), 2)                                   as prod_cost,
               round(sum(a.earn_gc) / sum(a.sold_kgs), 2)                                as actual_gc,
               round(sum(a.add_gc) / sum(a.sold_kgs), 2)                                 as add_gc_per_kg,
               round((sum(a.earn_gc) + sum(a.add_gc)) / sum(a.sold_kgs), 2)              as tot_gc_per_kg,
               sum(a.sold_no)                                                            as no_of_birds_sold,
               sum(a.sold_kgs)                                                           as no_of_kg_sold,
               round(avg(a.feed_trt), 2)                                                 as return_feed_perc,
               sum(a.sold_kgs * a.avg_selling_price) / sum(a.sold_kgs)                   as avg_sales_price,
               sum(a.mean_age_new)                                                       as mean_age_new,
               sum(a.birds_lifted)                                                       as birds_lifted,
               sum(a.lifted_wt)                                                          as lifted_wt,
               avg(a.mort)                                                               as mort
          from (select nvl(g.attribute16, c.breed)                               as breed,
                       c.branch_code,
                       sum(feed_consumed)                                        as feed_consumed,
                       sum(c.std_feed_cons_gm) / 1000                            as feed_consumption_std,
                       sum(c.birds_lifted)                                       as birds_lifted,
                       sum(nvl(c.chicks_housed, 0))                              as chicks_housed,
                       sum(nvl(c.mortality_no, 0))                               as mort,
                       sum(sug_live_farm_intake.sug_agewise_mort(c.mean_age - 7,
                                                                 c.mean_age - 1,
                                                                 c.batch_id,
                                                                 c.hatch_date))  as mort7,
                       sum(birds_weight)                                         as lifted_wt,
                       sum(feed_consumed) / sum(birds_weight)                    as fcr,
                       sum(birds_weight / birds_lifted)                          as birds_weight,
                       sum(mean_age * birds_lifted) / sum(birds_lifted)          as mean_age,
                       sum(nvl(c.mean_age, 0))                                   as mean_age_new,
                       sum(nvl(c.avg_wt, 0))                                     as day_gain,
                       avg(nvl(eef, 0))                                          as eef,
                       sum(chick_cost)                                           as ch,
                       sum(feed_cost / birds_weight)                             as feed_cost,
                       sum(nvl(feed_cost, 0))                                    as fc,
                       sum(nvl(medic_cost, 0))                                   as mc,
                       sum(admin_cost / birds_weight)                            as admin_cost,
                       sum(nvl(admin_cost, 0))                                   as ac,
                       sum(nvl(min_gc, 0))                                       as mgc,
                       sum(earn_gc)                                              as earn_gc,
                       trunc(sum(feed_cost + medic_cost + chick_cost
                                 + admin_cost +
                                 nvl(min_gc, 0)) / sum(birds_weight),
                             2)                                                  as prod_cost,
                       sum(gc_per_kg)                                            as gc_per_kg,
                       sum(feed_cost + medic_cost + chick_cost + admin_cost +
                           nvl(min_gc, 0)) / sum(birds_weight) + sum(gc_per_kg)  as tot_cost,
                       sum(nvl(birds_lifted, 0))                                 as sold_no,
                       sum(nvl(birds_weight, 0))                                 as sold_kgs,
                       sum(nvl(c.add_gc, 0))                                     as add_gc,
                       avg(nvl(return_feed_pct, 0))                              as feed_trt,
                       count(distinct(c.farm_code))                              as no_of_farms,
                       sum(c.avg_selling_price)                                  as avg_selling_price
                  from sug_batch_growing_charges c,
                       gme_batch_header          g,
                       sug_organization_mv       d
                 where 1 = 1
                   and c.gc_date between l_from_date and l_to_date
                   and c.status       <> 'CANCELLED'
                   and c.birds_weight <> 0
                   and g.batch_id     = c.batch_id
                   and d.branch_code  = c.branch_code
                   and d.region_code not in ('RB', 'RD', 'GF')
                   and d.ledger_id                = cp_ledger_id
                   and nvl(d.opm_zone, 'NA')      = nvl(cp_zone, nvl(d.opm_zone, 'NA'))
                   and d.region_id                = nvl(cp_org_id, d.region_id)
                   and nvl(d.cluster_name, 'NA')  = nvl(cp_cluster, nvl(d.cluster_name, 'NA'))
                   and d.branch_id                = nvl(cp_orgn_id, d.branch_id)
                   and exists (select 1
                                 from fnd_lookup_values a
                                where 1 = 1
                                  and a.lookup_type = 'SUG_BREED_DETAILS'
                                  and a.enabled_flag = 'Y'
                                  and trunc(sysdate) between a.start_date_active
                                                         and nvl(a.end_date_active, trunc(sysdate))
                                  and ((p_group = 0 and a.attribute_category = 'Country Bird')
                                    or (p_group = 1 and a.attribute_category <> 'Country Bird'))
                                  and a.lookup_code = nvl(g.attribute16, c.breed))
                 group by nvl(g.attribute16, c.breed),
                          c.branch_code) a,
               sug_organization_mv b
         where 1 = 1
           and b.branch_code (+) = a.branch_code
         group by rollup(a.breed,
                         (b.opm_zone,
                          b.zone_seq,
                          b.region,
                          b.region_code,
                          b.branch_name,
                          b.location_name)))
 order by breed nulls last,          -- breed is null only on the Grand Total row
          gid,                       -- 0 detail, then 1 Sub Total
          nvl(zone_seq, 9),
          branch_name,
          no_of_farms desc;

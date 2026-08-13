procedure strain_wise_fa_bro_prod_perfrm(p_alert_id number, p_grp number, p_type varchar2) as
 
  -- p_grp 3 = Broiler Birds(Closed Farms), p_grp 4 = Country Birds(Closed Farms)
  l_subject     varchar2(200) := case when p_grp = 0 then 'Strain Wise - Broiler Production Performance'
                                      when p_grp = 1 then 'Strain Wise PS Region Wise Broiler Performance' 
                                      when p_grp = 2 then 'Strain Wise Broiler Region Wise Performance'
                                      when p_grp = 3 then 'Strain Wise PS Region Wise Broiler Performance - Broiler Birds(Closed Farms)'
                                      when p_grp = 4 then 'Strain Wise PS Region Wise Broiler Performance - Country Birds(Closed Farms)' end;
                                      
  en            varchar2(120) := '<br><left>* Please do not reply to this E-Mail. This e-mail address is not monitored.,ID:' || p_alert_id || '</left>';
  l_lob_id      number;
  l_sysdate     date := sysdate;
  l_st_date     date;
  l_ed_date     date;
  l_week_no     number;
  l_flag        number := 0;
  l_bold        varchar2(5);
  l_zone        varchar2(100);
  l_region      varchar2(100);
  l_breed       varchar2(200);
  l_feed_gm_ps  number;
  l_feed_in_ps  number;
  l_cfcr_ps     number;
  l_mean_age_ps number;
  l_day_gain_ps number;
  l_mort_prc_ps number;
  l_mort7_ps    number;
  l_prod_cst_ps number;
  l_feed_gm_ne  number;
  l_feed_in_ne  number;
  l_cfcr_ne     number;
  l_mean_age_ne number;
  l_day_gain_ne number;
  l_mort_prc_ne number;
  l_mort7_ne    number;
  l_prod_cst_ne number;
  
  cursor c_alert is
    select a.ledger_id,
           a.org_id,
           a.org_name,
           a.id,
           a.alert_id,
           nvl(a.subject, l_subject) subject,
           a.zone,
           a.cluster_name,
           a.orgn_id,
           sug_alert_admin_pkg.get_param_dtl(a.id, 3) level_code
    from   sug_alert_param_v a
    where  a.alert_id = p_alert_id
    and    a.enabled = 'Y';

  cursor c1(cp_ledger_id number, cp_zone varchar2, cp_org_id number, cp_cluster varchar2, cp_orgn_id number) is
    /*select distinct
           case when p_grp = 0 and breed is null then 'Grand Total' 
                when p_grp = 1 and region is not null and breed is null then region||' Total' 
                when p_grp = 1 and region is null     and breed is null then 'Grand Total' 
                when p_grp = 2 and zone is not null and region is not null and breed is null then region||' Total' 
                when p_grp = 2 and zone is not null and region is null     and breed is null then zone||' Total' 
                when p_grp = 2 and zone is null     and region is null     and breed is null then 'Grand Total' 
                else '-' end label,
           case
            when p_grp in (1,2) then
             count(zone) over(partition by zone)-1
           end as zspan,
           case
            when p_grp in (1,2) then
             count(region) over(partition by region)-1
           end as rspan,
           sum(case when breed is null then 0 else no_of_farms end) over(partition by case when p_grp = 2 then zone end, case when p_grp in (1,2) then region else breed end) tot,
           case when p_grp = 2 then zone end zone,
           region,
           breed,
           no_of_farms,
           case when breed is null then -1 else 1 end color_grp,
           sug_gn.round_2(chicks_housed / 100000) chicks_housed,
           sug_gn.round_x(nvl(feed_gms, 0), 0) feed_gms,
           sug_gn.round_x(nvl(feed_intake_perc, 0), 0) feed_intake_perc,
           sug_gn.round_2(cfcr) cfcr,
           sug_gn.round_2(avg_wt) avg_wt,
           mean_age,
           sug_gn.round_x(nvl(day_gain, 0), 1) day_gain,
           sug_gn.round_x(nvl(mort_perc, 0), 1) mort_perc,
           sug_gn.round_x(nvl(mort_perc7, 0), 1) mort_perc7,
           sug_gn.round_x(nvl(eef, 0), 0) eef,
           sug_gn.round_2(nvl(med_cost, 0)) med_cost,
           sug_gn.round_x(nvl(prod_cost, 0), 1) prod_cost,
           sug_gn.round_2(nvl(actual_gc, 0)) actual_gc,
           sug_gn.round_2(nvl(add_gc_per_kg, 0)) add_gc_per_kg,
           sug_gn.round_2(nvl(tot_gc_per_kg, 0)) tot_gc_per_kg,
           sug_gn.round_2(nvl(round(avg_wt, 2) * round(tot_gc_per_kg, 2), 0)) tot_gc_per_bird,
           sug_gn.round_2(nvl(avg_wt * actual_gc, 0)) gc_per_kgs,
           sug_gn.round_x(no_of_kg_sold / 1000, 0) no_of_kg_sold,
           sug_gn.round_x(return_feed_perc, 1) return_feed_perc,nvl(zone_seq,9) zone_seq
    from   (select case when p_grp = 2 then nvl(b.opm_zone,'-') end zone,
                   case when p_grp = 2 then max(nvl(b.zone_seq,'9')) end zone_seq,
                   case when p_grp = 1 then nvl(b.region, 'Outside Purchase') when p_grp = 2 then b.region end as region,
                   breed,
                   sum(a.no_of_farms) no_of_farms,
                   sum(a.chicks_housed) chicks_housed,
                   round(((sum(a.feed_consumed) /
                         sum(a.feed_consumption_std * a.sold_no)) * 100), 2) feed_intake_perc,
                   round(sum(a.feed_consumed * 1000) / sum(a.sold_no)) feed_gms,
                   round((avg(a.feed_consumed) / avg(a.sold_kgs)) +
                         (2 - (avg(a.sold_kgs) / avg(a.sold_no))) / 0.04 * 0.01, 2) cfcr,
                   round(avg(a.sold_kgs) / avg(a.sold_no), 2) avg_wt,
                   round((avg(a.mean_age_new * a.sold_no)) / avg(a.sold_no)) as mean_age,
                   round(((sum(a.lifted_wt) / sum(a.birds_lifted)) /
                         ((avg(a.mean_age_new * a.sold_no) / avg(a.sold_no)))) * 1000, 2) as day_gain,
                   round(avg(a.mort) / avg(a.chicks_housed) * 100, 2) mort_perc,
                   round(avg(a.mort7) / avg(a.chicks_housed) * 100, 2) mort_perc7,
                   round(((((100 - ((sum(a.mort) / sum(a.chicks_housed)) * 100)) *
                         (sum(a.lifted_wt) / sum(a.birds_lifted))) /
                         ((sum(a.mean_age * a.birds_lifted) /
                         sum(a.birds_lifted)) *
                         (sum(a.feed_consumed) / sum(a.lifted_wt)))) * 100), 2) eef,
                   sug_gn.round_2(avg(mc) / avg(sold_kgs)) med_cost,
                   round((avg(a.fc) + avg(a.mc) + avg(a.ch) + avg(a.ac) +
                         avg(a.mgc)) / avg(a.sold_kgs), 2) prod_cost,
                   round(sum(a.earn_gc) / sum(a.sold_kgs), 2) actual_gc,
                   round(sum(a.add_gc) / sum(a.sold_kgs), 2) add_gc_per_kg,
                   round((sum(a.earn_gc) + sum(a.add_gc)) / sum(a.sold_kgs), 2) tot_gc_per_kg,
                   sum(a.sold_no) no_of_birds_sold,
                   sum(a.sold_kgs) no_of_kg_sold,
                   round(avg(a.feed_trt), 2) return_feed_perc
            from   (select nvl(g.attribute16,c.breed) breed,
                           c.farm_code,
                           case when p_grp in (0,2) then c.branch_code
                                when p_grp = 1 then
                                case when sug_mis_opm_pkg.is_number(substr(nvl(c.hatchery_lot, 'XXX'), -3, 3)) = 1 
                                     then substr(c.hatchery_lot, -6, 3) else 'XXX' end
                           end as branch_code,
                           sum(feed_consumed) as feed_consumed,
                           sum(c.std_feed_cons_gm) / 1000 feed_consumption_std,
                           sum(c.birds_lifted) as birds_lifted,
                           sum(nvl(c.chicks_housed, 0)) as chicks_housed,
                           sum(nvl(c.mortality_no, 0)) as mort,
                           sum(sug_live_farm_intake.sug_agewise_mort(c.mean_age - 7, c.mean_age - 1, c.batch_id, c.hatch_date)) mort7,
                           sum(birds_weight) as lifted_wt,
                           sum(feed_consumed) / sum(birds_weight) as fcr,
                           sum(birds_weight / birds_lifted) as birds_weight,
                           sum(mean_age * birds_lifted) / sum(birds_lifted) as mean_age,
                           sum(nvl(c.mean_age, 0)) as mean_age_new,
                           sum(nvl(c.avg_wt, 0)) as day_gain,
                           avg(nvl(eef, 0)) as eef,
                           sum(chick_cost) as ch,
                           sum(feed_cost / birds_weight) as feed_cost,
                           sum(nvl(feed_cost, 0)) as fc,
                           sum(nvl(medic_cost, 0)) as mc,
                           sum(admin_cost / birds_weight) as admin_cost,
                           sum(nvl(admin_cost, 0)) as ac,
                           sum(nvl(min_gc, 0)) as mgc,
                           SUM(earn_gc) earn_gc,
                           trunc(sum(feed_cost + medic_cost + chick_cost +
                                     admin_cost + nvl(min_gc, 0)) /
                                 sum(birds_weight), 2) as prod_cost,
                           sum(gc_per_kg) as gc_per_kg,
                           sum(feed_cost + medic_cost + chick_cost + admin_cost +
                               nvl(min_gc, 0)) / sum(birds_weight) +
                           sum(gc_per_kg) as tot_cost,
                           sum(nvl(birds_lifted, 0)) as sold_no,
                           sum(nvl(birds_weight, 0)) as sold_kgs,
                           sum(nvl(c.add_gc, 0)) as add_gc,
                           avg(nvl(return_feed_pct, 0)) as feed_trt,
                           count(distinct(c.farm_code)) as no_of_farms
                    from   sug_batch_growing_charges c,
                           gme_batch_header g,
                           sug_organization_mv d
                    where  1 = 1
                    and    c.gc_date between l_st_date and l_ed_date
                    and    c.status <> 'CANCELLED'
                    and    c.birds_weight <> 0
                    and    g.batch_id = c.batch_id
                    and    d.branch_code = c.branch_code
                    and    d.region_code not in ('RB', 'RD', 'GF')
                    and    d.ledger_id = cp_ledger_id
                    and    nvl(d.opm_zone, 'NA') =
                           nvl(cp_zone, nvl(d.opm_zone, 'NA'))
                    and    d.region_id = nvl(cp_org_id, d.region_id)
                    and    nvl(d.cluster_name, 'NA') =
                           nvl(cp_cluster, nvl(d.cluster_name, 'NA'))
                    and    d.branch_id = nvl(cp_orgn_id, d.branch_id)
                    group  by nvl(g.attribute16,c.breed),
                              c.farm_code,
                              case when p_grp in (0,2) then c.branch_code
                                   when p_grp = 1 then
                                   case when sug_mis_opm_pkg.is_number(substr(nvl(c.hatchery_lot, 'XXX'), -3, 3)) = 1 
                                        then substr(c.hatchery_lot, -6, 3) else 'XXX' end
                              end) a,
                   sug_organization_mv b
            where  1 = 1
            and    b.branch_code (+)= a.branch_code
            group  by rollup(case when p_grp = 2 then nvl(b.opm_zone,'-') end, case when p_grp = 1 then nvl(b.region, 'Outside Purchase') when p_grp = 2 then b.region end, breed))
    order  by zone_seq, tot desc, decode(region,'Outside Purchase', 'ZZZ', region),
              case when p_grp = 0 and breed is null then 2
                   when p_grp = 1 and region is not null  and breed is null then 2  
                   when p_grp = 1 and region is null      and breed is null then 3
                   when p_grp = 2 and zone is not null and region is not null and breed is null then 2 
                   when p_grp = 2 and zone is not null and region is null     and breed is null then 3  
                   when p_grp = 2 and zone is null     and region is null     and breed is null then 4
                   else 1 end, no_of_farms desc, breed;*/
                     
    select label,
       zspan,
       case
         when p_grp in (1,2,3,4) then
          count(region) over(partition by region)-1
       end as rspan,
        case when 
         p_grp in (1,2,3,4) then 
          count (cage) over (partition by breed,region)
         end as breedpan,
       sum(case when breed is null then 0 else no_of_farms end) over(partition by case when p_grp = 2 then zone end, case when p_grp in (1,2,3,4) then region else breed end)  tot,
       zone,
       region,
       breed,
       cage,
       no_of_farms,
       color_grp,
       chicks_housed,
       feed_gms,
       feed_intake_perc,
       cfcr,
       avg_wt,
       mean_age,
       day_gain,
       mort_perc,
       mort_perc7,
       eef,
       med_cost,
       prod_cost,
       actual_gc,
       add_gc_per_kg,
       tot_gc_per_kg,
       tot_gc_per_bird,
       gc_per_kgs,
       no_of_kg_sold,
       zone_seq
  from(
select distinct
           case
                when p_grp in (1,3,4) and region is not null and breed is null then region||' Total' 
                when p_grp in (1,3,4) and region is null     and breed is null then 'Grand Total' 
               
                else '-' end label,
           case
            when 1 in (1,2) then
             count(zone) over(partition by zone)-1
           end as zspan,
           case
            when 1 in (1,2) then
             count(region) over(partition by region)-1
           end as rspan,
             case when 
         1 in (1,2) then 
         count (cage) over (partition by breed)-1
         end as breedpan,
           sum(case when breed is null then 0 else no_of_farms end) over(partition by case when p_grp = 2 then zone end, case when p_grp in (1,2,3,4) then region else breed end) tot,
           case when p_grp = 2 then zone end zone,
           region,
           breed,
            case when region is not null and breed is not null and cage is null then null else cage end cage,
           no_of_farms,
           case when breed is null then -1 else 1 end color_grp,
           sug_gn.round_2(chicks_housed / 100000) chicks_housed,
           sug_gn.round_x(nvl(feed_gms, 0), 0) feed_gms,
           sug_gn.round_x(nvl(feed_intake_perc, 0), 0) feed_intake_perc,
           sug_gn.round_2(cfcr) cfcr,
           sug_gn.round_2(avg_wt) avg_wt,
           mean_age,
           sug_gn.round_x(nvl(day_gain, 0), 1) day_gain,
           sug_gn.round_x(nvl(mort_perc, 0), 1) mort_perc,
           sug_gn.round_x(nvl(mort_perc7, 0), 1) mort_perc7,
           sug_gn.round_x(nvl(eef, 0), 0) eef,
           sug_gn.round_2(nvl(med_cost, 0)) med_cost,
           sug_gn.round_x(nvl(prod_cost, 0), 1) prod_cost,
           sug_gn.round_2(nvl(actual_gc, 0)) actual_gc,
           sug_gn.round_2(nvl(add_gc_per_kg, 0)) add_gc_per_kg,
           sug_gn.round_2(nvl(tot_gc_per_kg, 0)) tot_gc_per_kg,
           sug_gn.round_2(nvl(round(avg_wt, 2) * round(tot_gc_per_kg, 2), 0)) tot_gc_per_bird,
           sug_gn.round_2(nvl(avg_wt * actual_gc, 0)) gc_per_kgs,
           sug_gn.round_x(no_of_kg_sold / 1000, 0) no_of_kg_sold,
           sug_gn.round_x(return_feed_perc, 1) return_feed_perc,nvl(zone_seq,9) zone_seq
    from   (select case when p_grp = 2 then nvl(b.opm_zone,'-') end zone,
                   case when p_grp = 2 then max(nvl(b.zone_seq,'9')) end zone_seq,
                   case when p_grp in (1,3,4) then nvl(b.region, 'Outside Purchase') when p_grp = 2 then b.region end as region,
                   breed,
                   cage,
                   sum(a.no_of_farms) no_of_farms,
                   sum(a.chicks_housed) chicks_housed,
                   round(((sum(a.feed_consumed) /
                         sum(a.feed_consumption_std * a.sold_no)) * 100), 2) feed_intake_perc,
                   round(sum(a.feed_consumed * 1000) / sum(a.sold_no)) feed_gms,
                   round((avg(a.feed_consumed) / avg(a.sold_kgs)) +
                         (2 - (avg(a.sold_kgs) / avg(a.sold_no))) / 0.04 * 0.01, 2) cfcr,
                   round(avg(a.sold_kgs) / avg(a.sold_no), 2) avg_wt,
                   round((avg(a.mean_age_new * a.sold_no)) / avg(a.sold_no)) as mean_age,
                   round(((sum(a.lifted_wt) / sum(a.birds_lifted)) /
                         ((avg(a.mean_age_new * a.sold_no) / avg(a.sold_no)))) * 1000, 2) as day_gain,
                   round(avg(a.mort) / avg(a.chicks_housed) * 100, 2) mort_perc,
                   round(avg(a.mort7) / avg(a.chicks_housed) * 100, 2) mort_perc7,
                   round(((((100 - ((sum(a.mort) / sum(a.chicks_housed)) * 100)) *
                         (sum(a.lifted_wt) / sum(a.birds_lifted))) /
                         ((sum(a.mean_age * a.birds_lifted) /
                         sum(a.birds_lifted)) *
                         (sum(a.feed_consumed) / sum(a.lifted_wt)))) * 100), 2) eef,
                   sug_gn.round_2(avg(mc) / avg(sold_kgs)) med_cost,
                   round((avg(a.fc) + avg(a.mc) + avg(a.ch) + avg(a.ac) +
                         avg(a.mgc)) / avg(a.sold_kgs), 2) prod_cost,
                   round(sum(a.earn_gc) / sum(a.sold_kgs), 2) actual_gc,
                   round(sum(a.add_gc) / sum(a.sold_kgs), 2) add_gc_per_kg,
                   round((sum(a.earn_gc) + sum(a.add_gc)) / sum(a.sold_kgs), 2) tot_gc_per_kg,
                   sum(a.sold_no) no_of_birds_sold,
                   sum(a.sold_kgs) no_of_kg_sold,
                   round(avg(a.feed_trt), 2) return_feed_perc
            from   (select nvl(g.attribute16,c.breed) breed,x.ATTRIBUTE9 cage,
                           c.farm_code,
                           case when p_grp in (0,2) then c.branch_code
                                when p_grp in (1,3,4) then
                                case when sug_mis_opm_pkg.is_number(substr(nvl(c.hatchery_lot, 'XXX'), -3, 3)) = 1 
                                     then substr(c.hatchery_lot, -6, 3) else 'XXX' end
                           end as branch_code,
                           sum(feed_consumed) as feed_consumed,
                           sum(c.std_feed_cons_gm) / 1000 feed_consumption_std,
                           sum(c.birds_lifted) as birds_lifted,
                           sum(nvl(c.chicks_housed, 0)) as chicks_housed,
                           sum(nvl(c.mortality_no, 0)) as mort,
                           sum(sug_live_farm_intake.sug_agewise_mort(c.mean_age - 7, c.mean_age - 1, c.batch_id, c.hatch_date)) mort7,
                           sum(birds_weight) as lifted_wt,
                           sum(feed_consumed) / sum(birds_weight) as fcr,
                           sum(birds_weight / birds_lifted) as birds_weight,
                           sum(mean_age * birds_lifted) / sum(birds_lifted) as mean_age,
                           sum(nvl(c.mean_age, 0)) as mean_age_new,
                           sum(nvl(c.avg_wt, 0)) as day_gain,
                           avg(nvl(eef, 0)) as eef,
                           sum(chick_cost) as ch,
                           sum(feed_cost / birds_weight) as feed_cost,
                           sum(nvl(feed_cost, 0)) as fc,
                           sum(nvl(medic_cost, 0)) as mc,
                           sum(admin_cost / birds_weight) as admin_cost,
                           sum(nvl(admin_cost, 0)) as ac,
                           sum(nvl(min_gc, 0)) as mgc,
                           SUM(earn_gc) earn_gc,
                           trunc(sum(feed_cost + medic_cost + chick_cost +
                                     admin_cost + nvl(min_gc, 0)) /
                                 sum(birds_weight), 2) as prod_cost,
                           sum(gc_per_kg) as gc_per_kg,
                           sum(feed_cost + medic_cost + chick_cost + admin_cost +
                               nvl(min_gc, 0)) / sum(birds_weight) +
                           sum(gc_per_kg) as tot_cost,
                           sum(nvl(birds_lifted, 0)) as sold_no,
                           sum(nvl(birds_weight, 0)) as sold_kgs,
                           sum(nvl(c.add_gc, 0)) as add_gc,
                           avg(nvl(return_feed_pct, 0)) as feed_trt,
                           count(distinct(c.farm_code)) as no_of_farms
                    from   sug_batch_growing_charges c,
                           gme_batch_header g,
                           sug_organization_mv d,
                           mtl_parameters x
                    where  1 = 1
                  
                    and x.ORGANIZATION_CODE =substr(c.hatchery_lot, -6, 3)
                    and    c.gc_date between l_st_date and l_ed_date
                    ---nd    c.gc_date BETWEEN TO_DATE('2024/01/07', 'YYYY/MM/DD HH24:MI:SS') AND TO_DATE('2024/01/13', 'YYYY/MM/DD HH24:MI:SS')+.99999
                    and    c.status <> 'CANCELLED'
                    and    c.birds_weight <> 0
                    and    g.batch_id = c.batch_id
                    and    d.branch_code = c.branch_code
                    and    d.region_code not in ('RB', 'RD', 'GF')
                    and    d.ledger_id = cp_ledger_id
                 and    nvl(d.opm_zone, 'NA') =
                         nvl(cp_zone, nvl(d.opm_zone, 'NA'))
                  and    d.region_id = nvl(cp_org_id, d.region_id)
                   and    nvl(d.cluster_name, 'NA') =
                          nvl(cp_cluster, nvl(d.cluster_name, 'NA'))
                   and    d.branch_id = nvl(cp_orgn_id, d.branch_id)
                    -- p_grp 3 Broiler / p_grp 4 Country from SUG_BREED_DETAILS
                    and    (
                             p_grp not in (3, 4)
                          or exists (
                               select 1
                               from   fnd_lookup_values flv
                               where  flv.lookup_type = 'SUG_BREED_DETAILS'
                               and    flv.enabled_flag = 'Y'
                               and    trunc(sysdate) between flv.start_date_active
                                                       and nvl(flv.end_date_active, trunc(sysdate))
                               and    upper(trim(flv.attribute1)) = upper(trim(nvl(g.attribute16, c.breed)))
                               and    (
                                        (p_grp = 4 and flv.attribute_category = 'Country Bird')
                                     or (p_grp = 3 and nvl(flv.attribute_category, 'X') <> 'Country Bird')
                                     )
                             )
                           )
                    group  by nvl(g.attribute16,c.breed),
                              c.farm_code,
                              x.ATTRIBUTE9,
                              case when p_grp in (0,2) then c.branch_code
                                   when p_grp in (1,3,4) then
                                   case when sug_mis_opm_pkg.is_number(substr(nvl(c.hatchery_lot, 'XXX'), -3, 3)) = 1 
                                        then substr(c.hatchery_lot, -6, 3) else 'XXX' end
                              end) a,
                   sug_organization_mv b
            where  1 = 1
            and    b.branch_code = a.branch_code
           --- and    b.region_code='BG'
            group  by rollup(case when p_grp = 2 then nvl(b.opm_zone,'-') end, case when p_grp in (1,3,4) then nvl(b.region, 'Outside Purchase') when p_grp = 2 then b.region end, breed,cage))
   where 1=1

 order  by zone_seq, tot desc, decode(region,'Outside Purchase', 'ZZZ', region),
            case 
                 when p_grp in (1,3,4) and region is not null  and breed  is null  then 2  
                 when p_grp in (1,3,4) and region is null      and breed is null  then 3
                  
                 else 1 end, breed ,cage 
                  
                     )where 1=1
                      and ((label='-' and (region is not null and breed is not null and cage is not null))or label like '%Total%')
                      order  by zone_seq,  (case when tot= 0 then 1000000 else tot end )desc, decode(region,'Outside Purchase', 'ZZZ', region),
            case 
                 when p_grp in (1,3,4) and region is not null  and breed  is null  then 2  
                 when p_grp in (1,3,4) and region is null  and breed is null  then 3
                  
                 else 1 end, breed ,cage 
                   ;
               
                   
                   
                   
                   
                     
   function get_color(p_value number, p_value_pos number, p_value_neg number, p_color_grp number) return varchar2 as
     l_clr_green varchar2(50) := '#129d01';
     l_clr_red   varchar2(50) := '#fd1300';
     l_clr_orng  varchar2(50) := '#f59704';
   begin
     if p_color_grp = 1 then
       if p_value <= p_value_neg then
         return(l_clr_green);
       elsif p_value >= p_value_pos then
         return(l_clr_red);
       else
         return(l_clr_orng);
       end if;
     end if;
     if p_color_grp = 2 then
       if p_value <= p_value_neg then
         return(l_clr_red);
       elsif p_value >= p_value_pos then
         return(l_clr_green);
       else
         return(l_clr_orng);
       end if;
     end if;
     return(null);
   end;

   procedure ol(p_str in varchar2) is
     pragma autonomous_transaction;
   begin
     null;
     sug_clob_pkg.write_lob(l_lob_id, p_str);
   end ol;
begin
    if p_type = 'W' then
      select start_wk,
             end_wk,
             week_no
      into   l_st_date, l_ed_date, l_week_no
      from   sug_broiler_calendar_week
      where  trunc(l_sysdate)  -5 between start_wk and end_wk;--5
    end if;
    if p_type = 'M' then
      select a.month_date, a.month_end
      into   l_st_date, l_ed_date
      from   sug_month_calendar a
      where  trunc(last_day(l_sysdate) - 32) between a.month_date and a.month_end;
    end if;

    for i in c_alert loop
      l_lob_id := sug_clob_gtt_s.nextval;
      for j in c1(i.ledger_id, i.zone, i.org_id, i.cluster_name, i.orgn_id) loop
        if j.label <> 'Grand Total' then continue; end if;
        --positive
        l_feed_gm_ps  := j.feed_gms + (j.feed_gms*5/100);
        l_feed_in_ps  := j.feed_intake_perc + (j.feed_intake_perc*5/100);
        l_cfcr_ps     := j.cfcr + (j.cfcr*5/100); 
        l_mean_age_ps := j.mean_age + (j.mean_age*5/100);
        l_day_gain_ps := j.day_gain + (j.day_gain*5/100);
        l_mort_prc_ps := j.mort_perc + (j.mort_perc*5/100);
        l_mort7_ps    := j.mort_perc7 + (j.mort_perc7*5/100);
        l_prod_cst_ps := j.prod_cost + (j.prod_cost*5/100);
        --negative
        l_feed_gm_ne  := j.feed_gms - (j.feed_gms*5/100);
        l_feed_in_ne  := j.feed_intake_perc - (j.feed_intake_perc*5/100);
        l_cfcr_ne     := j.cfcr - (j.cfcr*5/100); 
        l_mean_age_ne := j.mean_age - (j.mean_age*5/100);
        l_day_gain_ne := j.day_gain - (j.day_gain*5/100);
        l_mort_prc_ne := j.mort_perc - (j.mort_perc*5/100);
        l_mort7_ne    := j.mort_perc7 - (j.mort_perc7*5/100);
        l_prod_cst_ne := j.prod_cost - (j.prod_cost*5/100);
      end loop;
      
      ol(htd(td => 'H4', l => 'L', d => sug_alert_admin_pkg.get_param_dtl(i.id)));
      ol(htd(td => 'H4', l => 'L', d => i.subject));
      if p_type = 'W' then 
        ol(htd(td => 'H4', l => 'L', d => 'Week No : ' || l_week_no || ' (' || l_st_date || ' To ' || l_ed_date || ')')); 
      else
        ol(htd(td => 'H4', l => 'L', d => 'Period : ' || l_st_date || ' To ' || l_ed_date));
      end if;
      
      ol('<TABLE border=1 cellpadding=0 cellspacing=0>');
      ol(htrh);
    
      if p_grp in (1,2,3,4) then
        ol(htd(td => 'H', l => 'L', d => 'Business Unit'));
      end if;
      
      ol(htd(td => 'H', l => 'L', d => 'Breed/Strain'));
      if p_grp in (1,3,4) then
      ol(htd(td => 'H', l => 'L', d => 'PS Farm<br>Type'));
      end if;
      --ol(htd(td => 'H', l => 'R', d => 'No.of<br>Farms'));
      ol(htd(td => 'H', l => 'R', d => 'Housed<br>In Lakhs'));
      ol(htd(td => 'H', l => 'R', d => 'Sold Kgs<br>(MT)'));
      ol(htd(td => 'H', l => 'R', d => 'Feed Intake<br>(Gm)'));
      --ol(htd(td => 'H', l => 'R', d => 'Feed Intake<br>(%)'));
      ol(htd(td => 'H', l => 'R', d => 'Mean Age'));
      ol(htd(td => 'H', l => 'R', d => 'EEF'));
      ol(htd(td => 'H', l => 'R', d => 'Mort%'));
      ol(htd(td => 'H', l => 'R', d => 'Last 7 days<br>Mort%'));
      ol(htd(td => 'H', l => 'R', d => 'CFCR'));
      ol(htd(td => 'H', l => 'R', d => 'Avg. Wt.'));
      ol(htd(td => 'H', l => 'R', d => 'Day Gain'));
      --ol(htd(td => 'H', l => 'R', d => 'Med Cost'));
      ol(htd(td => 'H', l => 'R', d => 'Prod Cost'));  
      ol(htd(td => 'H', l => 'R', d => 'Tot.GC<br>Per KG'));
      ol(htd(td => 'H', l => 'R', d => 'Tot.GC<br>Per Bird')); 
      --ol(htd(td => 'H', l => 'R', d => 'Return Feed<br>(%)'));
      l_region := 'X';
      l_zone   := 'X';
      l_breed  := 'X';
      ol(htrc);
      ol(htd(b => l_bold, l => 'R', d => '&nbsp', e => 'colspan=16'));
      for j in c1(i.ledger_id, i.zone, i.org_id, i.cluster_name, i.orgn_id) loop
        
    ---  
        
        if (i.level_code not in ('L','Z') and j.label = j.region||' Total') or
           (i.level_code <> 'L'           and j.label = j.zone||' Total')  
        then
           continue;
            end if;
            
          
       
        if j.label = '-' then
           ol(htr); l_bold := 'N';
            else ol(htrh); l_bold := 'Y';
             end if;
             
             
       
        if j.label = '-' then
        
          if p_grp in (1,2,3,4) and nvl(l_region,'X') <> j.region then
            ol(htd(b => l_bold, l => 'L', e => 'rowspan="'||to_char(j.rspan)||'" nowrap', d => j.region));
          end if;
          
          if p_grp in (1,2,3,4) and nvl(l_breed,'X') <> j.breed or nvl(l_region,'X') <> j.region  then
            ol(htd(b => l_bold, l => 'L', e => 'rowspan="'||to_char(j.breedpan)||'" nowrap', d => j.breed));
          end if;
          
        
          if p_grp in (1,3,4) then
          ol(htd(b => l_bold, l => 'L', e => 'nowrap', d => nvl(nullif(j.cage,'-'),'&nbsp')));
          end if;
        end if;
       
        if j.label = j.region||' Total' then 
         -- if j.rspan = 1 then 
          --  continue; 
          --  end if;
          --ol(htd(b => l_bold, l => 'R', e => 'nowrap', d => '&nbsp'));
        --  ol(htd(b => l_bold, l => 'R', e => 'nowrap', d => '&nbsp'));
          ol(htd(b => l_bold, l => 'R', d => j.label, e => 'colspan=3'));
        end if;
        if j.label = 'Grand Total' then
          
      
          ol(htd(b => l_bold, l => 'R', e => 'colspan="'||to_char(case when p_grp in (3,4) then 3 else p_grp+1+1 end)||'"', d => case when i.level_code = 'B' then 'Branch Total'
                                                                                           when i.level_code = 'C' then 'Cluster Total'
                                                                                           when i.level_code = 'R' then 'Region Total'
                                                                                           when i.level_code = 'Z' then 'Zone Total'
                                                                                           when i.level_code = 'L' then 'Grand Total' end));
        end if;
        
        --ol(htd(b => l_bold, l => 'R', d => j.no_of_farms));
        ol(htd(b => l_bold, l => 'R', d => j.chicks_housed));
        ol(htd(b => l_bold, l => 'R', d => j.no_of_kg_sold));
        ol(htd(b => l_bold, l => 'R', C => get_color(j.feed_gms, l_feed_gm_ps, l_feed_gm_ne, j.color_grp+1), d => j.feed_gms));
        --ol(htd(b => l_bold, l => 'R', C => get_color(j.feed_intake_perc, l_feed_in_ps, l_feed_in_ne, j.color_grp+1), d => j.feed_intake_perc));
        ol(htd(b => l_bold, l => 'R', C => get_color(j.mean_age, l_mean_age_ps, l_mean_age_ne, j.color_grp), d => j.mean_age));
        ol(htd(b => l_bold, l => 'R', d => j.eef));
        ol(htd(b => l_bold, l => 'R', C => get_color(j.mort_perc, l_mort_prc_ps, l_mort_prc_ne, j.color_grp), d => j.mort_perc));
        ol(htd(b => l_bold, l => 'R', C => get_color(j.mort_perc7, l_mort7_ps, l_mort7_ne, j.color_grp), d => j.mort_perc7));
        ol(htd(b => l_bold, l => 'R', C => get_color(j.cfcr, l_cfcr_ps, l_cfcr_ne, j.color_grp), d => j.cfcr));
        ol(htd(b => l_bold, l => 'R', d => j.avg_wt));
        ol(htd(b => l_bold, l => 'R', C => get_color(j.day_gain, l_day_gain_ps, l_day_gain_ne, j.color_grp+1), d => j.day_gain));
        --ol(htd(b => l_bold, l => 'R', d => j.med_cost));
        ol(htd(b => l_bold, l => 'R', C => get_color(j.prod_cost, l_prod_cst_ps, l_prod_cst_ne, j.color_grp), d => j.prod_cost));
        ol(htd(b => l_bold, l => 'R', d => j.tot_gc_per_kg));
        ol(htd(b => l_bold, l => 'R', d => j.tot_gc_per_bird));
        --ol(htd(b => l_bold, l => 'R', d => j.return_feed_perc));
        ol(htrc);
        l_breed  := j.breed;
       if j.label like '%Total%' then 
          l_region:='X';
          else
        l_region := j.region;
        end if;
        l_zone := j.zone;
        l_flag := 1;
       
      end loop;
      ol(htc);
      ol(en);
      if l_flag <> 0 then
        sug_alert_admin_pkg.send_mail(p_param_id => i.id, p_lob_id => l_lob_id, p_subject => i.subject || case when i.level_code = 'R' then ' : ' || i.org_name end);
        l_flag := 0;
      end if;
    end loop i;
end;

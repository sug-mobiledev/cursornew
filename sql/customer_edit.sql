procedure customer_edit(p_source_id number) as
    -- 01 30032026 Ajay [P Adhoc] - Adhoc Chnages
    l_organization_rec_type      hz_party_v2pub.organization_rec_type;
    l_cust_account_rec_type      hz_cust_account_v2pub.cust_account_rec_type;
    l_customer_profile_rec_type  hz_customer_profile_v2pub.customer_profile_rec_type;
    l_cust_site_use_rec_type     hz_cust_account_site_v2pub.cust_site_use_rec_type;  --added for site payment term
    x_return_status              varchar2(3000);
    x_msg_count                  varchar2(30);
    x_msg_data                   varchar2(3000);
    x_msg_index_out              varchar2(30);
    l_profile_class_id           number;
    l_prof_class_ovn             number;
    l_error_message              varchar2(1000);
    ln_object_version_number     number;
    ln_profile_id                number; 
    ln_party_id                  number;
    l_obv_number                 number;
    
    l_catg_cnt                   number :=0;
    
    /* cursor c0 is
    select 
    b.object_version_number,
    a.erp_customer_id,
    a.erp_customer_number,
    a.customer_name,
    a.customer_class_code,
    a.customer_category_code,
    a.customer_region,
    a.profile_class,
    a.dob,
    a.wedding_date,
    a.quantity_discount,
    a.aadhar_number,
    a.common_customer,
    a.payment_term,
    a.payment_term_to
    from sug_cp_customer_edit a ,
         hz_cust_accounts_all b 
    where a.erp_customer_id=b.cust_account_id 
    and nvl(a.status, 'N') in ( 'N','E')
    AND a.creation_date>SYSDATE-1 
     \* and trunc(a.erp_creation_date)  >= '1-jul-20'*\;*/
       
    cursor c1(cp_source_id NUMBER) is
    select 
           b.object_version_number,
           a.erp_customer_id,
           a.erp_customer_number,
           a.customer_name,
           a.customer_class_code,
           a.customer_category_code,
           a.customer_region,
           a.profile_class,
           a.dob,
           a.wedding_date,
           a.quantity_discount,
           a.aadhar_number,
           a.common_customer,
           a.payment_term,
           a.payment_term_to
    from sug_cp_customer_edit a ,
         hz_cust_accounts_all b 
    where a.erp_customer_id=b.cust_account_id 
    and nvl(a.status, 'N') in ( 'N','E') 
    AND a.SOURCE_ID=cp_source_id
 /*    AND a.creation_date>SYSDATE-1 */
     /* and trunc(a.erp_creation_date)  >= '1-jul-20'*/;
     
   cursor c_site(cp_customer_id number) is
   select obj_cust,
          site_use_id,
          site_use_code,
          cust_acct_site_id,
          cust_acc_status
   from(select 
        c.object_version_number obj_cust,
        c.site_use_id,
        c.site_use_code,
        b.cust_acct_site_id,
        b.status cust_acc_status
        from hz_cust_acct_sites_all b,
             hz_cust_site_uses_all  c,
             hz_party_sites         d,
             hz_locations           e,
             hz_cust_accounts       f
        where 1 = 1
         and c.cust_acct_site_id = b.cust_acct_site_id
         and c.site_use_code     = 'BILL_TO'
         and d.party_site_id     = b.party_site_id
         and e.location_id       = d.location_id
         and f.cust_account_id   = b.cust_account_id
         and f.account_number    = cp_customer_id
             
        UNION ALL
           
        select 
        c.object_version_number obj_cust,
        c.site_use_id,
        c.site_use_code,
        b.cust_acct_site_id,
        b.status cust_acc_status
        from hz_cust_acct_sites_all b,
             hz_cust_site_uses_all  c,
             hz_party_sites         d,
             hz_locations           e,
             hz_cust_accounts       f
        where 1 = 1
         and c.cust_acct_site_id = b.cust_acct_site_id
         and c.site_use_code     = 'SHIP_TO'
         and d.party_site_id     = b.party_site_id
         and e.location_id       = d.location_id
         and f.cust_account_id   = b.cust_account_id
         and f.cust_account_id   = cp_customer_id)
         WHERE cust_acc_status   = 'A';  
     

  begin
    fnd_global.apps_initialize(fnd_profile.value('user_id'),
                               fnd_profile.value('resp_id'),
                               fnd_profile.value('resp_app_id'));
    mo_global.init('AR');
    --FOR k IN c0 LOOP

    for i in c1(p_source_id) loop
      fnd_file.put_line(fnd_file.log, '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++');
          
          BEGIN
            SELECT PROFILE_CLASS_ID
            INTO L_PROFILE_CLASS_ID
            FROM HZ_CUST_PROFILE_CLASSES
            WHERE NAME = I.PROFILE_CLASS;
          EXCEPTION
            WHEN OTHERS THEN
            L_PROFILE_CLASS_ID := NULL;
          END;

          Fnd_File.PUT_LINE(Fnd_File.LOG,'Customer Name:' || i.customer_name );

          mo_global.set_policy_context('S', fnd_profile.value('org_id'));
      
          l_cust_account_rec_type.cust_account_id     :=i.erp_customer_id;
          l_cust_account_rec_type.customer_class_code := i.customer_class_code;
          l_cust_account_rec_type.attribute_category  := 'Customer Information';
         -- l_cust_account_rec_type.created_by_module   := l_created_by_module;
         -- l_cust_account_rec_type.customer_type       := i.customer_type;
         -- l_cust_account_rec_type.attribute3  := 'N'; --Club
         -- l_cust_account_rec_type.attribute7  := 'Not Applicable'; --Club name
     
          if i.customer_region is not null then
             l_cust_account_rec_type.attribute2          := i.customer_region; --Region belongs
          end if ;
          
          if i.dob is not null then 
             l_cust_account_rec_type.attribute8          := to_char(to_date(i.dob, 'dd-mon-rr'),  'yyyy/mm/dd hh24:mi:ss');
          end if;
          
          if i.wedding_date is not null then 
             l_cust_account_rec_type.attribute9          := to_char(to_date(i.wedding_date, 'dd-mon-rr'), 'yyyy/mm/dd hh24:mi:ss');
          end if;
          
          if i.quantity_discount is not null then 
             l_cust_account_rec_type.attribute6  := i.quantity_discount; --Qty Discount
          end if;
          
          if i.aadhar_number is not null then 
             l_cust_account_rec_type.attribute11 := i.aadhar_number; ---Aadhar number
          end if;
          
          if i.common_customer is not null then 
             l_cust_account_rec_type.attribute12 := i.common_customer; --Common Code
          end if;
   
      
         Hz_Cust_Account_V2pub.update_cust_account(p_init_msg_list        => Fnd_Api.g_true,
                                                    p_cust_account_rec     => l_cust_account_rec_type,
                                                    p_object_version_number =>i.object_version_number,
                                                    x_return_status        => x_return_status,
                                                    x_msg_count            => x_msg_count,
                                                    x_msg_data             => x_msg_data);

        
          Fnd_File.PUT_LINE(Fnd_File.LOG,'Customer Account Creation Status:' || x_return_status );
          dbms_output.PUT_LINE('Customer Account Updation Status:' || x_return_status );
        
        
        IF x_return_status <> Fnd_Api.G_RET_STS_SUCCESS THEN
          FOR I IN 1 .. x_msg_count LOOP
            Fnd_Msg_Pub.GET(P_MSG_INDEX     => I,
                            P_DATA          => x_msg_data,
                            P_ENCODED       => Fnd_Api.G_FALSE,
                            P_MSG_INDEX_OUT => x_msg_index_out);
            Fnd_File.PUT_LINE(Fnd_File.LOG,
                              'Error in customer Account Updation :' ||
                              x_msg_data);
          END LOOP;
          
          update sug_cp_customer_edit 
           set error_message = x_msg_data, status = 'E'
          where erp_customer_id = i.erp_customer_id
          AND SOURCE_ID=p_source_id;
          commit;
        ELSE
       
          customer_email_update();
   
          
          
          select distinct
              b.party_id  
              into ln_party_id
          from hz_cust_accounts  a,
               hz_parties        b
          where 1=1
          and a.account_number = i.erp_customer_number
          and b.party_id       = a.party_id;  --add 26032026
          
          SELECT MAX(object_version_number)
          INTO ln_object_version_number
          FROM hz_parties
          WHERE party_id = ln_party_id;
               

           l_organization_rec_type.party_rec.party_id := ln_party_id/*i.erp_party_id*/;
           l_organization_rec_type.party_rec.category_code := i.customer_category_code;
           if i.customer_name is not null then
             l_organization_rec_type.organization_name:=i.customer_name;
             l_organization_rec_type.organization_name_phonetic:=i.customer_name;
           end if;

           -- Calling ORGANIZATION update API
           HZ_PARTY_V2PUB.UPDATE_ORGANIZATION   ( p_init_msg_list                  =>  Fnd_Api.g_true,
                                                  p_organization_rec               =>  l_organization_rec_type,
                                                 p_party_object_version_number    =>  ln_object_version_number,
                                                 x_profile_id                     =>  ln_profile_id,
                                                 x_return_status                  =>  x_return_status,
                                                 x_msg_count                      =>  x_msg_count,
                                                 x_msg_data                       =>  x_msg_data
                                                );

           IF (x_return_status <> FND_API.G_RET_STS_SUCCESS)  THEN
             FOR i IN 1 .. FND_MSG_PUB.COUNT_MSG
             LOOP
               Fnd_Msg_Pub.GET(P_MSG_INDEX     => I,
                                  P_DATA          => x_msg_data,
                                  P_ENCODED       => Fnd_Api.G_FALSE,
                                  P_MSG_INDEX_OUT => x_msg_index_out);
                  Fnd_File.PUT_LINE(Fnd_File.LOG,
                                    'Error in customer Organization Updation :' ||
                                    x_msg_data);
                END LOOP;
                update sug_cp_customer_edit a
                   set error_message = x_msg_data, status = 'E'
                 where erp_customer_id = i.erp_customer_id
                    AND SOURCE_ID=p_source_id;
                commit;
                
             DBMS_OUTPUT.PUT_LINE('lv_msg:'||x_msg_data);
           ELSE
             update sug_cp_customer_edit 
             set error_message = null, status = 'Y'
             where erp_customer_id = i.erp_customer_id 
             AND NVL(status,'N') IN ('N','E')
                AND SOURCE_ID=p_source_id;
             commit;
   
           END IF; 
   
            --update account profile  
            hz_cust_account_v2pub.get_cust_account_rec(fnd_api.g_true,
                                                    i.erp_customer_id,
                                                    l_cust_account_rec_type,
                                                    l_customer_profile_rec_type,
                                                    x_return_status,
                                                    x_msg_count,
                                                    x_msg_data);
                                                    
            if l_profile_Class_id is not null then 
               l_customer_profile_rec_type.profile_class_id := l_profile_Class_id;
            end if;
   
            if i.payment_term is not null then
            -- select name  into l_customer_profile_rec_type.discount_terms from ra_terms where term_id=i.payment_term;
               l_customer_profile_rec_type.standard_terms:=i.payment_term;   
            end if; 
    
           select object_version_number
           into l_prof_class_ovn
           from hz_customer_profiles
           where cust_account_profile_id = l_customer_profile_rec_type.cust_account_profile_id;
   
  
           hz_customer_profile_v2pub.update_customer_profile(fnd_api.g_false,
                                                             l_customer_profile_rec_type,
                                                             l_prof_class_ovn,
                                                             x_return_status,
                                                             x_msg_count,
                                                             x_msg_data);
   
            IF X_RETURN_STATUS != FND_API.G_RET_STS_SUCCESS THEN
              if (fnd_msg_pub.count_msg > 1) then
                for k in 1..fnd_msg_pub.count_msg loop
                  fnd_msg_pub.get(p_msg_index => k, p_encoded => 'F',
                                 p_data => x_msg_data,
                                 p_msg_index_out => x_msg_index_out);
                  l_error_message := l_error_message || CHR(10) || x_msg_data;
                end loop;
                dbms_output.put_line ('customer profile updated Successfully "'
                               || i.customer_name || '": '
                               || l_error_message);
                               
                update sug_cp_customer_edit
                set error_message = null, 
                    status = 'Y'
                where erp_customer_id = i.erp_customer_id
                   AND SOURCE_ID=p_source_id;
                commit;
              else
                fnd_msg_pub.get(p_msg_index => 1, p_encoded => 'F',
                             p_data => x_msg_data, 
                             p_msg_index_out => x_msg_index_out);
                l_error_message := x_msg_data;
                       
                dbms_output.put_line ('Error in updating profile for customer "'
                                 || i.customer_name || '": '
                                 || l_error_message);
                       
                update sug_cp_customer_edit
                set error_message = null, status = 'E'
                where erp_customer_id = i.erp_customer_id
                   AND SOURCE_ID=p_source_id;
                commit;
              end if;
            END IF;
       
         
        END IF;
        
        
        l_catg_cnt := 0;
        if i.payment_term is not null and i.payment_term_to = 'AS' then  --Update Site Payment Terms
          
            /*begin
              SELECT COUNT(DISTINCT customer_category_code) 
                     into l_catg_cnt
              FROM (select b.customer_category_code
                    from hz_cust_acct_sites_all b,
                         hz_cust_site_uses_all  c,
                         hz_party_sites         d,
                         hz_locations           e,
                         hz_cust_accounts       f
                    where c.cust_acct_site_id = b.cust_acct_site_id
                      and c.site_use_code = 'BILL_TO'
                      and d.party_site_id = b.party_site_id
                      and e.location_id = d.location_id
                      and f.cust_account_id = b.cust_account_id
                      and b.status = 'A'
                      and f.account_number = i.erp_customer_id

                    UNION ALL

                    select b.customer_category_code
                    from hz_cust_acct_sites_all b,
                         hz_cust_site_uses_all  c,
                         hz_party_sites         d,
                         hz_locations           e,
                         hz_cust_accounts       f
                    where c.cust_acct_site_id = b.cust_acct_site_id
                      and c.site_use_code = 'SHIP_TO'
                      and d.party_site_id = b.party_site_id
                      and e.location_id = d.location_id
                      and f.cust_account_id = b.cust_account_id
                      and b.status = 'A'
                      and f.cust_account_id = i.erp_customer_id);
            exception
              when others then
                wt('Category Selection Caused Error '||SQLERRM);
            end;*/  
              
        
          if l_catg_cnt = 1 then
            l_obv_number    := null;
            for k in c_site(i.erp_customer_id) loop
              
                IF k.site_use_code = 'SHIP_TO' THEN
                   l_cust_site_use_rec_type.site_use_id             := k.site_use_id;
                   l_cust_site_use_rec_type.site_use_code           := k.site_use_code;
                   l_cust_site_use_rec_type.cust_acct_site_id       := k.cust_acct_site_id;
                   l_cust_site_use_rec_type.payment_term_id         := i.payment_term;
                   l_obv_number                                     := k.obj_cust;
                   
                   hz_cust_account_site_v2pub.update_cust_site_use(p_init_msg_list          => fnd_api.g_true,
                                                                    p_cust_site_use_rec     => l_cust_site_use_rec_type,
                                                                    p_object_version_number => l_obv_number,
                                                                    x_return_status         => x_return_status,
                                                                    x_msg_count             => x_msg_count,
                                                                    x_msg_data              => x_msg_data);
                                                                    
                                                                    
                    Fnd_File.PUT_LINE(Fnd_File.LOG,'Return Status of SHIP TO Payment Terms API :' ||x_return_status);				
                    dbms_output.put_line('Return Status of SHIP TO Payment Terms API :' ||x_return_status ||i.erp_customer_number );
                      				
                    IF x_return_status <> fnd_api.g_ret_sts_success THEN
                      FOR j IN 1 .. x_msg_count LOOP
                        fnd_msg_pub.get(
                        p_msg_index     => j,
                        p_data          => x_msg_data,
                        p_encoded       => fnd_api.g_false,
                        p_msg_index_out => x_msg_index_out
                        );
                      END LOOP;

                      /*UPDATE sug_cp_customer_site_edit
                      SET error_message = x_msg_data,
                         status        = 'E'
                      WHERE erp_customer_id       = i.erp_customer_id
                      AND erp_cust_acct_site_id = i.erp_cust_acct_site_id;
                      ELSE
                       update sug_cp_customer_site_edit
                         ---- set location_status = 'Y',
                           -- error_message   = null,
                         SET   status          = 'Y'
                        where  erp_customer_id= i.cust_id 
                        and  erp_cust_acct_site_id=i.erp_cust_acct_site_id 
                        and nvl(status,'N')='N'; */   
                    END IF;                                                 
                   
                ELSIF k.site_use_code = 'BILL_TO' THEN
                   l_cust_site_use_rec_type.site_use_id             := k.site_use_id;
                   l_cust_site_use_rec_type.site_use_code           := k.site_use_code;
                   l_cust_site_use_rec_type.cust_acct_site_id       := k.cust_acct_site_id;
                   l_cust_site_use_rec_type.payment_term_id         := i.payment_term;
                   l_obv_number                                     := k.obj_cust;
                   
                   hz_cust_account_site_v2pub.update_cust_site_use(p_init_msg_list          => fnd_api.g_true,
                                                                    p_cust_site_use_rec     => l_cust_site_use_rec_type,
                                                                    p_object_version_number => l_obv_number,
                                                                    x_return_status         => x_return_status,
                                                                    x_msg_count             => x_msg_count,
                                                                    x_msg_data              => x_msg_data);
                                                                    
                                                                    
                   Fnd_File.PUT_LINE(Fnd_File.LOG,'Return Status of BILL TO Payment Terms API :' ||x_return_status);				
                   dbms_output.put_line('Return Status of BILL TO Payment Terms API :' ||x_return_status ||i.erp_customer_number );
                      				
                    IF x_return_status <> fnd_api.g_ret_sts_success THEN
                      FOR j IN 1 .. x_msg_count LOOP
                        fnd_msg_pub.get(
                        p_msg_index     => j,
                        p_data          => x_msg_data,
                        p_encoded       => fnd_api.g_false,
                        p_msg_index_out => x_msg_index_out
                        );
                      END LOOP;

                      /*UPDATE sug_cp_customer_site_edit
                      SET error_message = x_msg_data,
                         status        = 'E'
                      WHERE erp_customer_id       = i.erp_customer_id
                      AND erp_cust_acct_site_id = i.erp_cust_acct_site_id;
                      ELSE
                       update sug_cp_customer_site_edit
                         ---- set location_status = 'Y',
                           -- error_message   = null,
                         SET   status          = 'Y'
                        where  erp_customer_id= i.cust_id 
                        and  erp_cust_acct_site_id=i.erp_cust_acct_site_id 
                        and nvl(status,'N')='N'; */   
                    END IF;                                                        
                   
                END IF;
                
            end loop;
          else
            wt('Update Only Allow Same Catgeory Code Exists '||i.erp_customer_id);  
            
          end if;
        end if;
        
        
      Fnd_File.PUT_LINE(Fnd_File.LOG, '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++');
    end loop;
    -- end loop;
  end;

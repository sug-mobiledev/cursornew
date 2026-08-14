procedure customer_creation as
    l_created_by_module          varchar2(100) := 'CUST_INTERFACE';
    l_organization_rec_type      Hz_Party_V2pub.ORGANIZATION_REC_TYPE;
    l_cust_account_rec_type      Hz_Cust_Account_V2pub.CUST_ACCOUNT_REC_TYPE;
    l_customer_profile_rec_type  Hz_Customer_Profile_V2pub.CUSTOMER_PROFILE_REC_TYPE;
    l_cust_profile_amt_rec_type  HZ_CUSTOMER_PROFILE_V2PUB.cust_profile_amt_rec_type;
    x_cust_account_id            number;
    x_account_number             varchar2(30);
    x_party_id                   number;
    x_party_number               varchar2(30);
    x_profile_id                 number;
    x_return_status              varchar2(3000);
    x_msg_count                  varchar2(30);
    x_msg_data                   varchar2(3000);
    x_msg_index_out              varchar2(30);
    l_profile_Class_id           number;
    l_cust_account_profile_id    number;
    v_cust_act_prof_amt_id       number;
    cursor c1 is
      select a.cust_id,
             a.customer_name,
             a.customer_class_code,
             a.customer_type,
             a.customer_region,
             a.customer_category_code,
             a.profile_class,
             a.dob,
             a.wedding_date,
             a.aadhar_no,
             a.currency
        from sug_cp_customer a
       where nvl(a.status, 'N') = 'N'
         and a.erp_creation_date between trunc(sysdate-15) and sysdate
         and trunc(a.erp_creation_date) >= '1-jul-20';

  begin
    fnd_global.apps_initialize(fnd_profile.value('user_id'),
                               fnd_profile.value('resp_id'),
                               fnd_profile.value('resp_app_id'));
    mo_global.init('AR');

    for i in c1 loop
      Fnd_File.PUT_LINE(Fnd_File.LOG, '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++');
      begin
        SELECT profile_class_id
          INTO l_profile_Class_id
          FROM hz_cust_profile_classes
         WHERE NAME = i.profile_class;
      exception
        when others then
          l_profile_Class_id := NULL;
      end;

      Fnd_File.PUT_LINE(Fnd_File.LOG,
                        'Customer Name:' || i.customer_name );

      mo_global.set_policy_context('S', fnd_profile.value('org_id'));
      l_cust_account_rec_type.customer_class_code := i.customer_class_code;
      l_cust_account_rec_type.created_by_module   := l_created_by_module;
      l_cust_account_rec_type.attribute_category  := 'Customer Information';
      l_cust_account_rec_type.customer_type       := i.customer_type;
      l_cust_account_rec_type.attribute2          := i.customer_region; --Region belongs
      l_cust_account_rec_type.attribute8          := TO_CHAR(TO_DATE(i.dob,
                                                                     'DD-MON-RR'),
                                                             'YYYY/MM/DD HH24:MI:SS');
      l_cust_account_rec_type.attribute9          := TO_CHAR(TO_DATE(i.wedding_date,
                                                                     'DD-MON-RR'),
                                                             'YYYY/MM/DD HH24:MI:SS');

      l_cust_account_rec_type.attribute3  := 'N'; --Club
      l_cust_account_rec_type.attribute6  := 'No'; --Qty Discount
      l_cust_account_rec_type.attribute7  := 'Not Applicable'; --Club name
      l_cust_account_rec_type.attribute11 := i.aadhar_no; ---Aadhar number
      l_cust_account_rec_type.attribute12 := 'N'; --Common Code

      l_organization_rec_type.created_by_module          := l_created_by_module;
      l_organization_rec_type.organization_name          := i.customer_name;
      l_organization_rec_type.organization_name_phonetic := i.customer_name;
      l_organization_rec_type.party_rec.category_code    := i.customer_category_code;
      l_customer_profile_rec_type.profile_class_id       := l_profile_Class_id;
      l_customer_profile_rec_type.created_by_module      := l_created_by_module;


      --grouping rule id update
      begin
          select distinct
               c.grouping_rule_id
          into l_customer_profile_rec_type.grouping_rule_id
          from fnd_lookup_values   a,
               sug_org_mst_v       b,
               ra_grouping_rules   c
          where 1=1
          and a.lookup_type   = 'SUG_GROUPING_RULES'
          and a.enabled_flag  = 'Y'
          and trunc(sysdate) between a.start_date_active and nvl(a.end_date_active,trunc(sysdate))
          and a.tag           = b.ledger_id
          and a.description is null
          and c.name          = a.meaning
          and b.org_id        = i.customer_region;
      end;


      Hz_Cust_Account_V2pub.create_cust_account(p_init_msg_list        => Fnd_Api.G_TRUE,
                                                p_cust_account_rec     => l_cust_account_rec_type,
                                                p_organization_rec     => l_organization_rec_type,
                                                p_customer_profile_rec => l_customer_profile_rec_type,
                                                p_create_profile_amt   => Fnd_Api.G_FALSE,
                                                x_cust_account_id      => x_cust_account_id,
                                                x_account_number       => x_account_number,
                                                x_party_id             => x_party_id,
                                                x_party_number         => x_party_number,
                                                x_profile_id           => x_profile_id,
                                                x_return_status        => x_return_status,
                                                x_msg_count            => x_msg_count,
                                                x_msg_data             => x_msg_data);
      Fnd_File.PUT_LINE(Fnd_File.LOG,
                        'Customer Account Creation Status:' || x_return_status );
      IF x_return_status <> Fnd_Api.G_RET_STS_SUCCESS THEN
        FOR I IN 1 .. x_msg_count LOOP
          Fnd_Msg_Pub.GET(P_MSG_INDEX     => I,
                          P_DATA          => x_msg_data,
                          P_ENCODED       => Fnd_Api.G_FALSE,
                          P_MSG_INDEX_OUT => x_msg_index_out);
          Fnd_File.PUT_LINE(Fnd_File.LOG,
                            'Error in customer Account Creation :' ||
                            x_msg_data);
        END LOOP;
        update sug_cp_customer
           set error_message = x_msg_data, status = 'E'
         where cust_id = i.cust_id;
        commit;
      ELSE
      begin
         SELECT cust_account_profile_id into l_cust_account_profile_id
           FROM   hz_customer_profiles
           WHERE  cust_account_id         = x_cust_account_id ;
           exception when others then
             l_cust_account_profile_id := null;
        end;
       if l_cust_account_profile_id is not null then
       l_cust_profile_amt_rec_type.cust_account_profile_id :=l_cust_account_profile_id ;
       l_cust_profile_amt_rec_type.cust_account_id    :=  x_cust_account_id;
       l_cust_profile_amt_rec_type.currency_code      := i.currency;
       l_cust_profile_amt_rec_type.overall_credit_limit := 0;
       l_cust_profile_amt_rec_type.created_by_module  := l_created_by_module;

        HZ_CUSTOMER_PROFILE_V2PUB.create_cust_profile_amt
        (
        p_init_msg_list => 'T' ,
        p_check_foreign_key => FND_API.G_TRUE,
        p_cust_profile_amt_rec => l_cust_profile_amt_rec_type,
        x_cust_acct_profile_amt_id => v_cust_act_prof_amt_id,
        x_return_status        => x_return_status,
        x_msg_count            => x_msg_count,
        x_msg_data             => x_msg_data
        );

      IF x_return_status <> Fnd_Api.G_RET_STS_SUCCESS THEN
        FOR I IN 1 .. x_msg_count LOOP
          Fnd_Msg_Pub.GET(P_MSG_INDEX     => I,
                          P_DATA          => x_msg_data,
                          P_ENCODED       => Fnd_Api.G_FALSE,
                          P_MSG_INDEX_OUT => x_msg_index_out);
          Fnd_File.PUT_LINE(Fnd_File.LOG,
                            'Error in customer profile amount Creation :' ||
                            x_msg_data);
        END LOOP;
        end if;
        end if;
        Fnd_File.PUT_LINE(Fnd_File.LOG, 'Customer Account Created Successfully');
        Fnd_File.PUT_LINE(Fnd_File.LOG,
                          'Customer Account ID :' || x_cust_account_id);
        Fnd_File.PUT_LINE(Fnd_File.LOG,
                          'Customer Account Number:' || x_account_number);
        Fnd_File.PUT_LINE(Fnd_File.LOG, 'Party ID :' || x_party_id);
        Fnd_File.PUT_LINE(Fnd_File.LOG, 'Cust profile amount ID :' || v_cust_act_prof_amt_id);
        update sug_cp_customer
           set erp_customer_id     = x_cust_account_id,
               erp_customer_number = x_account_number,
               erp_party_id        = x_party_id,
               error_message       = null,
               status              = 'Y'
         where cust_id = i.cust_id;
        commit;
      END IF;
      Fnd_File.PUT_LINE(Fnd_File.LOG, '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++');
    end loop;
  end;

-------------------------------------------------------------------------------
-- Restrict manual Cancel on the Sales Orders form (OEXOEORD)
--
-- Form     : OEXOEORD (Sales Orders / order creation screen)
-- Function : ONT_OEXOEORD
-- Rule key : SUG_OEXOEORD_NO_MANUAL_CANCEL
--
-- When a user opens Actions from Order Information or Line Items and
-- highlights Cancel, Forms Personalization raises an error and stops the
-- action. System / API cancellation is not affected.
--
-- Run as APPS. Re-runnable: skips insert if RULE_KEY already exists.
-- Preferred install for TEST/PROD after validating in DEV via the form UI
-- (see sql/oexoeord_restrict_manual_cancel_setup_notes.sql).
-------------------------------------------------------------------------------

set serveroutput on size unlimited
set define off

declare
  l_user_id      number;
  l_login_id     number;
  l_rule_id      number;
  l_action_id    number;
  l_sequence     number;
  l_exists       number;
  l_msg          varchar2(4000);
begin
  l_user_id  := nvl(fnd_global.user_id, 0);
  l_login_id := nvl(fnd_global.login_id, -1);

  select count(*)
    into l_exists
    from fnd_form_custom_rules
   where rule_key = 'SUG_OEXOEORD_NO_MANUAL_CANCEL';

  if l_exists > 0 then
    dbms_output.put_line(
      'Personalization SUG_OEXOEORD_NO_MANUAL_CANCEL already exists. No changes made.');
    return;
  end if;

  select nvl(max(sequence), 0) + 10
    into l_sequence
    from fnd_form_custom_rules
   where form_name = 'OEXOEORD';

  select fnd_form_custom_rules_s.nextval
    into l_rule_id
    from dual;

  insert into fnd_form_custom_rules (
    id,
    sequence,
    function_name,
    form_name,
    description,
    trigger_event,
    trigger_object,
    condition,
    enabled,
    fire_in_enter_query,
    rule_type,
    rule_key,
    created_by,
    creation_date,
    last_updated_by,
    last_update_date,
    last_update_login
  ) values (
    l_rule_id,
    l_sequence,
    'ONT_OEXOEORD',
    'OEXOEORD',
    'Restrict manual Cancel from Actions',
    'WHEN-NEW-RECORD-INSTANCE',
    'ACTIONS',
    q'[UPPER(LTRIM(RTRIM(:ACTIONS.ACTION))) = 'CANCEL']',
    'Y',
    'N',
    'F',
    'SUG_OEXOEORD_NO_MANUAL_CANCEL',
    l_user_id,
    sysdate,
    l_user_id,
    sysdate,
    l_login_id
  );

  insert into fnd_form_custom_scopes (
    rule_id,
    level_id,
    level_value,
    level_value_application_id,
    created_by,
    creation_date,
    last_updated_by,
    last_update_date,
    last_update_login
  ) values (
    l_rule_id,
    10001,   -- Site
    0,
    0,
    l_user_id,
    sysdate,
    l_user_id,
    sysdate,
    l_login_id
  );

  select fnd_form_custom_actions_s.nextval
    into l_action_id
    from dual;

  insert into fnd_form_custom_actions (
    action_id,
    rule_id,
    sequence,
    action_type,
    enabled,
    language,
    message_type,
    message_text,
    summary,
    created_by,
    creation_date,
    last_updated_by,
    last_update_date,
    last_update_login
  ) values (
    l_action_id,
    l_rule_id,
    10,
    'M',     -- Message
    'Y',
    '*',
    'E',     -- Error (raises form_trigger_failure)
    'Manual Cancel is not allowed from the Sales Order form. Please contact the Order Management administrator.',
    'Block Actions > Cancel',
    l_user_id,
    sysdate,
    l_user_id,
    sysdate,
    l_login_id
  );

  commit;

  dbms_output.put_line('Installed Forms Personalization:');
  dbms_output.put_line('  RULE_KEY  = SUG_OEXOEORD_NO_MANUAL_CANCEL');
  dbms_output.put_line('  RULE_ID   = ' || l_rule_id);
  dbms_output.put_line('  SEQUENCE  = ' || l_sequence);
  dbms_output.put_line('  ACTION_ID = ' || l_action_id);
  dbms_output.put_line('Close and reopen Sales Orders for the rule to take effect.');
exception
  when others then
    rollback;
    l_msg := sqlerrm;
    dbms_output.put_line('Install failed: ' || l_msg);
    raise;
end;
/

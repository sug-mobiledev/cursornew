-------------------------------------------------------------------------------
-- Restrict manual Cancel on the Sales Orders form (OEXOEORD)
--
-- Form     : OEXOEORD (Sales Orders / order creation screen)
-- Function : ONT_OEXOEORD
--
-- Rule keys:
--   SUG_OEXOEORD_BLOCK_CANCEL_SELECT  (enabled)  select Cancel in Actions
--   SUG_OEXOEORD_BLOCK_CANCEL_OK      (enabled)  OK with Cancel selected
--   SUG_OEXOEORD_HIDE_CANCEL          (disabled) remove Cancel from the list
--
-- Run as APPS. Re-runnable: replaces the SUG_OEXOEORD_*CANCEL* rules above.
-- After install, close and reopen Sales Orders.
-- UI key-in steps: sql/oexoeord_restrict_manual_cancel_setup_notes.sql
-------------------------------------------------------------------------------

set serveroutput on size unlimited
set define off

declare
  l_user_id   number;
  l_login_id  number;
  l_sequence  number;
  l_msg       varchar2(4000);

  procedure delete_owned_rules is
  begin
    delete from fnd_form_custom_params
     where action_id in (
             select a.action_id
               from fnd_form_custom_actions a,
                    fnd_form_custom_rules r
              where a.rule_id = r.id
                and r.rule_key in ('SUG_OEXOEORD_NO_MANUAL_CANCEL',
                                   'SUG_OEXOEORD_BLOCK_CANCEL_SELECT',
                                   'SUG_OEXOEORD_BLOCK_CANCEL_OK',
                                   'SUG_OEXOEORD_HIDE_CANCEL'));

    delete from fnd_form_custom_actions
     where rule_id in (
             select id
               from fnd_form_custom_rules
              where rule_key in ('SUG_OEXOEORD_NO_MANUAL_CANCEL',
                                 'SUG_OEXOEORD_BLOCK_CANCEL_SELECT',
                                 'SUG_OEXOEORD_BLOCK_CANCEL_OK',
                                 'SUG_OEXOEORD_HIDE_CANCEL'));

    delete from fnd_form_custom_scopes
     where rule_id in (
             select id
               from fnd_form_custom_rules
              where rule_key in ('SUG_OEXOEORD_NO_MANUAL_CANCEL',
                                 'SUG_OEXOEORD_BLOCK_CANCEL_SELECT',
                                 'SUG_OEXOEORD_BLOCK_CANCEL_OK',
                                 'SUG_OEXOEORD_HIDE_CANCEL'));

    delete from fnd_form_custom_rules
     where rule_key in ('SUG_OEXOEORD_NO_MANUAL_CANCEL',
                        'SUG_OEXOEORD_BLOCK_CANCEL_SELECT',
                        'SUG_OEXOEORD_BLOCK_CANCEL_OK',
                        'SUG_OEXOEORD_HIDE_CANCEL');
  end delete_owned_rules;

  procedure add_scope(p_rule_id number) is
  begin
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
      p_rule_id,
      10001,  -- Site
      0,
      0,
      l_user_id,
      sysdate,
      l_user_id,
      sysdate,
      l_login_id
    );
  end add_scope;

  function add_rule(
    p_seq           number,
    p_rule_key      varchar2,
    p_description   varchar2,
    p_trigger_event varchar2,
    p_enabled       varchar2
  ) return number is
    l_rule_id number;
  begin
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
      p_seq,
      'ONT_OEXOEORD',
      'OEXOEORD',
      p_description,
      p_trigger_event,
      'ACTIONS',
      q'[UPPER(LTRIM(RTRIM(:ACTIONS.ACTION))) = 'CANCEL']',
      p_enabled,
      'N',
      'F',
      p_rule_key,
      l_user_id,
      sysdate,
      l_user_id,
      sysdate,
      l_login_id
    );

    add_scope(l_rule_id);
    return l_rule_id;
  end add_rule;

  procedure add_error_action(p_rule_id number, p_summary varchar2) is
    l_action_id number;
  begin
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
      p_rule_id,
      10,
      'M',
      'Y',
      '*',
      'E',
      'Manual Cancel is not allowed from the Sales Order form. Please contact the Order Management administrator.',
      p_summary,
      l_user_id,
      sysdate,
      l_user_id,
      sysdate,
      l_login_id
    );
  end add_error_action;

  procedure add_hide_action(p_rule_id number) is
    l_action_id number;
  begin
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
      builtin_type,
      builtin_arguments,
      summary,
      created_by,
      creation_date,
      last_updated_by,
      last_update_date,
      last_update_login
    ) values (
      l_action_id,
      p_rule_id,
      10,
      'B',
      'Y',
      '*',
      'DO_KEY',
      'DELETE_RECORD',
      'Hide Cancel from Actions list',
      l_user_id,
      sysdate,
      l_user_id,
      sysdate,
      l_login_id
    );
  end add_hide_action;

begin
  l_user_id  := nvl(fnd_global.user_id, 0);
  l_login_id := nvl(fnd_global.login_id, -1);

  delete_owned_rules;

  select nvl(max(sequence), 0)
    into l_sequence
    from fnd_form_custom_rules
   where form_name = 'OEXOEORD';

  -- Rule 1: block highlighting / selecting Cancel in the Actions list
  add_error_action(
    add_rule(
      l_sequence + 10,
      'SUG_OEXOEORD_BLOCK_CANCEL_SELECT',
      'Restrict manual Cancel - block select',
      'WHEN-NEW-RECORD-INSTANCE',
      'Y'),
    'Error when Cancel is selected');

  -- Rule 2: block OK if Cancel is still the current action
  add_error_action(
    add_rule(
      l_sequence + 20,
      'SUG_OEXOEORD_BLOCK_CANCEL_OK',
      'Restrict manual Cancel - block OK',
      'WHEN-VALIDATE-RECORD',
      'Y'),
    'Error when OK is used on Cancel');

  -- Rule 3: hide Cancel from the list (off until tested in DEV)
  add_hide_action(
    add_rule(
      l_sequence + 30,
      'SUG_OEXOEORD_HIDE_CANCEL',
      'Restrict manual Cancel - hide from list',
      'WHEN-NEW-RECORD-INSTANCE',
      'N'));

  commit;

  dbms_output.put_line('Installed OEXOEORD Cancel restriction personalizations.');
  dbms_output.put_line('  SUG_OEXOEORD_BLOCK_CANCEL_SELECT  enabled Y  (WHEN-NEW-RECORD-INSTANCE)');
  dbms_output.put_line('  SUG_OEXOEORD_BLOCK_CANCEL_OK      enabled Y  (WHEN-VALIDATE-RECORD)');
  dbms_output.put_line('  SUG_OEXOEORD_HIDE_CANCEL          enabled N  (DELETE_RECORD; enable after DEV test)');
  dbms_output.put_line('Close and reopen Sales Orders for the rules to take effect.');
exception
  when others then
    rollback;
    l_msg := sqlerrm;
    dbms_output.put_line('Install failed: ' || l_msg);
    raise;
end;
/

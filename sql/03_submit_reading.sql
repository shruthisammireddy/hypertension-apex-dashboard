-- 03_submit_reading.sql
-- Stored procedure SUBMIT_READING.
-- One call = store the reading, check it against THRESHOLDS,
-- save the quality and priority results, and create any alerts.
--
-- How to run:
--   SQL Scripts : upload this file and Run (the "/" on the last line is needed).
--   SQL Commands: paste everything from "create or replace" to the final "end submit_reading;"
--                 (leave out the "/"), then Run. Expected: "Procedure created."
--
-- The procedure does not COMMIT. The caller commits:
-- an APEX page commits automatically; the sample-data script commits at its end.

create or replace procedure submit_reading (
  p_patient_id        in number,
  p_measured_at       in timestamp,
  p_systolic          in number,
  p_diastolic         in number,
  p_pulse_rate        in number   default null,
  p_spo2              in number   default null,
  p_body_weight_kg    in number   default null,
  p_medication_status in varchar2 default 'Unknown',
  p_symptom_report    in varchar2 default null
) is
  v_reading_id   number;
  v_submitted_at timestamp     := localtimestamp;
  v_medication   varchar2(7)   := nvl(p_medication_status, 'Unknown');
  v_count        number;

  v_quality      varchar2(8)   := 'Accepted';
  v_q_expl       varchar2(4000);
  v_priority     varchar2(12)  := 'Not assigned';
  v_p_expl       varchar2(4000);

  -- alerts collected during the checks, inserted at the end
  type t_short is table of varchar2(30)   index by pls_integer;
  type t_long  is table of varchar2(4000) index by pls_integer;
  v_alert_rule   t_short;
  v_alert_type   t_short;
  v_alert_text   t_long;
  v_alert_count  pls_integer := 0;

  -- single values used inside the INSERT statement
  v_rule_id      varchar2(30);
  v_type         varchar2(30);
  v_text         varchar2(4000);

  -- rule values read from THRESHOLDS
  v_sys_rej_low    number;
  v_sys_rej_high   number;
  v_dia_rej_low    number;
  v_dia_rej_high   number;
  v_pulse_rej_low  number;
  v_pulse_rej_high number;
  v_spo2_rej_low   number;
  v_spo2_rej_high  number;
  v_wt_rej_low     number;
  v_wt_rej_high    number;
  v_future_min     number;
  v_sys_rev_high   number;
  v_dia_rev_high   number;
  v_pulse_rev_low  number;
  v_pulse_rev_high number;
  v_backdate_days  number;
  v_p_sys_high     number;
  v_p_dia_high     number;
  v_p_spo2_high    number;
  v_p_sys_raised   number;
  v_p_dia_raised   number;

  -- Reads one rule value from THRESHOLDS
  function rule_value(p_rule_id in varchar2) return number is
    v_value number;
  begin
    select numeric_value into v_value from thresholds where rule_id = p_rule_id;
    return v_value;
  exception
    when no_data_found then
      raise_application_error(-20010, 'Rule ' || p_rule_id || ' is missing from THRESHOLDS.');
  end rule_value;

  -- Adds text to an explanation, separated by "; "
  procedure append(p_target in out varchar2, p_text in varchar2) is
  begin
    if p_target is null then
      p_target := substr(p_text, 1, 4000);
    else
      p_target := substr(p_target || '; ' || p_text, 1, 4000);
    end if;
  end append;

  -- Remembers an alert to insert later
  procedure add_alert(p_rule in varchar2, p_type in varchar2, p_text in varchar2) is
  begin
    v_alert_count := v_alert_count + 1;
    v_alert_rule(v_alert_count) := p_rule;
    v_alert_type(v_alert_count) := p_type;
    v_alert_text(v_alert_count) := substr(p_text, 1, 4000);
  end add_alert;

  -- Data-quality finding. Rejected always wins over Review.
  procedure quality_flag(p_level in varchar2, p_rule in varchar2, p_text in varchar2) is
  begin
    if p_level = 'Rejected' then
      v_quality := 'Rejected';
    elsif v_quality <> 'Rejected' then
      v_quality := 'Review';
    end if;
    append(v_q_expl, p_level || ': ' || p_text);
    add_alert(p_rule, 'DATA_QUALITY', p_level || ': ' || p_text);
  end quality_flag;

  -- Demonstration priority finding. Only High creates an alert.
  procedure priority_flag(p_level in varchar2, p_rule in varchar2, p_text in varchar2) is
  begin
    if p_level = 'High' then
      v_priority := 'High';
      add_alert(p_rule, 'REVIEW_PRIORITY',
                'High: ' || p_text || '. Demonstration rule, not clinical advice.');
    elsif v_priority = 'Routine' then
      v_priority := 'Raised';
    end if;
    append(v_p_expl, p_level || ': ' || p_text);
  end priority_flag;

begin
  -- 1. Required input ----------------------------------------------------
  if p_patient_id is null or p_measured_at is null
     or p_systolic is null or p_diastolic is null then
    raise_application_error(-20001, 'Patient, measured date/time, systolic and diastolic are required.');
  end if;

  select count(*) into v_count from patients where patient_id = p_patient_id;
  if v_count = 0 then
    raise_application_error(-20003, 'Patient ' || p_patient_id || ' does not exist.');
  end if;

  -- 2. Store the reading (results still Pending) --------------------------
  begin
    insert into readings (patient_id, measured_at, systolic, diastolic, pulse_rate, spo2,
                          body_weight_kg, medication_status, symptom_report, submitted_at)
    values (p_patient_id, p_measured_at, p_systolic, p_diastolic, p_pulse_rate, p_spo2,
            p_body_weight_kg, v_medication, p_symptom_report, v_submitted_at)
    returning reading_id into v_reading_id;
  exception
    when dup_val_on_index then
      raise_application_error(-20002,
        'Duplicate reading: this patient already has a reading with the same date/time and blood pressure.');
  end;

  -- 3. Load the rule values ---------------------------------------------
  v_sys_rej_low    := rule_value('Q_SYS_REJECT_LOW');
  v_sys_rej_high   := rule_value('Q_SYS_REJECT_HIGH');
  v_dia_rej_low    := rule_value('Q_DIA_REJECT_LOW');
  v_dia_rej_high   := rule_value('Q_DIA_REJECT_HIGH');
  v_pulse_rej_low  := rule_value('Q_PULSE_REJECT_LOW');
  v_pulse_rej_high := rule_value('Q_PULSE_REJECT_HIGH');
  v_spo2_rej_low   := rule_value('Q_SPO2_REJECT_LOW');
  v_spo2_rej_high  := rule_value('Q_SPO2_REJECT_HIGH');
  v_wt_rej_low     := rule_value('Q_WEIGHT_REJECT_LOW');
  v_wt_rej_high    := rule_value('Q_WEIGHT_REJECT_HIGH');
  v_future_min     := rule_value('Q_FUTURE_MINUTES');
  v_sys_rev_high   := rule_value('Q_SYS_REVIEW_HIGH');
  v_dia_rev_high   := rule_value('Q_DIA_REVIEW_HIGH');
  v_pulse_rev_low  := rule_value('Q_PULSE_REVIEW_LOW');
  v_pulse_rev_high := rule_value('Q_PULSE_REVIEW_HIGH');
  v_backdate_days  := rule_value('Q_BACKDATE_DAYS');
  v_p_sys_high     := rule_value('P_SYS_HIGH');
  v_p_dia_high     := rule_value('P_DIA_HIGH');
  v_p_spo2_high    := rule_value('P_SPO2_HIGH');
  v_p_sys_raised   := rule_value('P_SYS_RAISED');
  v_p_dia_raised   := rule_value('P_DIA_RAISED');

  -- 4. Stage 1: data-quality checks -------------------------------------
  -- Blood pressure pair (fixed logic)
  if p_systolic <= p_diastolic then
    quality_flag('Rejected', 'H_BP_PAIR',
      'systolic ' || p_systolic || ' is not higher than diastolic ' || p_diastolic);
  end if;

  -- Systolic
  if p_systolic < v_sys_rej_low then
    quality_flag('Rejected', 'Q_SYS_REJECT_LOW', 'systolic ' || p_systolic || ' is below ' || v_sys_rej_low);
  elsif p_systolic > v_sys_rej_high then
    quality_flag('Rejected', 'Q_SYS_REJECT_HIGH', 'systolic ' || p_systolic || ' is above ' || v_sys_rej_high);
  elsif p_systolic > v_sys_rev_high then
    quality_flag('Review', 'Q_SYS_REVIEW_HIGH', 'systolic ' || p_systolic || ' is above ' || v_sys_rev_high || '; please confirm');
  end if;

  -- Diastolic
  if p_diastolic < v_dia_rej_low then
    quality_flag('Rejected', 'Q_DIA_REJECT_LOW', 'diastolic ' || p_diastolic || ' is below ' || v_dia_rej_low);
  elsif p_diastolic > v_dia_rej_high then
    quality_flag('Rejected', 'Q_DIA_REJECT_HIGH', 'diastolic ' || p_diastolic || ' is above ' || v_dia_rej_high);
  elsif p_diastolic > v_dia_rev_high then
    quality_flag('Review', 'Q_DIA_REVIEW_HIGH', 'diastolic ' || p_diastolic || ' is above ' || v_dia_rev_high || '; please confirm');
  end if;

  -- Pulse rate (optional)
  if p_pulse_rate is not null then
    if p_pulse_rate < v_pulse_rej_low then
      quality_flag('Rejected', 'Q_PULSE_REJECT_LOW', 'pulse ' || p_pulse_rate || ' is below ' || v_pulse_rej_low);
    elsif p_pulse_rate > v_pulse_rej_high then
      quality_flag('Rejected', 'Q_PULSE_REJECT_HIGH', 'pulse ' || p_pulse_rate || ' is above ' || v_pulse_rej_high);
    elsif p_pulse_rate < v_pulse_rev_low then
      quality_flag('Review', 'Q_PULSE_REVIEW_LOW', 'pulse ' || p_pulse_rate || ' is below ' || v_pulse_rev_low || '; please confirm');
    elsif p_pulse_rate > v_pulse_rev_high then
      quality_flag('Review', 'Q_PULSE_REVIEW_HIGH', 'pulse ' || p_pulse_rate || ' is above ' || v_pulse_rev_high || '; please confirm');
    end if;
  end if;

  -- SpO2 (optional)
  if p_spo2 is not null then
    if p_spo2 < v_spo2_rej_low then
      quality_flag('Rejected', 'Q_SPO2_REJECT_LOW', 'SpO2 ' || p_spo2 || '% is below ' || v_spo2_rej_low || '%');
    elsif p_spo2 > v_spo2_rej_high then
      quality_flag('Rejected', 'Q_SPO2_REJECT_HIGH', 'SpO2 ' || p_spo2 || '% is above ' || v_spo2_rej_high || '%');
    end if;
  end if;

  -- Body weight (optional)
  if p_body_weight_kg is not null then
    if p_body_weight_kg < v_wt_rej_low then
      quality_flag('Rejected', 'Q_WEIGHT_REJECT_LOW', 'weight ' || p_body_weight_kg || ' kg is below ' || v_wt_rej_low || ' kg');
    elsif p_body_weight_kg > v_wt_rej_high then
      quality_flag('Rejected', 'Q_WEIGHT_REJECT_HIGH', 'weight ' || p_body_weight_kg || ' kg is above ' || v_wt_rej_high || ' kg');
    end if;
  end if;

  -- Dates
  if p_measured_at > v_submitted_at + numtodsinterval(v_future_min, 'MINUTE') then
    quality_flag('Rejected', 'Q_FUTURE_MINUTES', 'measured time is in the future');
  elsif p_measured_at < v_submitted_at - numtodsinterval(v_backdate_days, 'DAY') then
    quality_flag('Review', 'Q_BACKDATE_DAYS',
      'measured more than ' || v_backdate_days || ' days before it was entered; please confirm the date');
  end if;

  if v_quality = 'Accepted' then
    v_q_expl := 'All data-quality checks passed.';
  end if;

  -- 5. Stage 2: demonstration priority (Accepted readings only) -----------
  if v_quality = 'Accepted' then
    v_priority := 'Routine';

    if p_systolic >= v_p_sys_high then
      priority_flag('High', 'P_SYS_HIGH', 'systolic ' || p_systolic || ' is at or above ' || v_p_sys_high);
    end if;
    if p_diastolic >= v_p_dia_high then
      priority_flag('High', 'P_DIA_HIGH', 'diastolic ' || p_diastolic || ' is at or above ' || v_p_dia_high);
    end if;
    if p_spo2 is not null and p_spo2 < v_p_spo2_high then
      priority_flag('High', 'P_SPO2_HIGH', 'SpO2 ' || p_spo2 || '% is below ' || v_p_spo2_high || '%');
    end if;
    if p_systolic >= v_p_sys_raised then
      priority_flag('Raised', 'P_SYS_RAISED', 'systolic ' || p_systolic || ' is at or above ' || v_p_sys_raised);
    end if;
    if p_diastolic >= v_p_dia_raised then
      priority_flag('Raised', 'P_DIA_RAISED', 'diastolic ' || p_diastolic || ' is at or above ' || v_p_dia_raised);
    end if;

    if v_p_expl is null then
      v_p_expl := 'Routine: no demonstration priority rule was triggered.';
    else
      v_p_expl := substr('Demonstration rules, not clinical advice. ' || v_p_expl, 1, 4000);
    end if;
  elsif v_quality = 'Review' then
    v_p_expl := 'Not assigned: the reading needs confirmation before any priority is given.';
  else
    v_p_expl := 'Not assigned: the reading was rejected as a data-quality problem.';
  end if;

  -- 6. Save the results on the reading ------------------------------------
  update readings
     set quality_status       = v_quality,
         quality_explanation  = v_q_expl,
         priority_status      = v_priority,
         priority_explanation = v_p_expl,
         processed_at         = localtimestamp
   where reading_id = v_reading_id;

  -- 7. Create the alerts ---------------------------------------------------
  for i in 1 .. v_alert_count loop
    v_rule_id := v_alert_rule(i);
    v_type    := v_alert_type(i);
    v_text    := v_alert_text(i);
    insert into alerts (reading_id, rule_id, alert_type, explanation)
    values (v_reading_id, v_rule_id, v_type, v_text);
  end loop;
end submit_reading;
/

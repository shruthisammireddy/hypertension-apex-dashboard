-- 04_sample_readings.sql
-- Loads synthetic SOFTWARE-TEST readings by calling SUBMIT_READING,
-- so every reading is checked by the real rules. Not real clinical data.
--
-- Run after 01, 02 and 03, in SQL Workshop > SQL Scripts.
-- Dates are relative to the day you run it, so the future-date and
-- backdated cases always behave the same.
--
-- Expected result (shown by the queries at the end):
--   64 readings: 47 Accepted, 5 Review, 12 Rejected, 0 Pending
--   21 alerts:   18 DATA_QUALITY, 3 REVIEW_PRIORITY
--   1 duplicate submission refused (E24)
-- Run it ONCE. A second run is refused by the duplicate check.

declare
  v_today       timestamp := cast(trunc(localtimestamp) as timestamp);
  v_duplicates  pls_integer := 0;

  e_duplicate exception;
  pragma exception_init(e_duplicate, -20002);

  -- patient_id for a reference such as 'SYN-001'
  function pid(p_reference in varchar2) return number is
    v_id number;
  begin
    select patient_id into v_id from patients where patient_reference = p_reference;
    return v_id;
  end pid;

  -- a time N days ago at a given hour (negative days = in the future)
  function d(p_days_ago in number, p_hour in number) return timestamp is
  begin
    return v_today - numtodsinterval(p_days_ago, 'DAY') + numtodsinterval(p_hour, 'HOUR');
  end d;

begin
  -- ---------------------------------------------------------------------
  -- Baseline: SYN-001 to SYN-020, 2 normal readings each (40 readings).
  -- All pass quality checks; some reach the demo "Raised" priority.
  -- Measured 7 to 19 days ago.
  -- ---------------------------------------------------------------------
  for i in 1 .. 20 loop
    for j in 1 .. 2 loop
      submit_reading(
        p_patient_id        => pid('SYN-' || lpad(i, 3, '0')),
        p_measured_at       => d(j * 7 + mod(i, 5), 8 + mod(i, 3) * 4),
        p_systolic          => 115 + mod(i * 7, 35) + j * 3,
        p_diastolic         => 72 + mod(i * 3, 18) + j,
        p_pulse_rate        => 60 + mod(i * 5, 30),
        p_spo2              => 95 + mod(i, 4),
        p_body_weight_kg    => 60 + mod(i * 9, 40) + 0.5,
        p_medication_status => case mod(i + j, 4) when 0 then 'No' when 1 then 'Unknown' else 'Yes' end,
        p_symptom_report    => case when mod(i, 6) = 0 then 'Mild headache in the morning' end);
    end loop;
  end loop;

  -- ---------------------------------------------------------------------
  -- Named edge cases (24 readings + 1 refused duplicate).
  -- Each tests one rule. Expected result in the comment.
  -- ---------------------------------------------------------------------
  -- Demonstration priority
  submit_reading(pid('SYN-021'), d(1, 9),  186, 104, 78, 96, 80,  'Yes');  -- E01 Accepted, High (P_SYS_HIGH) + alert
  submit_reading(pid('SYN-021'), d(2, 9),  165, 124, 80, 97, 82,  'Yes');  -- E02 Accepted, High (P_DIA_HIGH) + alert
  submit_reading(pid('SYN-022'), d(1, 10), 132, 84,  88, 89, 70,  'Yes',
                 'Short of breath climbing stairs');                         -- E03 Accepted, High (P_SPO2_HIGH) + alert
  submit_reading(pid('SYN-022'), d(3, 10), 152, 84,  70, 97, 70,  'Yes');  -- E04 Accepted, Raised (P_SYS_RAISED)
  submit_reading(pid('SYN-022'), d(4, 10), 132, 94,  70, 97, 70,  'No');   -- E05 Accepted, Raised (P_DIA_RAISED)

  -- Rejected: blood pressure
  submit_reading(pid('SYN-023'), d(1, 11), 90,  120, 70, 97, 70,  'Yes');  -- E06 Rejected (H_BP_PAIR)
  submit_reading(pid('SYN-023'), d(2, 11), 45,  30,  70, 97, 70,  'Yes');  -- E07 Rejected (Q_SYS_REJECT_LOW)
  submit_reading(pid('SYN-023'), d(3, 11), 320, 100, 72, 97, 70,  'Yes');  -- E08 Rejected (Q_SYS_REJECT_HIGH)
  submit_reading(pid('SYN-024'), d(1, 12), 110, 15,  72, 97, 70,  'Yes');  -- E09 Rejected (Q_DIA_REJECT_LOW)
  submit_reading(pid('SYN-024'), d(2, 12), 260, 210, 72, 97, 70,  'Yes');  -- E10 Rejected wins over Review (Q_DIA_REJECT_HIGH + Q_SYS_REVIEW_HIGH), 2 alerts

  -- Review: unusual blood pressure
  submit_reading(pid('SYN-024'), d(3, 12), 240, 110, 72, 97, 70,  'Yes');  -- E11 Review (Q_SYS_REVIEW_HIGH), no priority
  submit_reading(pid('SYN-024'), d(4, 12), 195, 145, 72, 97, 70,  'Yes');  -- E12 Review (Q_DIA_REVIEW_HIGH), no priority

  -- Pulse rate
  submit_reading(pid('SYN-025'), d(1, 8),  128, 82,  20,  97, 70, 'Yes');  -- E13 Rejected (Q_PULSE_REJECT_LOW)
  submit_reading(pid('SYN-025'), d(2, 8),  128, 82,  160, 97, 70, 'Yes');  -- E14 Review (Q_PULSE_REVIEW_HIGH)
  submit_reading(pid('SYN-025'), d(3, 8),  128, 82,  35,  97, 70, 'Yes');  -- E15 Review (Q_PULSE_REVIEW_LOW)
  submit_reading(pid('SYN-025'), d(4, 8),  128, 82,  260, 97, 70, 'Yes');  -- E25 Rejected (Q_PULSE_REJECT_HIGH)

  -- SpO2
  submit_reading(pid('SYN-001'), d(1, 9),  126, 80,  70, 105, 70, 'Yes');  -- E16 Rejected (Q_SPO2_REJECT_HIGH)
  submit_reading(pid('SYN-002'), d(1, 9),  126, 80,  70, 40,  70, 'Yes');  -- E17 Rejected (Q_SPO2_REJECT_LOW)

  -- Body weight
  submit_reading(pid('SYN-003'), d(1, 9),  130, 84,  72, 97, 350, 'Yes');  -- E18 Rejected (Q_WEIGHT_REJECT_HIGH)
  submit_reading(pid('SYN-003'), d(2, 9),  130, 84,  72, 97, 12,  'Yes');  -- E19 Rejected (Q_WEIGHT_REJECT_LOW)

  -- Dates
  submit_reading(pid('SYN-004'), d(-2, 9), 130, 85,  70, 97, 70,  'Yes');  -- E20 Rejected (Q_FUTURE_MINUTES): 2 days ahead
  submit_reading(pid('SYN-005'), d(45, 10),138, 86,  74, 97, 70,  'Yes');  -- E21 Review (Q_BACKDATE_DAYS): 45 days ago

  -- Optional values empty, and special characters
  submit_reading(pid('SYN-006'), d(1, 8),  126, 78,  null, null, null, null);  -- E22 Accepted, Routine; medication becomes Unknown
  submit_reading(pid('SYN-007'), d(1, 9),  134, 82,  68, 97, 71,  'Yes',
                 'Felt dizzy <b>after</b> standing & "tired"');               -- E23 Accepted; text must display literally in the app

  -- Duplicate: exactly the same patient, time and BP as E04
  begin
    submit_reading(pid('SYN-022'), d(3, 10), 152, 84, 70, 97, 70, 'Yes');   -- E24 refused (-20002)
  exception
    when e_duplicate then
      v_duplicates := v_duplicates + 1;
  end;

  commit;
  dbms_output.put_line('Duplicates refused as expected: ' || v_duplicates);
end;
/

-- ---------------------------------------------------------------------
-- Results: compare with the expected values in the header
-- ---------------------------------------------------------------------
select quality_status, count(*) as readings
  from readings
 group by quality_status
 order by quality_status;

select alert_type, count(*) as alerts
  from alerts
 group by alert_type
 order by alert_type;

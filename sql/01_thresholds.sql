-- 01_thresholds.sql
-- Rule settings used by the SUBMIT_READING procedure.
-- Demonstration values only. They are NOT clinically validated.
-- Run once in SQL Workshop > SQL Scripts. Expected: 22 rows.

-- Fixed logic (no value needed)
insert into thresholds (rule_id, description, numeric_value) values ('H_BP_PAIR', 'Rejected if systolic is not higher than diastolic (likely data-entry error)', null);

-- Data quality: Rejected (impossible values)
insert into thresholds (rule_id, description, numeric_value) values ('Q_SYS_REJECT_LOW',     'Rejected if systolic is below this value (mmHg)', 50);
insert into thresholds (rule_id, description, numeric_value) values ('Q_SYS_REJECT_HIGH',    'Rejected if systolic is above this value (mmHg)', 300);
insert into thresholds (rule_id, description, numeric_value) values ('Q_DIA_REJECT_LOW',     'Rejected if diastolic is below this value (mmHg)', 20);
insert into thresholds (rule_id, description, numeric_value) values ('Q_DIA_REJECT_HIGH',    'Rejected if diastolic is above this value (mmHg)', 200);
insert into thresholds (rule_id, description, numeric_value) values ('Q_PULSE_REJECT_LOW',   'Rejected if pulse rate is below this value (bpm)', 25);
insert into thresholds (rule_id, description, numeric_value) values ('Q_PULSE_REJECT_HIGH',  'Rejected if pulse rate is above this value (bpm)', 250);
insert into thresholds (rule_id, description, numeric_value) values ('Q_SPO2_REJECT_LOW',    'Rejected if SpO2 is below this value (%)', 50);
insert into thresholds (rule_id, description, numeric_value) values ('Q_SPO2_REJECT_HIGH',   'Rejected if SpO2 is above this value (%)', 100);
insert into thresholds (rule_id, description, numeric_value) values ('Q_WEIGHT_REJECT_LOW',  'Rejected if body weight is below this value (kg)', 20);
insert into thresholds (rule_id, description, numeric_value) values ('Q_WEIGHT_REJECT_HIGH', 'Rejected if body weight is above this value (kg)', 300);
insert into thresholds (rule_id, description, numeric_value) values ('Q_FUTURE_MINUTES',     'Rejected if measured more than this many minutes after it was submitted', 5);

-- Data quality: Review (unusual values, confirm before use)
insert into thresholds (rule_id, description, numeric_value) values ('Q_SYS_REVIEW_HIGH',    'Review if systolic is above this value (mmHg)', 230);
insert into thresholds (rule_id, description, numeric_value) values ('Q_DIA_REVIEW_HIGH',    'Review if diastolic is above this value (mmHg)', 140);
insert into thresholds (rule_id, description, numeric_value) values ('Q_PULSE_REVIEW_LOW',   'Review if pulse rate is below this value (bpm)', 40);
insert into thresholds (rule_id, description, numeric_value) values ('Q_PULSE_REVIEW_HIGH',  'Review if pulse rate is above this value (bpm)', 150);
insert into thresholds (rule_id, description, numeric_value) values ('Q_BACKDATE_DAYS',      'Review if measured more than this many days before it was submitted', 30);

-- Demonstration review priority (Accepted readings only, not clinical advice)
insert into thresholds (rule_id, description, numeric_value) values ('P_SYS_HIGH',   'DEMO RULE: High priority if systolic is at or above this value (mmHg). Creates an alert', 180);
insert into thresholds (rule_id, description, numeric_value) values ('P_DIA_HIGH',   'DEMO RULE: High priority if diastolic is at or above this value (mmHg). Creates an alert', 120);
insert into thresholds (rule_id, description, numeric_value) values ('P_SPO2_HIGH',  'DEMO RULE: High priority if SpO2 is below this value (%). Creates an alert', 92);
insert into thresholds (rule_id, description, numeric_value) values ('P_SYS_RAISED', 'DEMO RULE: Raised priority if systolic is at or above this value (mmHg)', 140);
insert into thresholds (rule_id, description, numeric_value) values ('P_DIA_RAISED', 'DEMO RULE: Raised priority if diastolic is at or above this value (mmHg)', 90);

commit;

select count(*) as rules_loaded from thresholds;

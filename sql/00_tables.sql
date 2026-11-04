-- 00_tables.sql
-- Creates the four tables. Run first, in SQL Workshop > SQL Scripts.
-- Order matters: READINGS refers to PATIENTS, and ALERTS refers to
-- READINGS and THRESHOLDS.

create table patients (
  patient_id         number generated always as identity,
  patient_reference  varchar2(10)  not null,
  age_years          number(3)     not null,
  constraint patients_pk     primary key (patient_id),
  constraint patients_ref_uk unique (patient_reference),
  constraint patients_ref_ck check (regexp_like(patient_reference, '^SYN-[0-9]{3}$')),
  constraint patients_age_ck check (age_years between 18 and 110)
);

create table thresholds (
  rule_id        varchar2(30)   not null,
  description    varchar2(400)  not null,
  numeric_value  number,
  constraint thresholds_pk primary key (rule_id)
);

create table readings (
  reading_id            number generated always as identity,
  patient_id            number          not null,
  measured_at           timestamp(0)    not null,
  systolic              number(3)       not null,
  diastolic             number(3)       not null,
  pulse_rate            number(3),
  spo2                  number(3),
  body_weight_kg        number(5,1),
  medication_status     varchar2(7)     default 'Unknown' not null,
  symptom_report        varchar2(500),
  submitted_at          timestamp       default localtimestamp not null,
  quality_status        varchar2(8)     default 'Pending' not null,
  quality_explanation   varchar2(4000),
  priority_status       varchar2(12)    default 'Not assigned' not null,
  priority_explanation  varchar2(4000),
  processed_at          timestamp,
  constraint readings_pk           primary key (reading_id),
  constraint readings_patient_fk   foreign key (patient_id) references patients (patient_id),
  constraint readings_dup_uk       unique (patient_id, measured_at, systolic, diastolic),
  constraint readings_sys_ck       check (systolic >= 0),
  constraint readings_dia_ck       check (diastolic >= 0),
  constraint readings_pulse_ck     check (pulse_rate is null or pulse_rate >= 0),
  constraint readings_spo2_ck      check (spo2 is null or spo2 >= 0),
  constraint readings_weight_ck    check (body_weight_kg is null or body_weight_kg > 0),
  constraint readings_med_ck       check (medication_status in ('Yes', 'No', 'Unknown')),
  constraint readings_quality_ck   check (quality_status in ('Pending', 'Accepted', 'Review', 'Rejected')),
  constraint readings_priority_ck  check (priority_status in ('Not assigned', 'Routine', 'Raised', 'High')),
  constraint readings_prio_rule_ck check (priority_status = 'Not assigned' or quality_status = 'Accepted')
);

create table alerts (
  alert_id         number generated always as identity,
  reading_id       number          not null,
  rule_id          varchar2(30)    not null,
  alert_type       varchar2(15)    not null,
  explanation      varchar2(4000)  not null,
  status           varchar2(12)    default 'Open' not null,
  created_at       timestamp       default localtimestamp not null,
  acknowledged_at  timestamp,
  constraint alerts_pk          primary key (alert_id),
  constraint alerts_reading_fk  foreign key (reading_id) references readings (reading_id),
  constraint alerts_rule_fk     foreign key (rule_id) references thresholds (rule_id),
  constraint alerts_dup_uk      unique (reading_id, rule_id),
  constraint alerts_type_ck     check (alert_type in ('DATA_QUALITY', 'REVIEW_PRIORITY')),
  constraint alerts_status_ck   check (status in ('Open', 'Acknowledged')),
  constraint alerts_ack_ck      check (
       (status = 'Open'         and acknowledged_at is null)
    or (status = 'Acknowledged' and acknowledged_at is not null))
);

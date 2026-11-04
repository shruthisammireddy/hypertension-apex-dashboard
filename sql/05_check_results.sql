-- 05_check_results.sql
-- Test queries. Run in SQL Workshop > SQL Scripts (or one at a time in SQL Commands).
-- Each query states the expected result after 04_sample_readings.sql.

-- 1. Row counts. Expected: PATIENTS 25, THRESHOLDS 22, READINGS 64, ALERTS 21
select 'PATIENTS' as table_name, count(*) as row_count from patients
union all select 'THRESHOLDS', count(*) from thresholds
union all select 'READINGS',   count(*) from readings
union all select 'ALERTS',     count(*) from alerts;

-- 2. Quality status. Expected: Accepted 47, Rejected 12, Review 5 (and no Pending)
select quality_status, count(*) as readings
  from readings
 group by quality_status
 order by quality_status;

-- 3. Priority status. Expected: High 3; Raised and Routine for the rest of the Accepted; Not assigned 17
select priority_status, count(*) as readings
  from readings
 group by priority_status
 order by priority_status;

-- 4. Bad data never gets a priority. Expected: 0
select count(*) as broken_rows
  from readings
 where quality_status <> 'Accepted'
   and priority_status <> 'Not assigned';

-- 5. Every alerting rule fired at least once. Expected: 20 rows, each with alerts >= 1
--    (P_SYS_RAISED and P_DIA_RAISED never create alerts by design)
select t.rule_id, count(a.alert_id) as alerts
  from thresholds t
  left join alerts a on a.rule_id = t.rule_id
 where t.rule_id not in ('P_SYS_RAISED', 'P_DIA_RAISED')
 group by t.rule_id
 order by t.rule_id;

-- 6. No duplicate alerts. Expected: no rows
select reading_id, rule_id, count(*)
  from alerts
 group by reading_id, rule_id
having count(*) > 1;

-- 7. Alerts with the patient (the join the Alerts page will use)
select a.alert_id, p.patient_reference, r.systolic || '/' || r.diastolic as bp,
       a.rule_id, a.alert_type, a.status, a.explanation
  from alerts a
  join readings r on r.reading_id = a.reading_id
  join patients p on p.patient_id = r.patient_id
 order by a.alert_id;

-- 8. Accepted-only average for one patient (the GP summary logic).
--    SYN-023 has only Rejected readings, so its accepted average is empty.
select p.patient_reference,
       count(*)                                                   as submitted,
       sum(case when r.quality_status = 'Accepted' then 1 else 0 end) as accepted,
       round(avg(case when r.quality_status = 'Accepted' then r.systolic end), 1)  as avg_systolic,
       round(avg(case when r.quality_status = 'Accepted' then r.diastolic end), 1) as avg_diastolic
  from readings r
  join patients p on p.patient_id = r.patient_id
 group by p.patient_reference
 order by p.patient_reference;

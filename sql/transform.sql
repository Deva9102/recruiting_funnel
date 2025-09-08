SELECT COUNT(*) AS raw_rows FROM raw_candidates;

INSERT INTO candidates (candidate_id, gender, education_level, years_experience,
                        python_exp, internship, score, location, salary_band)
SELECT
  Serial_no,
  Gender,
  Education,
  Experience_Years,
  CASE WHEN Python_exp='Yes' THEN 1 ELSE 0 END,
  CASE WHEN Internship='Yes' THEN 1 ELSE 0 END,
  Score,
  Location,
  "Salary * 10E4"
FROM raw_candidates;

INSERT INTO applications (candidate_id, applied_at, hired)
SELECT
  Serial_no,
  date('2024-01-01', '+' || Serial_no || ' days'),
  CASE WHEN Recruitment_Status='Y' THEN 1 ELSE 0 END
FROM raw_candidates;

INSERT INTO stage_events (application_id, stage_name, stage_entered_at)
SELECT application_id, 'Applied', applied_at
FROM applications;

INSERT INTO stage_events (application_id, stage_name, stage_entered_at)
SELECT a.application_id, 'Screened', date(a.applied_at,'+1 day')
FROM applications a
JOIN candidates c ON c.candidate_id=a.candidate_id
WHERE c.score >= 4000 OR c.education_level='Graduate';

INSERT INTO stage_events (application_id, stage_name, stage_entered_at)
SELECT a.application_id, 'Interviewed', date(a.applied_at,'+7 day')
FROM applications a
JOIN candidates c ON c.candidate_id=a.candidate_id
WHERE c.python_exp=1 OR c.years_experience>=1;

INSERT INTO stage_events (application_id, stage_name, stage_entered_at)
SELECT a.application_id, 'Offered', date(a.applied_at,'+14 day')
FROM applications a
JOIN raw_candidates r ON r.Serial_no=a.candidate_id
WHERE r.Offer_History > 0;

INSERT INTO stage_events (application_id, stage_name, stage_entered_at)
SELECT a.application_id, 'Hired', date(a.applied_at,'+21 day')
FROM applications a
JOIN raw_candidates r ON r.Serial_no=a.candidate_id
WHERE r.Recruitment_Status='Y';

WITH ordered AS (
  SELECT
    stage_event_id,
    application_id,
    stage_entered_at,
    LEAD(stage_entered_at) OVER (PARTITION BY application_id ORDER BY stage_entered_at) AS next_entered
  FROM stage_events
)
UPDATE stage_events
SET stage_exited_at = (SELECT next_entered
                       FROM ordered o
                       WHERE o.stage_event_id = stage_events.stage_event_id)
WHERE stage_event_id IN (SELECT stage_event_id FROM ordered);
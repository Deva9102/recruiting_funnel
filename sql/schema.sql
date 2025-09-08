PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS stage_events;
DROP TABLE IF EXISTS applications;
DROP TABLE IF EXISTS candidates;

CREATE TABLE candidates (
  candidate_id       INTEGER PRIMARY KEY,
  gender             TEXT,
  education_level    TEXT,                         -- Graduate / Not Graduate
  years_experience   INTEGER,
  python_exp         INTEGER,                      -- 1/0 from Yes/No
  internship         INTEGER,                      -- 1/0 from Yes/No
  score              INTEGER,
  location           TEXT,                         -- Urban/Rural
  salary_band        REAL                          -- from "Salary * 10E4"
);

CREATE TABLE applications (
  application_id     INTEGER PRIMARY KEY,
  candidate_id       INTEGER NOT NULL REFERENCES candidates(candidate_id),
  applied_at         TEXT NOT NULL,                -- ISO date
  hired              INTEGER NOT NULL              -- 1/0 from Recruitment_Status
);

CREATE TABLE stage_events (
  stage_event_id     INTEGER PRIMARY KEY,
  application_id     INTEGER NOT NULL REFERENCES applications(application_id),
  stage_name         TEXT NOT NULL,                -- Applied/Screened/Interviewed/Offered/Hired
  stage_entered_at   TEXT NOT NULL,                -- ISO date
  stage_exited_at    TEXT                          -- filled from next stage
);

CREATE INDEX IF NOT EXISTS idx_app_candidate   ON applications(candidate_id);
CREATE INDEX IF NOT EXISTS idx_stage_app       ON stage_events(application_id);
CREATE INDEX IF NOT EXISTS idx_stage_entered   ON stage_events(stage_entered_at);

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

SELECT COUNT(*) FROM candidates;
SELECT COUNT(*) FROM applications;
SELECT stage_name, COUNT(DISTINCT application_id) AS apps
FROM stage_events
GROUP BY stage_name
ORDER BY CASE stage_name
  WHEN 'Applied' THEN 1 WHEN 'Screened' THEN 2
  WHEN 'Interviewed' THEN 3 WHEN 'Offered' THEN 4
  WHEN 'Hired' THEN 5 END;

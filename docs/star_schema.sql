PRAGMA foreign_keys = ON;

-- --- tiny dimensions from candidate attributes ---
DROP TABLE IF EXISTS dim_education;
CREATE TABLE dim_education(
  education_key INTEGER PRIMARY KEY,
  education_level TEXT UNIQUE NOT NULL
);
INSERT OR IGNORE INTO dim_education(education_level)
SELECT DISTINCT education_level FROM candidates WHERE education_level IS NOT NULL;

DROP TABLE IF EXISTS dim_location;
CREATE TABLE dim_location(
  location_key INTEGER PRIMARY KEY,
  location TEXT UNIQUE NOT NULL
);
INSERT OR IGNORE INTO dim_location(location)
SELECT DISTINCT location FROM candidates WHERE location IS NOT NULL;

DROP TABLE IF EXISTS dim_python;
CREATE TABLE dim_python(
  python_key INTEGER PRIMARY KEY,
  has_python INTEGER UNIQUE NOT NULL CHECK(has_python IN (0,1))
);
INSERT OR IGNORE INTO dim_python(has_python) VALUES (0),(1);

DROP TABLE IF EXISTS dim_internship;
CREATE TABLE dim_internship(
  internship_key INTEGER PRIMARY KEY,
  has_internship INTEGER UNIQUE NOT NULL CHECK(has_internship IN (0,1))
);
INSERT OR IGNORE INTO dim_internship(has_internship) VALUES (0),(1);

-- --- synth business dims you can analyze by (recruiter/source/role) ---
DROP TABLE IF EXISTS dim_recruiter;
CREATE TABLE dim_recruiter(
  recruiter_key INTEGER PRIMARY KEY,
  recruiter_name TEXT UNIQUE NOT NULL
);
INSERT INTO dim_recruiter(recruiter_name) VALUES
 ('Rita'),('Sam'),('Ava'),('Leo');

DROP TABLE IF EXISTS dim_source;
CREATE TABLE dim_source(
  source_key INTEGER PRIMARY KEY,
  source_name TEXT UNIQUE NOT NULL
);
INSERT INTO dim_source(source_name) VALUES
 ('Referral'),('LinkedIn'),('Job Board'),('Career Site');

DROP TABLE IF EXISTS dim_role;
CREATE TABLE dim_role(
  role_key INTEGER PRIMARY KEY,
  role_name TEXT UNIQUE NOT NULL
);
INSERT INTO dim_role(role_name) VALUES
 ('Data Analyst'),('Data Engineer'),('ML Engineer'),('BI Analyst');

-- --- time dimension from min..max applied_at ---
DROP TABLE IF EXISTS dim_time;
CREATE TABLE dim_time(
  date_key TEXT PRIMARY KEY,         -- 'YYYY-MM-DD'
  year INTEGER, quarter INTEGER, month INTEGER, week INTEGER
);

WITH bounds AS (
  SELECT date(min(applied_at)) AS d0, date(max(applied_at)) AS d1 FROM applications
),
seq(n) AS (
  SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
),
days AS (
  SELECT d0, d1, (a.n+b.n*5+c.n*25+d.n*125) AS k
  FROM bounds
  JOIN seq a JOIN seq b JOIN seq c JOIN seq d
)
INSERT INTO dim_time
SELECT date(d0, '+'||k||' day') AS d,
       CAST(strftime('%Y', d) AS INT),
       ((CAST(strftime('%m', d) AS INT)-1)/3)+1,
       CAST(strftime('%m', d) AS INT),
       CAST(strftime('%W', d) AS INT)
FROM days, bounds
WHERE date(d0, '+'||k||' day') BETWEEN d0 AND d1;

-- --- FACT: application (add recruiter/source/role deterministically) ---
DROP TABLE IF EXISTS fact_application;
CREATE TABLE fact_application(
  application_id   INTEGER PRIMARY KEY,
  candidate_id     INTEGER NOT NULL,
  applied_date_key TEXT NOT NULL REFERENCES dim_time(date_key),
  education_key    INTEGER REFERENCES dim_education(education_key),
  location_key     INTEGER REFERENCES dim_location(location_key),
  python_key       INTEGER REFERENCES dim_python(python_key),
  internship_key   INTEGER REFERENCES dim_internship(internship_key),
  recruiter_key    INTEGER REFERENCES dim_recruiter(recruiter_key),
  source_key       INTEGER REFERENCES dim_source(source_key),
  role_key         INTEGER REFERENCES dim_role(role_key),
  years_experience INTEGER,
  score            INTEGER,
  salary_band      REAL,
  hired            INTEGER NOT NULL CHECK(hired IN (0,1))
);

-- map categorical keys
INSERT INTO fact_application
SELECT
  a.application_id,
  a.candidate_id,
  date(a.applied_at) AS applied_date_key,
  (SELECT education_key  FROM dim_education  d WHERE d.education_level=c.education_level),
  (SELECT location_key   FROM dim_location   d WHERE d.location       =c.location),
  (SELECT python_key     FROM dim_python     d WHERE d.has_python     =c.python_exp),
  (SELECT internship_key FROM dim_internship d WHERE d.has_internship =c.internship),
  -- deterministic synth using modulo on candidate_id
  ((c.candidate_id % 4)+1) AS recruiter_key,
  ((c.candidate_id % 4)+1) AS source_key,
  ((c.candidate_id % 4)+1) AS role_key,
  c.years_experience,
  c.score,
  c.salary_band,
  a.hired
FROM applications a
JOIN candidates  c ON c.candidate_id=a.candidate_id;

-- --- FACT: stage events (rename for star)
DROP TABLE IF EXISTS fact_stage_event;
CREATE TABLE fact_stage_event AS
SELECT
  stage_event_id,
  application_id,
  stage_name,
  stage_entered_at,
  stage_exited_at
FROM stage_events;

CREATE INDEX IF NOT EXISTS idx_fact_stage_app ON fact_stage_event(application_id);

------------------------------------------------------------
-- 1) Funnel counts
------------------------------------------------------------
SELECT stage_name,
       COUNT(DISTINCT application_id) AS apps
FROM stage_events
WHERE stage_name IN ('Applied','Screened','Interviewed','Offered','Hired')
GROUP BY stage_name
ORDER BY CASE stage_name
  WHEN 'Applied' THEN 1
  WHEN 'Screened' THEN 2
  WHEN 'Interviewed' THEN 3
  WHEN 'Offered' THEN 4
  WHEN 'Hired' THEN 5 END;

------------------------------------------------------------
-- 2) Conversion rates (stage to stage + overall)
------------------------------------------------------------
WITH by_stage AS (
  SELECT stage_name, COUNT(DISTINCT application_id) AS n
  FROM stage_events
  WHERE stage_name IN ('Applied','Screened','Interviewed','Offered','Hired')
  GROUP BY stage_name
),
pivot AS (
  SELECT
    SUM(CASE WHEN stage_name='Applied' THEN n END) AS applied,
    SUM(CASE WHEN stage_name='Screened' THEN n END) AS screened,
    SUM(CASE WHEN stage_name='Interviewed' THEN n END) AS interviewed,
    SUM(CASE WHEN stage_name='Offered' THEN n END) AS offered,
    SUM(CASE WHEN stage_name='Hired' THEN n END) AS hired
  FROM by_stage
)
SELECT applied, screened, interviewed, offered, hired,
       ROUND(1.0*screened/applied,3)     AS conv_applied_to_screened,
       ROUND(1.0*interviewed/screened,3) AS conv_screened_to_interviewed,
       ROUND(1.0*offered/interviewed,3)  AS conv_interviewed_to_offered,
       ROUND(1.0*hired/offered,3)        AS conv_offered_to_hired,
       ROUND(1.0*hired/applied,3)        AS conv_overall
FROM pivot;

------------------------------------------------------------
-- 3) Average time in each stage (days)
------------------------------------------------------------
SELECT stage_name,
       ROUND(AVG(julianday(stage_exited_at) - julianday(stage_entered_at)),2) AS avg_days_in_stage
FROM stage_events
WHERE stage_exited_at IS NOT NULL
GROUP BY stage_name
ORDER BY avg_days_in_stage DESC;

------------------------------------------------------------
-- 4) Education impact (Graduate vs Not Graduate)
------------------------------------------------------------
SELECT c.education_level,
       COUNT(*) AS apps,
       SUM(a.hired) AS hires,
       ROUND(1.0*SUM(a.hired)/COUNT(*),3) AS conversion_rate
FROM applications a
JOIN candidates c ON c.candidate_id=a.candidate_id
GROUP BY c.education_level;

------------------------------------------------------------
-- 5) Location impact (Urban vs Rural)
------------------------------------------------------------
SELECT c.location,
       COUNT(*) AS apps,
       SUM(a.hired) AS hires,
       ROUND(1.0*SUM(a.hired)/COUNT(*),3) AS conversion_rate
FROM applications a
JOIN candidates c ON c.candidate_id=a.candidate_id
GROUP BY c.location;

-- 1) Record-level flat view (great for Tableau)
CREATE VIEW IF NOT EXISTS v_applications_flat AS
SELECT
  a.application_id,
  a.candidate_id,
  a.applied_at,
  a.hired,
  c.gender,
  c.education_level,
  c.years_experience,
  c.python_exp,
  c.internship,
  c.score,
  c.location,
  c.salary_band
FROM applications a
JOIN candidates c ON c.candidate_id = a.candidate_id;

-- 2) Funnel counts
CREATE VIEW IF NOT EXISTS v_funnel_counts AS
SELECT stage_name,
       COUNT(DISTINCT application_id) AS apps
FROM stage_events
WHERE stage_name IN ('Applied','Screened','Interviewed','Offered','Hired')
GROUP BY stage_name
ORDER BY CASE stage_name
  WHEN 'Applied' THEN 1 WHEN 'Screened' THEN 2
  WHEN 'Interviewed' THEN 3 WHEN 'Offered' THEN 4
  WHEN 'Hired' THEN 5 END;

-- 3) Conversion rates (overall)
CREATE VIEW IF NOT EXISTS v_conversion_overall AS
WITH by_stage AS (
  SELECT stage_name, COUNT(DISTINCT application_id) AS n
  FROM stage_events
  WHERE stage_name IN ('Applied','Screened','Interviewed','Offered','Hired')
  GROUP BY stage_name
)
SELECT
  MAX(CASE WHEN stage_name='Applied' THEN n END)       AS applied,
  MAX(CASE WHEN stage_name='Screened' THEN n END)      AS screened,
  MAX(CASE WHEN stage_name='Interviewed' THEN n END)   AS interviewed,
  MAX(CASE WHEN stage_name='Offered' THEN n END)       AS offered,
  MAX(CASE WHEN stage_name='Hired' THEN n END)         AS hired,
  ROUND(1.0*MAX(CASE WHEN stage_name='Screened' THEN n END)/
             MAX(CASE WHEN stage_name='Applied'  THEN n END),3) AS conv_applied_to_screened,
  ROUND(1.0*MAX(CASE WHEN stage_name='Interviewed' THEN n END)/
             MAX(CASE WHEN stage_name='Screened'   THEN n END),3) AS conv_screened_to_interviewed,
  ROUND(1.0*MAX(CASE WHEN stage_name='Offered' THEN n END)/
             MAX(CASE WHEN stage_name='Interviewed' THEN n END),3) AS conv_interviewed_to_offered,
  ROUND(1.0*MAX(CASE WHEN stage_name='Hired' THEN n END)/
             MAX(CASE WHEN stage_name='Offered' THEN n END),3) AS conv_offered_to_hired,
  ROUND(1.0*MAX(CASE WHEN stage_name='Hired' THEN n END)/
             MAX(CASE WHEN stage_name='Applied' THEN n END),3) AS conv_overall;

-- 4) Average days spent in each stage
CREATE VIEW IF NOT EXISTS v_stage_durations AS
SELECT stage_name,
       ROUND(AVG(julianday(stage_exited_at) - julianday(stage_entered_at)),2) AS avg_days_in_stage
FROM stage_events
WHERE stage_exited_at IS NOT NULL
GROUP BY stage_name
ORDER BY avg_days_in_stage DESC;

-- 5) Slice by education and location
CREATE VIEW IF NOT EXISTS v_conversion_by_edu AS
SELECT c.education_level,
       COUNT(*) AS apps,
       SUM(a.hired) AS hires,
       ROUND(1.0*SUM(a.hired)/COUNT(*),3) AS conversion_rate
FROM applications a
JOIN candidates c ON c.candidate_id=a.candidate_id
GROUP BY c.education_level;

CREATE VIEW IF NOT EXISTS v_conversion_by_location AS
SELECT c.location,
       COUNT(*) AS apps,
       SUM(a.hired) AS hires,
       ROUND(1.0*SUM(a.hired)/COUNT(*),3) AS conversion_rate
FROM applications a
JOIN candidates c ON c.candidate_id=a.candidate_id
GROUP BY c.location;

-- Flat record-level view (base table for most charts)
CREATE VIEW IF NOT EXISTS v_applications_flat AS
SELECT
  f.application_id, f.candidate_id, f.applied_date_key,
  f.hired, f.years_experience, f.score, f.salary_band,
  de.education_level, dl.location,
  dp.has_python AS python_exp, di.has_internship AS internship,
  dr.recruiter_name, ds.source_name, rr.role_name
FROM fact_application f
LEFT JOIN dim_education  de ON de.education_key  = f.education_key
LEFT JOIN dim_location   dl ON dl.location_key   = f.location_key
LEFT JOIN dim_python     dp ON dp.python_key     = f.python_key
LEFT JOIN dim_internship di ON di.internship_key = f.internship_key
LEFT JOIN dim_recruiter  dr ON dr.recruiter_key  = f.recruiter_key
LEFT JOIN dim_source     ds ON ds.source_key     = f.source_key
LEFT JOIN dim_role       rr ON rr.role_key       = f.role_key;

-- Funnel counts by slice (Role/Source/Recruiter filters)
CREATE VIEW IF NOT EXISTS v_funnel_by_slice AS
WITH s AS (
  SELECT f.role_key, f.source_key, f.recruiter_key, e.stage_name,
         COUNT(DISTINCT e.application_id) AS apps
  FROM fact_stage_event e
  JOIN fact_application  f ON f.application_id=e.application_id
  WHERE e.stage_name IN ('Applied','Screened','Interviewed','Offered','Hired')
  GROUP BY 1,2,3,4
)
SELECT r.role_name, s2.source_name, rc.recruiter_name, stage_name, apps
FROM s
JOIN dim_role r       ON r.role_key=s.role_key
JOIN dim_source s2    ON s2.source_key=s.source_key
JOIN dim_recruiter rc ON rc.recruiter_key=s.recruiter_key;

-- Cohort conversion (by application month)
CREATE VIEW IF NOT EXISTS v_cohort_conversion AS
WITH cohort AS (
  SELECT substr(applied_date_key,1,7) AS cohort_month, application_id
  FROM fact_application
),
stage_cte AS (
  SELECT c.cohort_month, e.stage_name, COUNT(DISTINCT e.application_id) AS n
  FROM cohort c
  JOIN fact_stage_event e ON e.application_id=c.application_id
  GROUP BY 1,2
)
SELECT cohort_month,
       MAX(CASE WHEN stage_name='Applied'     THEN n END) AS applied,
       MAX(CASE WHEN stage_name='Screened'    THEN n END) AS screened,
       MAX(CASE WHEN stage_name='Interviewed' THEN n END) AS interviewed,
       MAX(CASE WHEN stage_name='Offered'     THEN n END) AS offered,
       MAX(CASE WHEN stage_name='Hired'       THEN n END) AS hired
FROM stage_cte
GROUP BY cohort_month
ORDER BY cohort_month;

-- Avg time-in-stage (days)
CREATE VIEW IF NOT EXISTS v_stage_durations AS
SELECT stage_name,
       ROUND(AVG(julianday(stage_exited_at) - julianday(stage_entered_at)),2) AS avg_days_in_stage
FROM fact_stage_event
WHERE stage_exited_at IS NOT NULL
GROUP BY stage_name
ORDER BY avg_days_in_stage DESC;

-- Score bands vs hire rate
CREATE VIEW IF NOT EXISTS v_score_band AS
WITH bands AS (
  SELECT application_id,
         CASE
           WHEN score < 2500 THEN 'Very Low'
           WHEN score < 4000 THEN 'Low'
           WHEN score < 6000 THEN 'Medium'
           WHEN score < 9000 THEN 'High'
           ELSE 'Very High'
         END AS score_band
  FROM fact_application
)
SELECT b.score_band, COUNT(*) AS apps,
       SUM(f.hired) AS hires,
       ROUND(1.0*SUM(f.hired)/COUNT(*),3) AS hire_rate
FROM fact_application f
JOIN bands b ON b.application_id=f.application_id
GROUP BY b.score_band
ORDER BY CASE b.score_band
  WHEN 'Very Low' THEN 1 WHEN 'Low' THEN 2
  WHEN 'Medium' THEN 3 WHEN 'High' THEN 4 ELSE 5 END;

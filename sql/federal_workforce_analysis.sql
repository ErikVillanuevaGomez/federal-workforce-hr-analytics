-- ============================================================
-- Federal Workforce HR Analytics
-- U.S. Office of Personnel Management (OPM)
-- Analysis Period: August 2025 - July 2026
--
-- Purpose:
-- Prepare cleaned analytical views for workforce trends,
-- salaries, separations, departments, occupations, and age groups.
-- ============================================================

USE federal_hr_analytics;


-- ============================================================
-- 1. DEPARTMENT SEPARATION RATIOS
-- ============================================================

CREATE OR REPLACE VIEW vw_department_separation_rates AS
SELECT
    e.department,
    SUM(s.separations) AS total_separations,
    ROUND(AVG(e.employee_count), 2) AS avg_employee_count,
    ROUND(
        SUM(s.separations)
        / NULLIF(AVG(e.employee_count), 0) * 100,
        2
    ) AS separation_rate
FROM employment_department_monthly AS e
INNER JOIN separations_department_monthly AS s
    ON e.snapshot_date = s.separation_date
    AND e.department = s.department
GROUP BY e.department;


-- ============================================================
-- 2. MONTHLY WORKFORCE TREND
-- ============================================================

CREATE OR REPLACE VIEW vw_monthly_workforce_trend AS
SELECT
    snapshot_date,
    SUM(employee_count) AS total_employees,

    ROUND(
        SUM(average_salary * employee_count)
        /
        NULLIF(
            SUM(
                CASE
                    WHEN average_salary IS NOT NULL
                    THEN employee_count
                END
            ),
            0
        ),
        2
    ) AS weighted_avg_salary

FROM employment_department_monthly
GROUP BY snapshot_date;


-- ============================================================
-- 3. LATEST DEPARTMENT SNAPSHOT
-- ============================================================

CREATE OR REPLACE VIEW vw_department_latest_snapshot AS
SELECT
    snapshot_date,
    department,
    average_salary,
    employee_count
FROM employment_department_monthly
WHERE snapshot_date = (
    SELECT MAX(snapshot_date)
    FROM employment_department_monthly
);


-- ============================================================
-- 4. SEPARATION TYPE DISTRIBUTION
-- ============================================================

CREATE OR REPLACE VIEW vw_separation_type_distribution AS
SELECT
    separation_type,
    SUM(separations) AS total_separations,

    ROUND(
        SUM(separations)
        /
        NULLIF(
            (
                SELECT SUM(separations)
                FROM separations_type_department
            ),
            0
        ) * 100,
        2
    ) AS percent_of_separations

FROM separations_type_department
GROUP BY separation_type;


-- ============================================================
-- 5. OCCUPATIONAL GROUP ANALYTICS
-- ============================================================

CREATE OR REPLACE VIEW vw_occupation_analytics AS
SELECT
    e.occupational_group,

    ROUND(
        AVG(e.average_salary),
        2
    ) AS avg_salary,

    ROUND(
        AVG(e.employee_count),
        2
    ) AS avg_employee_count,

    SUM(s.separations) AS total_separations,

    ROUND(
        SUM(s.separations)
        / NULLIF(AVG(e.employee_count), 0) * 100,
        2
    ) AS separation_rate,

    CASE
        WHEN AVG(e.employee_count) >= 1000 THEN 'Yes'
        ELSE 'No'
    END AS meets_1000_employee_threshold

FROM employment_occupation_monthly AS e
INNER JOIN separations_occupation_monthly AS s
    ON e.snapshot_date = s.separation_date
    AND e.occupational_group = s.occupational_group

GROUP BY e.occupational_group;


-- ============================================================
-- 6. AGE BRACKET SEPARATION RATIOS
-- ============================================================

CREATE OR REPLACE VIEW vw_age_separation_rates AS
SELECT
    e.age_bracket,

    CASE
        WHEN e.age_bracket = 'LESS THAN 20' THEN 1
        WHEN e.age_bracket = '20-24' THEN 2
        WHEN e.age_bracket = '25-29' THEN 3
        WHEN e.age_bracket = '30-34' THEN 4
        WHEN e.age_bracket = '35-39' THEN 5
        WHEN e.age_bracket = '40-44' THEN 6
        WHEN e.age_bracket = '45-49' THEN 7
        WHEN e.age_bracket = '50-54' THEN 8
        WHEN e.age_bracket = '55-59' THEN 9
        WHEN e.age_bracket = '60-64' THEN 10
        WHEN e.age_bracket = '65 OR MORE' THEN 11
    END AS age_order,

    SUM(s.separations) AS total_separations,

    ROUND(
        AVG(e.employee_count),
        2
    ) AS avg_employee_count,

    ROUND(
        SUM(s.separations)
        / NULLIF(AVG(e.employee_count), 0) * 100,
        2
    ) AS separation_rate

FROM employment_age_monthly AS e
INNER JOIN separations_age_monthly AS s
    ON e.snapshot_date = s.separation_date
    AND e.age_bracket = s.age_bracket

WHERE e.age_bracket <> 'UNSPECIFIED'

GROUP BY e.age_bracket;


-- ============================================================
-- 7. DASHBOARD KPI VIEW
-- ============================================================

CREATE OR REPLACE VIEW vw_dashboard_kpis AS
SELECT
    latest_row.snapshot_date AS latest_snapshot_date,

    latest_row.total_employees AS latest_employee_count,

    latest_row.weighted_avg_salary
        AS latest_weighted_avg_salary,

    (
        SELECT SUM(separations)
        FROM separations_department_monthly
    ) AS total_separations_12mo,

    start_row.total_employees
        AS starting_employee_count,

    latest_row.total_employees
        - start_row.total_employees
        AS workforce_change,

    ROUND(
        (
            latest_row.total_employees
            - start_row.total_employees
        )
        / NULLIF(start_row.total_employees, 0) * 100,
        2
    ) AS workforce_change_pct

FROM vw_monthly_workforce_trend AS latest_row

CROSS JOIN vw_monthly_workforce_trend AS start_row

WHERE latest_row.snapshot_date = (
    SELECT MAX(snapshot_date)
    FROM vw_monthly_workforce_trend
)

AND start_row.snapshot_date = (
    SELECT MIN(snapshot_date)
    FROM vw_monthly_workforce_trend
);


-- ============================================================
-- VALIDATION / EXPLORATORY QUERIES
-- ============================================================

-- Monthly workforce trend
SELECT *
FROM vw_monthly_workforce_trend
ORDER BY snapshot_date;


-- Highest department separation ratios
SELECT *
FROM vw_department_separation_rates
ORDER BY separation_rate DESC;


-- Separation categories
SELECT *
FROM vw_separation_type_distribution
ORDER BY total_separations DESC;


-- Occupations with at least 1,000 average employees
SELECT *
FROM vw_occupation_analytics
WHERE meets_1000_employee_threshold = 'Yes'
ORDER BY separation_rate DESC;


-- Age bracket separation ratios
SELECT *
FROM vw_age_separation_rates
ORDER BY age_order;


-- Dashboard KPIs
SELECT *
FROM vw_dashboard_kpis;

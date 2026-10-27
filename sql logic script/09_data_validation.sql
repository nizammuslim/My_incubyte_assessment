-- five important data-quality checks check whether data is complete, unique, correctly routed, valid, and consistent

-- DATA QUALITY RESULTS

USE ROLE ACCOUNTADMIN;

USE WAREHOUSE incubyte_wh;

USE DATABASE INCUBYTE_ASSESSMENT;

USE SCHEMA INCUBYTE_ASSESSMENT.GOLD;

CREATE TABLE IF NOT EXISTS INCUBYTE_ASSESSMENT.GOLD.DQ_RESULTS (
    RUN_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CHECK_NAME      VARCHAR,
    SEVERITY        VARCHAR,
    FAILED_ROWS     NUMBER,
    STATUS          VARCHAR
);

INSERT INTO INCUBYTE_ASSESSMENT.GOLD.DQ_RESULTS
(CHECK_NAME, SEVERITY, FAILED_ROWS, STATUS)
WITH CHECKS AS (
 -- 1. Every raw row should be staged or rejected
SELECT 'ROW_RECONCILIATION' AS CHECK_NAME,
        'ERROR' AS SEVERITY,
        ABS(
            (SELECT COUNT(*) FROM RAW_MEMBERS)
          - (SELECT COUNT(*) FROM STG_MEMBERS)
          - (SELECT COUNT(*) FROM REJECTED_MEMBERS)
        ) AS FAILED_ROWS
    UNION ALL

    -- 2. Required member fields must not be NULL
    SELECT 
    'REQUIRED_FIELDS',
    'ERROR',
    COALESCE(COUNT_IF(MEMBER_ID IS NULL
            OR MEMBER_NAME IS NULL
            OR DOB IS NULL
            OR COUNTRY IS NULL
        ), 0)
    FROM INCUBYTE_ASSESSMENT.BRONZE.STG_MEMBERS
    UNION ALL

    -- 3. A member ID should appear only once in the final member view
    SELECT
        'DUPLICATE_MEMBER_IDS',
        'ERROR',
        COUNT(*)
    FROM (
        SELECT MEMBER_ID
        FROM V_MEMBERS_ALL
        WHERE MEMBER_ID IS NOT NULL
        GROUP BY MEMBER_ID
        HAVING COUNT(*) > 1
    )
    UNION ALL

    -- 4. Members must be stored in the correct country table
    SELECT
        'COUNTRY_ROUTING',
        'ERROR',
        (SELECT COALESCE(COUNT_IF(
            COUNTRY IS NULL OR COUNTRY <> 'AUS'
        ), 0) FROM MEMBERS_AUS)
        +
        (SELECT COALESCE(COUNT_IF(
            COUNTRY IS NULL OR COUNTRY <> 'USA'
        ), 0) FROM MEMBERS_USA)
        +
        (SELECT COALESCE(COUNT_IF(
            COUNTRY IS NULL OR COUNTRY <> 'IND'
        ), 0) FROM MEMBERS_IND)

    UNION ALL

    -- 5. Flight dates should not be in the future
    SELECT
        'FUTURE_FLIGHT_DATE',
        'WARN',
        COALESCE(COUNT_IF(
            FLIGHT_DATE > AS_OF_DATE
        ), 0)
    FROM INCUBYTE_ASSESSMENT.BRONZE.STG_MEMBERS

    UNION ALL

    -- 6. Every redemption should have an ID and member ID
    SELECT
        'REDEMPTION_REQUIRED_FIELDS',
        'ERROR',
        COALESCE(COUNT_IF(
            REDEMPTION_ID IS NULL
            OR MEMBER_ID IS NULL
        ), 0)
    FROM INCUBYTE_ASSESSMENT.SILVAR.REDEMPTIONS_FLAT

    UNION ALL

    -- 7. Redemption member IDs should exist in the member view
    SELECT
        'REDEMPTION_MEMBER_EXISTS',
        'WARN',
        COALESCE(COUNT_IF(
            r.MEMBER_ID IS NOT NULL
            AND m.MEMBER_ID IS NULL
        ), 0)
    FROM REDEMPTIONS_FLAT r
    LEFT JOIN V_MEMBERS_ALL m
        ON r.MEMBER_ID = m.MEMBER_ID
)

SELECT
    CHECK_NAME,
    SEVERITY,
    FAILED_ROWS,
    CASE
        WHEN FAILED_ROWS = 0 THEN 'PASS'
        WHEN SEVERITY = 'ERROR' THEN 'FAIL'
        ELSE 'WARN'
    END AS STATUS
FROM CHECKS; -- THIS IS CTE EXPRESS NAME 


-- Display the latest validation results
SELECT
    CHECK_NAME,
    SEVERITY,
    FAILED_ROWS,
    STATUS
FROM INCUBYTE_ASSESSMENT.GOLD.DQ_RESULTSDQ_RESULTS
WHERE RUN_AT = (SELECT MAX(RUN_AT) FROM DQ_RESULTS)
ORDER BY 
    CASE STATUS WHEN 'FAIL' THEN 1
        WHEN 'WARN' THEN 2
        ELSE 3
    END, CHECK_NAME;


    

CREATE DATABASE IF NOT EXISTS dddm_hdb;
USE dddm_hdb;
SELECT DATABASE();

USE dddm_hdb;
CREATE TABLE IF NOT EXISTS hdb_resale_raw (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    month VARCHAR(7),
    town VARCHAR(80),
    flat_type VARCHAR(30),
    block VARCHAR(20),
    street_name VARCHAR(120),
    storey_range VARCHAR(20),
    floor_area_sqm DECIMAL(8,2),
    flat_model VARCHAR(80),
    lease_commence_date INT,
    remaining_lease VARCHAR(40),
    resale_price DECIMAL(12,2)
);
DESCRIBE hdb_resale_raw;

USE dddm_hdb;
-- Kiem tra tong so giao dich
SELECT COUNT(*) AS total_transactions
FROM hdb_resale_raw;

SELECT
    LEFT(month, 4) AS year,
    COUNT(*) AS total_transactions
FROM hdb_resale_raw
GROUP BY LEFT(month, 4)
ORDER BY year;

-- DATA QUALITY CHECK 1: MISSING VALUES

SELECT
    COUNT(*) AS total_rows,
    SUM(month IS NULL OR TRIM(month) = '')
        AS missing_month,
    SUM(town IS NULL OR TRIM(town) = '')
        AS missing_town,
    SUM(flat_type IS NULL OR TRIM(flat_type) = '')
        AS missing_flat_type,
    SUM(floor_area_sqm IS NULL)
        AS missing_floor_area,
    SUM(remaining_lease IS NULL
        OR TRIM(remaining_lease) = '')
        AS missing_remaining_lease,
    SUM(resale_price IS NULL)
        AS missing_resale_price
FROM dddm_hdb.hdb_resale_raw;

SELECT
    COUNT(*) AS total_rows,
    SUM(block IS NULL OR TRIM(block) = '')
        AS missing_block,
    SUM(street_name IS NULL OR TRIM(street_name) = '')
        AS missing_street_name,
    SUM(storey_range IS NULL OR TRIM(storey_range) = '')
        AS missing_storey_range,
    SUM(flat_model IS NULL OR TRIM(flat_model) = '')
        AS missing_flat_model,
    SUM(lease_commence_date IS NULL)
        AS missing_lease_commence_date
FROM dddm_hdb.hdb_resale_raw;

-- DATA QUALITY CHECK 2: DUPLICATE RECORDS

SELECT
    COUNT(*) AS duplicate_groups,
    COALESCE(SUM(duplicate_count - 1), 0)
        AS extra_identical_rows
FROM (
    SELECT COUNT(*) AS duplicate_count
    FROM dddm_hdb.hdb_resale_raw
    GROUP BY
        month,
        town,
        flat_type,
        block,
        street_name,
        storey_range,
        floor_area_sqm,
        flat_model,
        lease_commence_date,
        remaining_lease,
        resale_price
    HAVING COUNT(*) > 1
) AS duplicates;

-- DATA QUALITY CHECK 3: INVALID VALUES

SELECT
    COUNT(*) AS total_rows,
    SUM(
        month NOT REGEXP
        '^(2024|2025)-(0[1-9]|1[0-2])$'
    ) AS invalid_month,
    SUM(
        floor_area_sqm <= 0
    ) AS invalid_floor_area,
    SUM(
        resale_price <= 0
    ) AS invalid_resale_price,
    SUM(
        lease_commence_date <= 0
        OR lease_commence_date >
           CAST(LEFT(month, 4) AS UNSIGNED)
    ) AS invalid_lease_date
FROM dddm_hdb.hdb_resale_raw;

-- DATA QUALITY CHECK 4: INCONSISTENT VALUES

SELECT
    COUNT(*) AS total_rows,
    SUM(
        storey_range NOT REGEXP
        '^[0-9]{2} TO [0-9]{2}$'
    ) AS invalid_storey_format,
    SUM(
        CAST(LEFT(storey_range, 2) AS UNSIGNED) >
        CAST(RIGHT(storey_range, 2) AS UNSIGNED)
    ) AS reversed_storey_range,
    SUM(
        remaining_lease NOT REGEXP
        '^[0-9]+ years?( [0-9]{2} months?)?$'
    ) AS invalid_remaining_lease_format,
    SUM(
        ABS(
            CAST(SUBSTRING_INDEX(remaining_lease, ' ', 1)
                AS SIGNED)
            - (99 - (
                CAST(LEFT(month, 4) AS SIGNED)
                - lease_commence_date
            ))
        ) > 2
    ) AS lease_year_inconsistency
FROM dddm_hdb.hdb_resale_raw;

SELECT
    transaction_id,
    month,
    town,
    flat_type,
    lease_commence_date,
    remaining_lease,
    CAST(
        SUBSTRING_INDEX(remaining_lease, ' ', 1)
        AS SIGNED
    ) AS reported_years,
    99 - (
        CAST(LEFT(month, 4) AS SIGNED)
        - lease_commence_date
    ) AS estimated_years
FROM dddm_hdb.hdb_resale_raw
WHERE ABS(
    CAST(
        SUBSTRING_INDEX(remaining_lease, ' ', 1)
        AS SIGNED
    )
    -
    (99 - (
        CAST(LEFT(month, 4) AS SIGNED)
        - lease_commence_date
    ))
) > 2;

SELECT
    transaction_id,
    month,
    town,
    block,
    street_name,
    flat_type,
    lease_commence_date,
    remaining_lease,
    resale_price
FROM dddm_hdb.hdb_resale_raw
WHERE transaction_id = 37332;

SELECT
    transaction_id,
    month,
    town,
    block,
    street_name,
    flat_type,
    lease_commence_date,
    remaining_lease,
    resale_price
FROM dddm_hdb.hdb_resale_raw
WHERE town = 'JURONG EAST'
  AND block = '37'
  AND street_name = 'TEBAN GDNS RD'
ORDER BY month, transaction_id;

-- DATA QUALITY CHECK 5: OUTLIERS

SELECT
    COUNT(*) AS total_rows,
    MIN(resale_price) AS min_price,
    ROUND(AVG(resale_price), 2) AS avg_price,
    MAX(resale_price) AS max_price,
    MIN(floor_area_sqm) AS min_area,
    ROUND(AVG(floor_area_sqm), 2) AS avg_area,
    MAX(floor_area_sqm) AS max_area
FROM dddm_hdb.hdb_resale_raw;

SELECT
    transaction_id,
    month,
    town,
    flat_type,
    flat_model,
    floor_area_sqm,
    resale_price
FROM dddm_hdb.hdb_resale_raw
ORDER BY floor_area_sqm DESC
LIMIT 10;

-- Compare Terrace flats in the same town

SELECT
    transaction_id,
    month,
    flat_type,
    flat_model,
    floor_area_sqm,
    resale_price
FROM dddm_hdb.hdb_resale_raw
WHERE town = 'KALLANG/WHAMPOA'
  AND flat_type = '3 ROOM'
  AND flat_model = 'Terrace'
ORDER BY floor_area_sqm DESC
LIMIT 20;

-- IQR OUTLIER CHECK: FLOOR AREA

WITH ranked AS (
    SELECT
        floor_area_sqm,
        ROW_NUMBER() OVER (
            ORDER BY floor_area_sqm
        ) AS rn,
        COUNT(*) OVER () AS n
    FROM dddm_hdb.hdb_resale_raw
),
quartiles AS (
    SELECT
        MAX(CASE
            WHEN rn = CEIL(n * 0.25)
            THEN floor_area_sqm
        END) AS q1,

        MAX(CASE
            WHEN rn = CEIL(n * 0.75)
            THEN floor_area_sqm
        END) AS q3
    FROM ranked
)
SELECT
    q.q1,
    q.q3,
    ROUND(q.q3 - q.q1, 2) AS iqr,
    ROUND(
        q.q1 - 1.5 * (q.q3 - q.q1), 2
    ) AS lower_bound,
    ROUND(
        q.q3 + 1.5 * (q.q3 - q.q1), 2
    ) AS upper_bound,
    SUM(
        t.floor_area_sqm <
            q.q1 - 1.5 * (q.q3 - q.q1)
        OR
        t.floor_area_sqm >
            q.q3 + 1.5 * (q.q3 - q.q1)
    ) AS flagged_outliers
FROM dddm_hdb.hdb_resale_raw t
CROSS JOIN quartiles q
GROUP BY q.q1, q.q3;

WITH ranked AS (
    SELECT
        resale_price,
        ROW_NUMBER() OVER (
            ORDER BY resale_price
        ) AS rn,
        COUNT(*) OVER () AS n
    FROM dddm_hdb.hdb_resale_raw
),
quartiles AS (
    SELECT
        MAX(CASE
            WHEN rn = CEIL(n * 0.25)
            THEN resale_price
        END) AS q1,
        MAX(CASE
            WHEN rn = CEIL(n * 0.75)
            THEN resale_price
        END) AS q3
    FROM ranked
)
SELECT
    q.q1,
    q.q3,
    ROUND(q.q3 - q.q1, 2) AS iqr,
    ROUND(
        q.q1 - 1.5 * (q.q3 - q.q1), 2
    ) AS lower_bound,
    ROUND(
        q.q3 + 1.5 * (q.q3 - q.q1), 2
    ) AS upper_bound,
    SUM(
        t.resale_price <
            q.q1 - 1.5 * (q.q3 - q.q1)
        OR
        t.resale_price >
            q.q3 + 1.5 * (q.q3 - q.q1)
    ) AS flagged_outliers
FROM dddm_hdb.hdb_resale_raw t
CROSS JOIN quartiles q
GROUP BY q.q1, q.q3;

SELECT
    flat_type,
    COUNT(*) AS total_transactions,
    SUM(resale_price > 1110000) AS price_outliers,
    ROUND(
        100 * SUM(resale_price > 1110000) / COUNT(*),
        2
    ) AS outlier_percentage
FROM dddm_hdb.hdb_resale_raw
GROUP BY flat_type
ORDER BY price_outliers DESC;

CREATE DATABASE IF NOT EXISTS dddm_hdb;
USE dddm_hdb;
SELECT DATABASE();

USE dddm_hdb;
CREATE TABLE IF NOT EXISTS hdb_resale_raw (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    month VARCHAR(7),
    town VARCHAR(80),
    flat_type VARCHAR(30),
    block VARCHAR(20),
    street_name VARCHAR(120),
    storey_range VARCHAR(20),
    floor_area_sqm DECIMAL(8,2),
    flat_model VARCHAR(80),
    lease_commence_date INT,
    remaining_lease VARCHAR(40),
    resale_price DECIMAL(12,2)
);
DESCRIBE hdb_resale_raw;

USE dddm_hdb;
-- Kiem tra tong so giao dich
SELECT COUNT(*) AS total_transactions
FROM hdb_resale_raw;

SELECT
    LEFT(month, 4) AS year,
    COUNT(*) AS total_transactions
FROM hdb_resale_raw
GROUP BY LEFT(month, 4)
ORDER BY year;

-- DATA QUALITY CHECK 1: MISSING VALUES

SELECT
    COUNT(*) AS total_rows,
    SUM(month IS NULL OR TRIM(month) = '')
        AS missing_month,
    SUM(town IS NULL OR TRIM(town) = '')
        AS missing_town,
    SUM(flat_type IS NULL OR TRIM(flat_type) = '')
        AS missing_flat_type,
    SUM(floor_area_sqm IS NULL)
        AS missing_floor_area,
    SUM(remaining_lease IS NULL
        OR TRIM(remaining_lease) = '')
        AS missing_remaining_lease,
    SUM(resale_price IS NULL)
        AS missing_resale_price
FROM dddm_hdb.hdb_resale_raw;

SELECT
    COUNT(*) AS total_rows,
    SUM(block IS NULL OR TRIM(block) = '')
        AS missing_block,
    SUM(street_name IS NULL OR TRIM(street_name) = '')
        AS missing_street_name,
    SUM(storey_range IS NULL OR TRIM(storey_range) = '')
        AS missing_storey_range,
    SUM(flat_model IS NULL OR TRIM(flat_model) = '')
        AS missing_flat_model,
    SUM(lease_commence_date IS NULL)
        AS missing_lease_commence_date
FROM dddm_hdb.hdb_resale_raw;

-- DATA QUALITY CHECK 2: DUPLICATE RECORDS

SELECT
    COUNT(*) AS duplicate_groups,
    COALESCE(SUM(duplicate_count - 1), 0)
        AS extra_identical_rows
FROM (
    SELECT COUNT(*) AS duplicate_count
    FROM dddm_hdb.hdb_resale_raw
    GROUP BY
        month,
        town,
        flat_type,
        block,
        street_name,
        storey_range,
        floor_area_sqm,
        flat_model,
        lease_commence_date,
        remaining_lease,
        resale_price
    HAVING COUNT(*) > 1
) AS duplicates;

-- DATA QUALITY CHECK 3: INVALID VALUES

SELECT
    COUNT(*) AS total_rows,
    SUM(
        month NOT REGEXP
        '^(2024|2025)-(0[1-9]|1[0-2])$'
    ) AS invalid_month,
    SUM(
        floor_area_sqm <= 0
    ) AS invalid_floor_area,
    SUM(
        resale_price <= 0
    ) AS invalid_resale_price,
    SUM(
        lease_commence_date <= 0
        OR lease_commence_date >
           CAST(LEFT(month, 4) AS UNSIGNED)
    ) AS invalid_lease_date
FROM dddm_hdb.hdb_resale_raw;

-- DATA QUALITY CHECK 4: INCONSISTENT VALUES

SELECT
    COUNT(*) AS total_rows,
    SUM(
        storey_range NOT REGEXP
        '^[0-9]{2} TO [0-9]{2}$'
    ) AS invalid_storey_format,
    SUM(
        CAST(LEFT(storey_range, 2) AS UNSIGNED) >
        CAST(RIGHT(storey_range, 2) AS UNSIGNED)
    ) AS reversed_storey_range,
    SUM(
        remaining_lease NOT REGEXP
        '^[0-9]+ years?( [0-9]{2} months?)?$'
    ) AS invalid_remaining_lease_format,
    SUM(
        ABS(
            CAST(SUBSTRING_INDEX(remaining_lease, ' ', 1)
                AS SIGNED)
            - (99 - (
                CAST(LEFT(month, 4) AS SIGNED)
                - lease_commence_date
            ))
        ) > 2
    ) AS lease_year_inconsistency
FROM dddm_hdb.hdb_resale_raw;

SELECT
    transaction_id,
    month,
    town,
    flat_type,
    lease_commence_date,
    remaining_lease,
    CAST(
        SUBSTRING_INDEX(remaining_lease, ' ', 1)
        AS SIGNED
    ) AS reported_years,
    99 - (
        CAST(LEFT(month, 4) AS SIGNED)
        - lease_commence_date
    ) AS estimated_years
FROM dddm_hdb.hdb_resale_raw
WHERE ABS(
    CAST(
        SUBSTRING_INDEX(remaining_lease, ' ', 1)
        AS SIGNED
    )
    -
    (99 - (
        CAST(LEFT(month, 4) AS SIGNED)
        - lease_commence_date
    ))
) > 2;

SELECT
    transaction_id,
    month,
    town,
    block,
    street_name,
    flat_type,
    lease_commence_date,
    remaining_lease,
    resale_price
FROM dddm_hdb.hdb_resale_raw
WHERE transaction_id = 37332;

SELECT
    transaction_id,
    month,
    town,
    block,
    street_name,
    flat_type,
    lease_commence_date,
    remaining_lease,
    resale_price
FROM dddm_hdb.hdb_resale_raw
WHERE town = 'JURONG EAST'
  AND block = '37'
  AND street_name = 'TEBAN GDNS RD'
ORDER BY month, transaction_id;

-- DATA QUALITY CHECK 5: OUTLIERS

SELECT
    COUNT(*) AS total_rows,
    MIN(resale_price) AS min_price,
    ROUND(AVG(resale_price), 2) AS avg_price,
    MAX(resale_price) AS max_price,
    MIN(floor_area_sqm) AS min_area,
    ROUND(AVG(floor_area_sqm), 2) AS avg_area,
    MAX(floor_area_sqm) AS max_area
FROM dddm_hdb.hdb_resale_raw;

SELECT
    transaction_id,
    month,
    town,
    flat_type,
    flat_model,
    floor_area_sqm,
    resale_price
FROM dddm_hdb.hdb_resale_raw
ORDER BY floor_area_sqm DESC
LIMIT 10;

-- Compare Terrace flats in the same town

SELECT
    transaction_id,
    month,
    flat_type,
    flat_model,
    floor_area_sqm,
    resale_price
FROM dddm_hdb.hdb_resale_raw
WHERE town = 'KALLANG/WHAMPOA'
  AND flat_type = '3 ROOM'
  AND flat_model = 'Terrace'
ORDER BY floor_area_sqm DESC
LIMIT 20;

-- IQR OUTLIER CHECK: FLOOR AREA

WITH ranked AS (
    SELECT
        floor_area_sqm,
        ROW_NUMBER() OVER (
            ORDER BY floor_area_sqm
        ) AS rn,
        COUNT(*) OVER () AS n
    FROM dddm_hdb.hdb_resale_raw
),
quartiles AS (
    SELECT
        MAX(CASE
            WHEN rn = CEIL(n * 0.25)
            THEN floor_area_sqm
        END) AS q1,

        MAX(CASE
            WHEN rn = CEIL(n * 0.75)
            THEN floor_area_sqm
        END) AS q3
    FROM ranked
)
SELECT
    q.q1,
    q.q3,
    ROUND(q.q3 - q.q1, 2) AS iqr,
    ROUND(
        q.q1 - 1.5 * (q.q3 - q.q1), 2
    ) AS lower_bound,
    ROUND(
        q.q3 + 1.5 * (q.q3 - q.q1), 2
    ) AS upper_bound,
    SUM(
        t.floor_area_sqm <
            q.q1 - 1.5 * (q.q3 - q.q1)
        OR
        t.floor_area_sqm >
            q.q3 + 1.5 * (q.q3 - q.q1)
    ) AS flagged_outliers
FROM dddm_hdb.hdb_resale_raw t
CROSS JOIN quartiles q
GROUP BY q.q1, q.q3;

WITH ranked AS (
    SELECT
        resale_price,
        ROW_NUMBER() OVER (
            ORDER BY resale_price
        ) AS rn,
        COUNT(*) OVER () AS n
    FROM dddm_hdb.hdb_resale_raw
),
quartiles AS (
    SELECT
        MAX(CASE
            WHEN rn = CEIL(n * 0.25)
            THEN resale_price
        END) AS q1,
        MAX(CASE
            WHEN rn = CEIL(n * 0.75)
            THEN resale_price
        END) AS q3
    FROM ranked
)
SELECT
    q.q1,
    q.q3,
    ROUND(q.q3 - q.q1, 2) AS iqr,
    ROUND(
        q.q1 - 1.5 * (q.q3 - q.q1), 2
    ) AS lower_bound,
    ROUND(
        q.q3 + 1.5 * (q.q3 - q.q1), 2
    ) AS upper_bound,
    SUM(
        t.resale_price <
            q.q1 - 1.5 * (q.q3 - q.q1)
        OR
        t.resale_price >
            q.q3 + 1.5 * (q.q3 - q.q1)
    ) AS flagged_outliers
FROM dddm_hdb.hdb_resale_raw t
CROSS JOIN quartiles q
GROUP BY q.q1, q.q3;

SELECT
    flat_type,
    COUNT(*) AS total_transactions,
    SUM(resale_price > 1110000) AS price_outliers,
    ROUND(
        100 * SUM(resale_price > 1110000) / COUNT(*),
        2
    ) AS outlier_percentage
FROM dddm_hdb.hdb_resale_raw
GROUP BY flat_type
ORDER BY price_outliers DESC;

CREATE DATABASE IF NOT EXISTS dddm_hdb;
USE dddm_hdb;
SELECT DATABASE();

USE dddm_hdb;
CREATE TABLE IF NOT EXISTS hdb_resale_raw (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    month VARCHAR(7),
    town VARCHAR(80),
    flat_type VARCHAR(30),
    block VARCHAR(20),
    street_name VARCHAR(120),
    storey_range VARCHAR(20),
    floor_area_sqm DECIMAL(8,2),
    flat_model VARCHAR(80),
    lease_commence_date INT,
    remaining_lease VARCHAR(40),
    resale_price DECIMAL(12,2)
);
DESCRIBE hdb_resale_raw;

USE dddm_hdb;
-- Kiem tra tong so giao dich
SELECT COUNT(*) AS total_transactions
FROM hdb_resale_raw;

SELECT
    LEFT(month, 4) AS year,
    COUNT(*) AS total_transactions
FROM hdb_resale_raw
GROUP BY LEFT(month, 4)
ORDER BY year;

-- DATA QUALITY CHECK 1: MISSING VALUES

SELECT
    COUNT(*) AS total_rows,
    SUM(month IS NULL OR TRIM(month) = '')
        AS missing_month,
    SUM(town IS NULL OR TRIM(town) = '')
        AS missing_town,
    SUM(flat_type IS NULL OR TRIM(flat_type) = '')
        AS missing_flat_type,
    SUM(floor_area_sqm IS NULL)
        AS missing_floor_area,
    SUM(remaining_lease IS NULL
        OR TRIM(remaining_lease) = '')
        AS missing_remaining_lease,
    SUM(resale_price IS NULL)
        AS missing_resale_price
FROM dddm_hdb.hdb_resale_raw;

SELECT
    COUNT(*) AS total_rows,
    SUM(block IS NULL OR TRIM(block) = '')
        AS missing_block,
    SUM(street_name IS NULL OR TRIM(street_name) = '')
        AS missing_street_name,
    SUM(storey_range IS NULL OR TRIM(storey_range) = '')
        AS missing_storey_range,
    SUM(flat_model IS NULL OR TRIM(flat_model) = '')
        AS missing_flat_model,
    SUM(lease_commence_date IS NULL)
        AS missing_lease_commence_date
FROM dddm_hdb.hdb_resale_raw;

-- DATA QUALITY CHECK 2: DUPLICATE RECORDS

SELECT
    COUNT(*) AS duplicate_groups,
    COALESCE(SUM(duplicate_count - 1), 0)
        AS extra_identical_rows
FROM (
    SELECT COUNT(*) AS duplicate_count
    FROM dddm_hdb.hdb_resale_raw
    GROUP BY
        month,
        town,
        flat_type,
        block,
        street_name,
        storey_range,
        floor_area_sqm,
        flat_model,
        lease_commence_date,
        remaining_lease,
        resale_price
    HAVING COUNT(*) > 1
) AS duplicates;

-- DATA QUALITY CHECK 3: INVALID VALUES

SELECT
    COUNT(*) AS total_rows,
    SUM(
        month NOT REGEXP
        '^(2024|2025)-(0[1-9]|1[0-2])$'
    ) AS invalid_month,
    SUM(
        floor_area_sqm <= 0
    ) AS invalid_floor_area,
    SUM(
        resale_price <= 0
    ) AS invalid_resale_price,
    SUM(
        lease_commence_date <= 0
        OR lease_commence_date >
           CAST(LEFT(month, 4) AS UNSIGNED)
    ) AS invalid_lease_date
FROM dddm_hdb.hdb_resale_raw;

-- DATA QUALITY CHECK 4: INCONSISTENT VALUES

SELECT
    COUNT(*) AS total_rows,
    SUM(
        storey_range NOT REGEXP
        '^[0-9]{2} TO [0-9]{2}$'
    ) AS invalid_storey_format,
    SUM(
        CAST(LEFT(storey_range, 2) AS UNSIGNED) >
        CAST(RIGHT(storey_range, 2) AS UNSIGNED)
    ) AS reversed_storey_range,
    SUM(
        remaining_lease NOT REGEXP
        '^[0-9]+ years?( [0-9]{2} months?)?$'
    ) AS invalid_remaining_lease_format,
    SUM(
        ABS(
            CAST(SUBSTRING_INDEX(remaining_lease, ' ', 1)
                AS SIGNED)
            - (99 - (
                CAST(LEFT(month, 4) AS SIGNED)
                - lease_commence_date
            ))
        ) > 2
    ) AS lease_year_inconsistency
FROM dddm_hdb.hdb_resale_raw;

SELECT
    transaction_id,
    month,
    town,
    flat_type,
    lease_commence_date,
    remaining_lease,
    CAST(
        SUBSTRING_INDEX(remaining_lease, ' ', 1)
        AS SIGNED
    ) AS reported_years,
    99 - (
        CAST(LEFT(month, 4) AS SIGNED)
        - lease_commence_date
    ) AS estimated_years
FROM dddm_hdb.hdb_resale_raw
WHERE ABS(
    CAST(
        SUBSTRING_INDEX(remaining_lease, ' ', 1)
        AS SIGNED
    )
    -
    (99 - (
        CAST(LEFT(month, 4) AS SIGNED)
        - lease_commence_date
    ))
) > 2;

SELECT
    transaction_id,
    month,
    town,
    block,
    street_name,
    flat_type,
    lease_commence_date,
    remaining_lease,
    resale_price
FROM dddm_hdb.hdb_resale_raw
WHERE transaction_id = 37332;

SELECT
    transaction_id,
    month,
    town,
    block,
    street_name,
    flat_type,
    lease_commence_date,
    remaining_lease,
    resale_price
FROM dddm_hdb.hdb_resale_raw
WHERE town = 'JURONG EAST'
  AND block = '37'
  AND street_name = 'TEBAN GDNS RD'
ORDER BY month, transaction_id;

-- DATA QUALITY CHECK 5: OUTLIERS

SELECT
    COUNT(*) AS total_rows,
    MIN(resale_price) AS min_price,
    ROUND(AVG(resale_price), 2) AS avg_price,
    MAX(resale_price) AS max_price,
    MIN(floor_area_sqm) AS min_area,
    ROUND(AVG(floor_area_sqm), 2) AS avg_area,
    MAX(floor_area_sqm) AS max_area
FROM dddm_hdb.hdb_resale_raw;

SELECT
    transaction_id,
    month,
    town,
    flat_type,
    flat_model,
    floor_area_sqm,
    resale_price
FROM dddm_hdb.hdb_resale_raw
ORDER BY floor_area_sqm DESC
LIMIT 10;

-- Compare Terrace flats in the same town

SELECT
    transaction_id,
    month,
    flat_type,
    flat_model,
    floor_area_sqm,
    resale_price
FROM dddm_hdb.hdb_resale_raw
WHERE town = 'KALLANG/WHAMPOA'
  AND flat_type = '3 ROOM'
  AND flat_model = 'Terrace'
ORDER BY floor_area_sqm DESC
LIMIT 20;

-- IQR OUTLIER CHECK: FLOOR AREA

WITH ranked AS (
    SELECT
        floor_area_sqm,
        ROW_NUMBER() OVER (
            ORDER BY floor_area_sqm
        ) AS rn,
        COUNT(*) OVER () AS n
    FROM dddm_hdb.hdb_resale_raw
),
quartiles AS (
    SELECT
        MAX(CASE
            WHEN rn = CEIL(n * 0.25)
            THEN floor_area_sqm
        END) AS q1,

        MAX(CASE
            WHEN rn = CEIL(n * 0.75)
            THEN floor_area_sqm
        END) AS q3
    FROM ranked
)
SELECT
    q.q1,
    q.q3,
    ROUND(q.q3 - q.q1, 2) AS iqr,
    ROUND(
        q.q1 - 1.5 * (q.q3 - q.q1), 2
    ) AS lower_bound,
    ROUND(
        q.q3 + 1.5 * (q.q3 - q.q1), 2
    ) AS upper_bound,
    SUM(
        t.floor_area_sqm <
            q.q1 - 1.5 * (q.q3 - q.q1)
        OR
        t.floor_area_sqm >
            q.q3 + 1.5 * (q.q3 - q.q1)
    ) AS flagged_outliers
FROM dddm_hdb.hdb_resale_raw t
CROSS JOIN quartiles q
GROUP BY q.q1, q.q3;

WITH ranked AS (
    SELECT
        resale_price,
        ROW_NUMBER() OVER (
            ORDER BY resale_price
        ) AS rn,
        COUNT(*) OVER () AS n
    FROM dddm_hdb.hdb_resale_raw
),
quartiles AS (
    SELECT
        MAX(CASE
            WHEN rn = CEIL(n * 0.25)
            THEN resale_price
        END) AS q1,
        MAX(CASE
            WHEN rn = CEIL(n * 0.75)
            THEN resale_price
        END) AS q3
    FROM ranked
)
SELECT
    q.q1,
    q.q3,
    ROUND(q.q3 - q.q1, 2) AS iqr,
    ROUND(
        q.q1 - 1.5 * (q.q3 - q.q1), 2
    ) AS lower_bound,
    ROUND(
        q.q3 + 1.5 * (q.q3 - q.q1), 2
    ) AS upper_bound,
    SUM(
        t.resale_price <
            q.q1 - 1.5 * (q.q3 - q.q1)
        OR
        t.resale_price >
            q.q3 + 1.5 * (q.q3 - q.q1)
    ) AS flagged_outliers
FROM dddm_hdb.hdb_resale_raw t
CROSS JOIN quartiles q
GROUP BY q.q1, q.q3;

SELECT
    flat_type,
    COUNT(*) AS total_transactions,
    SUM(resale_price > 1110000) AS price_outliers,
    ROUND(
        100 * SUM(resale_price > 1110000) / COUNT(*),
        2
    ) AS outlier_percentage
FROM dddm_hdb.hdb_resale_raw
GROUP BY flat_type
ORDER BY price_outliers DESC;

SHOW TABLES FROM dddm_hdb
LIKE 'hdb_resale_quality_summary_w2';

USE dddm_hdb;

SELECT *
FROM hdb_resale_quality_summary_w2;

USE dddm_hdb;

SELECT *
FROM hdb_resale_raw
LIMIT 10;

SELECT COUNT(*) AS total_predictions
FROM dddm_hdb.hdb_resale_predictions_w3_2025;

SELECT *
FROM dddm_hdb.hdb_resale_predictions_w3_2025
LIMIT 10;

SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT p.transaction_id) AS unique_transactions
FROM dddm_hdb.hdb_resale_predictions_w3_2025 AS p
JOIN dddm_hdb.hdb_resale_raw AS r
    ON p.transaction_id = r.transaction_id;
    
SELECT
    r.flat_type,
    COUNT(*) AS total_transactions,
    ROUND(AVG(p.prediction_error), 2)
        AS mean_signed_error,
    ROUND(AVG(p.absolute_error), 2)
        AS mae,
    ROUND(AVG(POWER(p.prediction_error, 2)), 2)
        AS mse,
    ROUND(SQRT(AVG(POWER(p.prediction_error, 2))), 2)
        AS rmse,
    ROUND(
        100 * AVG(p.prediction_error > 0), 2
    ) AS underprediction_pct,
    ROUND(
        100 * AVG(p.prediction_error < 0), 2
    ) AS overprediction_pct
FROM dddm_hdb.hdb_resale_predictions_w3_2025 AS p
JOIN dddm_hdb.hdb_resale_raw AS r
    ON p.transaction_id = r.transaction_id
WHERE r.flat_type IN ('3 ROOM', '4 ROOM', '5 ROOM')
GROUP BY r.flat_type
ORDER BY r.flat_type;

SELECT
    COUNT(*) AS total_predictions,
    ROUND(AVG(prediction_error), 2)
        AS mean_signed_error,
    ROUND(AVG(absolute_error), 2)
        AS mae,
    ROUND(
        100 * AVG(prediction_error > 0), 2
    ) AS underprediction_pct,
    ROUND(
        100 * AVG(prediction_error < 0), 2
    ) AS overprediction_pct
FROM dddm_hdb.hdb_resale_predictions_w3_2025;

SELECT
    r.town,
    COUNT(*) AS total_transactions,
    ROUND(AVG(p.prediction_error), 2)
        AS mean_signed_error,
    ROUND(AVG(p.absolute_error), 2)
        AS mae,
    ROUND(
        100 * AVG(p.prediction_error > 0), 2
    ) AS underprediction_pct,
    ROUND(
        100 * AVG(p.prediction_error < 0), 2
    ) AS overprediction_pct
FROM dddm_hdb.hdb_resale_predictions_w3_2025 AS p
JOIN dddm_hdb.hdb_resale_raw AS r
    ON p.transaction_id = r.transaction_id
GROUP BY r.town
ORDER BY mae DESC;

SELECT
    r.town,
    r.flat_type,
    COUNT(*) AS total_transactions,
    ROUND(AVG(p.prediction_error), 2)
        AS mean_signed_error,
    ROUND(AVG(p.absolute_error), 2)
        AS mae,
    ROUND(
        100 * AVG(p.prediction_error > 0), 2
    ) AS underprediction_pct
FROM dddm_hdb.hdb_resale_predictions_w3_2025 AS p
JOIN dddm_hdb.hdb_resale_raw AS r
    ON p.transaction_id = r.transaction_id
GROUP BY r.town, r.flat_type
HAVING COUNT(*) >= 50
ORDER BY mae DESC
LIMIT 20;

SELECT COUNT(*) AS total_records
FROM dddm_hdb.hdb_resale_predictions_w3_2025;

SELECT COUNT(*) AS total_records
FROM dddm_hdb.hdb_resale_baseline_w4_2025;

CREATE VIEW dddm_hdb.hdb_model_comparison_w4_2025 AS
SELECT
    l.transaction_id,
    b.town,
    b.flat_type,
    l.actual_price,
    l.predicted_price AS lr_predicted_price,
    b.baseline_predicted_price,
    l.prediction_error AS lr_signed_error,
    l.absolute_error AS lr_absolute_error,
    (l.actual_price - b.baseline_predicted_price)
        AS baseline_signed_error,
    ABS(l.actual_price - b.baseline_predicted_price)
        AS baseline_absolute_error
FROM dddm_hdb.hdb_resale_predictions_w3_2025 AS l
JOIN dddm_hdb.hdb_resale_baseline_w4_2025 AS b
    ON l.transaction_id = b.transaction_id;

SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT transaction_id) AS unique_transactions
FROM dddm_hdb.hdb_model_comparison_w4_2025;

SELECT
    COUNT(*) AS total_transactions,
    ROUND(AVG(lr_absolute_error), 2) AS lr_mae,
    ROUND(AVG(baseline_absolute_error), 2) AS baseline_mae,
    ROUND(
        SQRT(AVG(POWER(lr_signed_error, 2))), 2
    ) AS lr_rmse,
    ROUND(
        SQRT(AVG(POWER(baseline_signed_error, 2))), 2
    ) AS baseline_rmse,
    ROUND(AVG(lr_signed_error), 2) AS lr_mean_bias,
    ROUND(AVG(baseline_signed_error), 2) AS baseline_mean_bias
FROM dddm_hdb.hdb_model_comparison_w4_2025;

SELECT
    flat_type,
    COUNT(*) AS total_transactions,
    ROUND(AVG(lr_absolute_error), 2) AS mae,

    ROUND(AVG(lr_signed_error), 2) AS mean_signed_error,
    ROUND(
        100 * AVG(lr_signed_error > 0), 2
    ) AS underprediction_pct
FROM dddm_hdb.hdb_model_comparison_w4_2025
GROUP BY flat_type
ORDER BY total_transactions DESC;

SELECT COUNT(*) AS total_records
FROM dddm_hdb.hdb_resale_predictions_w4_2026;

SELECT *
FROM dddm_hdb.hdb_resale_predictions_w4_2026
LIMIT 10;

SELECT
    COUNT(*) AS total_transactions,
    ROUND(AVG(absolute_error), 2) AS mae_2026,
    ROUND(SQRT(AVG(POWER(prediction_error, 2))), 2) AS rmse_2026,
    ROUND(AVG(prediction_error), 2) AS mean_signed_error,
    ROUND(100 * AVG(prediction_error > 0), 2) AS underprediction_pct,
    ROUND(100 * AVG(prediction_error < 0), 2) AS overprediction_pct
FROM dddm_hdb.hdb_resale_predictions_w4_2026;

SELECT
    flat_type,
    COUNT(*) AS total_transactions,
    ROUND(AVG(absolute_error), 2) AS mae,
    ROUND(SQRT(AVG(POWER(prediction_error, 2))), 2) AS rmse,
    ROUND(AVG(prediction_error), 2) AS mean_signed_error,
    ROUND(100 * AVG(prediction_error > 0), 2) AS underprediction_pct
FROM dddm_hdb.hdb_resale_predictions_w4_2026
GROUP BY flat_type
ORDER BY total_transactions DESC;

SELECT
    town,
    COUNT(*) AS total_transactions,
    ROUND(AVG(absolute_error), 2) AS mae,
    ROUND(SQRT(AVG(POWER(prediction_error, 2))), 2) AS rmse,
    ROUND(AVG(prediction_error), 2) AS mean_signed_error,
    ROUND(100 * AVG(prediction_error > 0), 2) AS underprediction_pct
FROM dddm_hdb.hdb_resale_predictions_w4_2026
GROUP BY town
ORDER BY mae DESC;

SELECT
    town,
    flat_type,
    COUNT(*) AS total_transactions,
    ROUND(AVG(absolute_error), 2) AS mae,
    ROUND(AVG(prediction_error), 2) AS mean_signed_error,
    ROUND(100 * AVG(prediction_error > 0), 2) AS underprediction_pct
FROM dddm_hdb.hdb_resale_predictions_w4_2026
GROUP BY town, flat_type
HAVING COUNT(*) >= 30
ORDER BY mae DESC;

SELECT
    ROUND(MAX(
        CASE
            WHEN rn = CEIL(0.90 * total_rows)
            THEN absolute_error
        END
    ), 2) AS error_p90_sgd
FROM (
    SELECT
        absolute_error,
        ROW_NUMBER() OVER (ORDER BY absolute_error) AS rn,
        COUNT(*) OVER () AS total_rows
    FROM dddm_hdb.hdb_resale_predictions_w3_2025
    WHERE absolute_error IS NOT NULL
) AS ranked_errors;

SELECT
    COUNT(*) AS total_transactions,
    117547.79 AS interval_margin_sgd,
    ROUND(
        100 * AVG(
            actual_price BETWEEN
                GREATEST(0, predicted_price - 117547.79)
                AND (predicted_price + 117547.79)
        ), 2
    ) AS coverage_pct
FROM dddm_hdb.hdb_resale_predictions_w4_2026;

CREATE OR REPLACE VIEW dddm_hdb.hdb_resale_intervals_w4_2026 AS
SELECT
    month,
    town,
    flat_type,
    actual_price,
    predicted_price,
    GREATEST(0, predicted_price - 117547.79)
        AS lower_bound,
    predicted_price + 117547.79
        AS upper_bound,
    prediction_error,
    absolute_error,
    CASE
        WHEN actual_price BETWEEN
            GREATEST(0, predicted_price - 117547.79)
            AND predicted_price + 117547.79
        THEN 1 ELSE 0
    END AS within_interval
FROM dddm_hdb.hdb_resale_predictions_w4_2026;

SELECT *
FROM dddm_hdb.hdb_resale_intervals_w4_2026
LIMIT 10;

-- DQ1: Historical Resale Price by Town (2024–2025)

SELECT
    town,
    COUNT(*) AS total_transactions,
    ROUND(AVG(resale_price), 2) AS avg_resale_price_sgd,
    MIN(resale_price) AS min_resale_price_sgd,
    MAX(resale_price) AS max_resale_price_sgd
FROM dddm_hdb.hdb_resale_raw
WHERE month BETWEEN '2024-01' AND '2025-12'
GROUP BY town
ORDER BY avg_resale_price_sgd DESC;

-- DQ1: Historical Resale Price by Floor Area Band
-- Data: 2024–2025

SELECT
    CONCAT(
        area_band_start, ' - ',
        area_band_start + 19, ' sqm'
    ) AS floor_area_band,
    COUNT(*) AS total_transactions,
    ROUND(AVG(resale_price), 2) AS avg_resale_price_sgd
FROM (
    SELECT
        FLOOR(floor_area_sqm / 20) * 20 AS area_band_start,
        resale_price
    FROM dddm_hdb.hdb_resale_raw
    WHERE month BETWEEN '2024-01' AND '2025-12'
      AND floor_area_sqm > 0
) AS area_data
GROUP BY area_band_start
ORDER BY area_band_start;

-- DQ1: Monthly HDB Resale Price Trend (2024–2025)

SELECT
    month AS transaction_month,
    COUNT(*) AS total_transactions,
    ROUND(AVG(resale_price), 2) AS avg_resale_price_sgd
FROM dddm_hdb.hdb_resale_raw
WHERE month BETWEEN '2024-01' AND '2025-12'
GROUP BY month
ORDER BY month;

-- WEEK 4 FINAL
-- End-to-End System Verification
-- Check database outputs without modifying data

USE dddm_hdb;
SELECT
    '1. Raw Dataset 2024-2025' AS component,
    COUNT(*) AS total_records
FROM hdb_resale_raw

UNION ALL

SELECT
    '2. Week 2 Quality Summary',
    COUNT(*)
FROM hdb_resale_quality_summary_w2

UNION ALL

SELECT
    '3. Validation Predictions 2025',
    COUNT(*)
FROM hdb_resale_predictions_w3_2025

UNION ALL

SELECT
    '4. Median Baseline 2025',
    COUNT(*)
FROM hdb_resale_baseline_w4_2025

UNION ALL

SELECT
    '5. Independent Test 2026',
    COUNT(*)
FROM hdb_resale_predictions_w4_2026

UNION ALL

SELECT
    '6. Prediction Intervals 2026',
    COUNT(*)
FROM hdb_resale_intervals_w4_2026;

-- WEEK 4: Verify Demo Workflow Outputs

SELECT 'Validation 2025' AS component,
       COUNT(*) AS total_records
FROM dddm_hdb.hdb_resale_predictions_demo_2025

UNION ALL

SELECT 'Median Baseline 2025',
       COUNT(*)
FROM dddm_hdb.hdb_resale_baseline_demo_2025

UNION ALL

SELECT 'Independent Test 2026',
       COUNT(*)
FROM dddm_hdb.hdb_resale_predictions_demo_2026;

-- Compare Model Results: Final vs Demo

SELECT
    'Validation 2025' AS dataset,
    (SELECT ROUND(AVG(absolute_error), 2)
     FROM dddm_hdb.hdb_resale_predictions_w3_2025)
        AS final_mae,
    (SELECT ROUND(AVG(absolute_error), 2)
     FROM dddm_hdb.hdb_resale_predictions_demo_2025)
        AS demo_mae

UNION ALL

SELECT
    'Independent Test 2026',
    (SELECT ROUND(AVG(absolute_error), 2)
     FROM dddm_hdb.hdb_resale_predictions_w4_2026),
    (SELECT ROUND(AVG(absolute_error), 2)
     FROM dddm_hdb.hdb_resale_predictions_demo_2026);




















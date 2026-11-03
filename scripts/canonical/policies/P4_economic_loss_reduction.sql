-- =========================
-- Canonical SQL query for Policy 4: Economic loss reduction
-- Produces gold GEOID ranking within selected metro area based on P4
-- P4 = L_z
-- =========================
SET VARIABLE selected_metro_id = 'HOU';

WITH 
criteria AS (
    SELECT
        ct.GEOID,
        metro.metro_id,
        nri.RFLD_EALB + nri.RFLD_EALA AS L_raw
    FROM census_tracts ct
    LEFT JOIN nri USING(GEOID)
    INNER JOIN six_metro AS metro
        ON SUBSTRING(ct.GEOID, 0, 6) = metro.county_geoid
    WHERE metro_id = getvariable('selected_metro_id')
),
ranked AS (
    SELECT
        GEOID,
        L_raw, RANK() OVER (ORDER BY L_raw) AS rank_l,
    FROM criteria
),
tract_level_normalized AS (
    SELECT
        GEOID,
        CASE WHEN L_raw IS NULL THEN NULL
            ELSE (AVG(rank_l) OVER (PARTITION BY L_raw) - 1)::DOUBLE
                / (COUNT(L_raw) OVER () - 1)
        END AS L_z,
    FROM ranked
)
SELECT
    GEOID,
    L_z AS P4
FROM tract_level_normalized
ORDER BY P4 DESC;
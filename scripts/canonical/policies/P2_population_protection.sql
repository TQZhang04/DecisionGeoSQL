-- =========================
-- Canonical SQL query for Policy 2: Population protection
-- Produces gold GEOID ranking within selected metro area based on P2
-- P2 = E_z 
-- =========================
SET VARIABLE selected_metro_id = 'HOU';

WITH 
criteria AS (
    SELECT
        ct.GEOID,
        metro.metro_id,
        nri.RFLD_EXPP AS E_raw,
    FROM census_tracts ct
    LEFT JOIN nri USING(GEOID)
    INNER JOIN six_metro AS metro
        ON SUBSTRING(ct.GEOID, 0, 6) = metro.county_geoid
    WHERE metro_id = getvariable('selected_metro_id')
),
ranked AS (
    SELECT
        GEOID,
        E_raw, RANK() OVER (ORDER BY E_raw) AS rank_e
    FROM criteria
),
tract_level_normalized AS (
    SELECT
        GEOID,
        CASE WHEN E_raw IS NULL THEN NULL
            ELSE (AVG(rank_e) OVER (PARTITION BY E_raw) - 1)::DOUBLE
                / (COUNT(E_raw) OVER () - 1)
        END AS E_z,
    FROM ranked
)
SELECT
    GEOID,
    E_z AS P2
FROM tract_level_normalized
ORDER BY P2 DESC;
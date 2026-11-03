-- =========================
-- Canonical SQL query for Policy 3: Equity-aware population protection
-- Produces gold GEOID ranking within selected metro area based on P3
-- P3 = (E_z + V_z) / 2
-- =========================
SET VARIABLE selected_metro_id = 'HOU';

WITH 
criteria AS (
    SELECT
        ct.GEOID,
        metro.metro_id,
        nri.RFLD_EXPP AS E_raw,
        svi.RPL_THEMES AS V_raw
    FROM census_tracts ct
    LEFT JOIN nri USING(GEOID)
    LEFT JOIN svi USING(GEOID)
    INNER JOIN six_metro AS metro
        ON SUBSTRING(ct.GEOID, 0, 6) = metro.county_geoid
    WHERE metro_id = getvariable('selected_metro_id')
),
ranked AS (
    SELECT
        GEOID,
        E_raw, RANK() OVER (ORDER BY E_raw) AS rank_e,
        V_raw, RANK() OVER (ORDER BY V_raw) AS rank_v
    FROM criteria
),
tract_level_normalized AS (
    SELECT
        GEOID,
        CASE WHEN E_raw IS NULL THEN NULL
            ELSE (AVG(rank_e) OVER (PARTITION BY E_raw) - 1)::DOUBLE
                / (COUNT(E_raw) OVER () - 1)
        END AS E_z,
        CASE WHEN V_raw IS NULL THEN NULL
            ELSE (AVG(rank_v) OVER (PARTITION BY V_raw) - 1)::DOUBLE
                / (COUNT(V_raw) OVER () - 1)
        END AS V_z
    FROM ranked
)
SELECT
    GEOID,
    (E_z + V_z) / 2 AS P3
FROM tract_level_normalized
ORDER BY P3 DESC;
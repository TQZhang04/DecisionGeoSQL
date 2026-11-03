-- =========================
-- Canonical SQL query for Policy 1: Hazard screening
-- Produces gold GEOID ranking within selected metro area based on P1
-- P1 = H_z
-- =========================
SET VARIABLE selected_metro_id = 'HOU';

WITH 
criteria AS (
    SELECT
        ct.GEOID,
        metro.metro_id,
        nri.RFLD_EXP_AREA / NULLIF(ST_Area(ST_Transform(ct.geometry, 'EPSG:4269', 'EPSG:5070', always_xy := true)) / 2589988.11, 0) AS H_raw, -- constant converts meters to miles
    FROM census_tracts ct
    LEFT JOIN nri USING(GEOID)
    INNER JOIN six_metro AS metro
        ON SUBSTRING(ct.GEOID, 0, 6) = metro.county_geoid
    WHERE metro_id = getvariable('selected_metro_id')
),
ranked AS (
    SELECT
        GEOID,
        H_raw, RANK() OVER (ORDER BY H_raw) AS rank_h,
    FROM criteria
),
tract_level_normalized AS (
    SELECT
        GEOID,
        CASE WHEN H_raw IS NULL THEN NULL
            ELSE (AVG(rank_h) OVER (PARTITION BY H_raw) - 1)::DOUBLE
                / (COUNT(H_raw) OVER () - 1)
        END AS H_z,
    FROM ranked
)
SELECT
    GEOID,
    H_z AS P1
FROM tract_level_normalized
ORDER BY P1 DESC;
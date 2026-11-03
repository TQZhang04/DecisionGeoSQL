-- =========================
-- Canonical SQL query for F: Community Services
-- F_raw = hospital_count + school_count
--        -> metro percentile ranks
--        -> average composite
-- =========================

WITH 
schools_geom AS
    (SELECT
        SCHOOL_ID,
        ST_POINT(LON, LAT) AS geom
    FROM schools),
hospitals_geom AS
    (SELECT
        HOSPITAL_ID,
        ST_POINT(LON, LAT) AS geom
    FROM hospitals),
-- Hospitals
    --- Clean matches
    clean_matches_hospitals AS (
        SELECT h.HOSPITAL_ID, ct.GEOID
        FROM hospitals_geom h
        JOIN census_tracts ct ON ST_Within(h.geom, ct.geometry)
    ),
    --- Points that touched a boundary and got excluded from clean_matches_hospitals
    boundary_points_hospitals AS (
        SELECT h.HOSPITAL_ID, h.geom
        FROM hospitals h
        WHERE h.HOSPITAL_ID NOT IN (SELECT HOSPITAL_ID FROM clean_matches_hospitals)
    ),
    --- Assign each to its single nearest tract centroid
    boundary_assigned_hospitals AS (
        SELECT
            bp.HOSPITAL_ID,
            ct.GEOID,
            ROW_NUMBER() OVER (
                PARTITION BY bp.HOSPITAL_ID
                ORDER BY ST_Distance(bp.geom, ST_Centroid(ct.geometry))
            ) AS rn
        FROM boundary_points_hospitals bp
        JOIN census_tracts ct ON ST_Intersects(bp.geom, ct.geometry)
    ),
    hospital_tracts AS (
        SELECT HOSPITAL_ID, GEOID FROM clean_matches_hospitals
        UNION ALL
        SELECT HOSPITAL_ID, GEOID FROM boundary_assigned_hospitals WHERE rn = 1
    ),
-- Schools
    clean_matches_schools AS (
        SELECT s.SCHOOL_ID, ct.GEOID
        FROM schools s
        JOIN census_tracts ct ON ST_Within(s.geom, ct.geometry)
    ),
    --- Points that touched a boundary and got excluded from clean_matches_schools
    boundary_points_schools AS (
        SELECT s.SCHOOL_ID, s.geom
        FROM schools s
        WHERE s.SCHOOL_ID NOT IN (SELECT SCHOOL_ID FROM clean_matches_schools)
    ),
    --- Assign each to its single nearest tract centroid
    boundary_assigned_schools AS (
        SELECT
            bp.SCHOOL_ID,
            ct.GEOID,
            ROW_NUMBER() OVER (
                PARTITION BY bp.SCHOOL_ID
                ORDER BY ST_Distance(bp.geom, ST_Centroid(ct.geometry))
            ) AS rn
        FROM boundary_points_schools bp
        JOIN census_tracts ct ON ST_Intersects(bp.geom, ct.geometry)
    ),
    schools_tracts AS (
        SELECT SCHOOL_ID, GEOID FROM clean_matches_schools
        UNION ALL
        SELECT SCHOOL_ID, GEOID FROM boundary_assigned_schools WHERE rn = 1
    ),
    hosp_counts AS (
       SELECT ct.GEOID, COUNT(*) AS hospital_count
       FROM census_tracts ct
       JOIN hospitals h ON ST_Within(h.geom, ct.geometry)
       GROUP BY ct.GEOID
    ),
    school_counts AS (
        SELECT ct.GEOID, COUNT(*) AS school_count
        FROM census_tracts ct
        JOIN schools s ON ST_Within(s.geom, ct.geometry)
        GROUP BY ct.GEOID
    ),
    h_s_counts AS (
        SELECT
            ct.GEOID,
            metro.metro_id,
            COALESCE(h.hospital_count, 0) AS hospital_count,
            COALESCE(sc.school_count, 0) AS school_count
        FROM census_tracts ct
        INNER JOIN six_metro AS metro
            ON SUBSTRING(ct.GEOID, 0, 6) = metro.county_geoid
        LEFT JOIN hosp_counts h ON ct.GEOID = h.GEOID
        LEFT JOIN school_counts sc ON ct.GEOID = sc.GEOID
    ),
    t AS (
        SELECT
            GEOID,
            (PERCENT_RANK() OVER (PARTITION BY metro_id ORDER BY school_count)
            + PERCENT_RANK() OVER (PARTITION BY metro_id ORDER BY hospital_count))
            / 2 AS F_raw
        FROM h_s_counts
    )
SELECT
    ct.GEOID,
    t.F_raw
FROM census_tracts AS ct
LEFT JOIN t USING(GEOID)
INNER JOIN six_metro AS metro
    ON SUBSTRING(ct.GEOID, 0, 6) = metro.county_geoid;
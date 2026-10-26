-- =========================
-- ** FloodSQL Setup Script **
-- Sets up FloodSQL data in a duckdb database and creates analytical tables.
-- Each table maps to a .parquet file included in FloodSQL.
-- ** Running **
-- 1. Set data_dir to the directory with FloodSQL data
-- 2. Run with one of the following options:
--   a. Run `duckdb < DGQSL.sql` to create wk1 deliverables.
--      Files will be saved to data_dir/outputs.
--   b. Run `duckdb -init DGSQL.sql` to start an interactive session
--   c. Run `duckdb < DGSQL.sql database.ddb` to save a persistent database
-- ** Other Info **
-- - If you save a persistent database, it will take up roughly 3.4 Gb of space
--   in addition to the original data
-- =========================

-- Constants
SET VARIABLE data_dir = '../FloodSQL-Bench/data/data/';

-- Load spatial library
INSTALL spatial;
LOAD spatial;

-- Create tables
CREATE OR REPLACE TABLE census_tracts AS
    SELECT * FROM read_parquet(getvariable('data_dir') || 'census_tracts_tx_fl_la.parquet');

ALTER TABLE census_tracts
    ADD PRIMARY KEY (GEOID);

CREATE OR REPLACE TABLE county AS
    SELECT * FROM read_parquet(getvariable('data_dir') || 'county_tx_fl_la.parquet');

ALTER TABLE county
    ADD PRIMARY KEY (GEOID);

CREATE OR REPLACE TABLE zcta AS
    SELECT * FROM read_parquet(getvariable('data_dir') || 'zcta_tx_fl_la.parquet');

ALTER TABLE zcta
    ADD PRIMARY KEY (GEOID); 

CREATE OR REPLACE TABLE floodplain AS
    SELECT * FROM read_parquet(getvariable('data_dir') || 'floodplain_tx_fl_la.parquet');

CREATE OR REPLACE TABLE claims AS
    SELECT * FROM read_parquet(getvariable('data_dir') || 'claims_tx_fl_la.parquet');

ALTER TABLE claims
    ADD PRIMARY KEY (id);

CREATE OR REPLACE TABLE cre AS
    SELECT * FROM read_parquet(getvariable('data_dir') || 'cre_tx_fl_la.parquet');

ALTER TABLE cre
    ADD PRIMARY KEY (GEOID);

CREATE OR REPLACE TABLE nri AS
    SELECT * FROM read_parquet(getvariable('data_dir') || 'nri_tx_fl_la.parquet');

ALTER TABLE nri
    ADD PRIMARY KEY (GEOID);

CREATE OR REPLACE TABLE svi AS
    SELECT * FROM read_parquet(getvariable('data_dir') || 'svi_tx_fl_la.parquet');

ALTER TABLE svi
    ADD PRIMARY KEY (GEOID);

CREATE OR REPLACE TABLE hospitals AS
    SELECT * FROM read_parquet(getvariable('data_dir') || 'hospitals_tx_fl_la.parquet');

ALTER TABLE hospitals
    ADD PRIMARY KEY (HOSPITAL_ID);

CREATE OR REPLACE TABLE schools AS
    SELECT * FROM read_parquet(getvariable('data_dir') || 'schools_tx_fl_la.parquet');

CREATE OR REPLACE TABLE six_metro AS
    SELECT * FROM read_csv(getvariable('data_dir') || 'six_metro_counties.csv');

ALTER TABLE six_metro
    ALTER COLUMN county_geoid TYPE VARCHAR;

-- Clean data

--- Add county GEOID to census_tracts
ALTER TABLE census_tracts
    ADD COLUMN county_geoid VARCHAR;

UPDATE census_tracts
    SET county_geoid = substring(GEOID, 0, 6);

--- Replace null sentinels in SVI

CREATE OR REPLACE TABLE svi AS
    SELECT
        * REPLACE (
            NULLIF(EP_POV150, -999) AS EP_POV150,
            NULLIF(MP_POV150, -999) AS MP_POV150,
            NULLIF(EP_UNEMP, -999) AS EP_UNEMP,
            NULLIF(MP_UNEMP, -999) AS MP_UNEMP,
            NULLIF(EP_HBURD, -999) AS EP_HBURD,
            NULLIF(MP_HBURD, -999) AS MP_HBURD,
            NULLIF(EP_NOHSDP, -999) AS EP_NOHSDP,
            NULLIF(MP_NOHSDP, -999) AS MP_NOHSDP,
            NULLIF(EP_UNINSUR, -999) AS EP_UNINSUR,
            NULLIF(MP_UNINSUR, -999) AS MP_UNINSUR,
            NULLIF(EP_AGE65, -999) AS EP_AGE65,
            NULLIF(MP_AGE65, -999) AS MP_AGE65,
            NULLIF(EP_AGE17, -999) AS EP_AGE17,
            NULLIF(MP_AGE17, -999) AS MP_AGE17,
            NULLIF(EP_DISABL, -999) AS EP_DISABL,
            NULLIF(MP_DISABL, -999) AS MP_DISABL,
            NULLIF(EP_SNGPNT, -999) AS EP_SNGPNT,
            NULLIF(MP_SNGPNT, -999) AS MP_SNGPNT,
            NULLIF(EP_LIMENG, -999) AS EP_LIMENG,
            NULLIF(MP_LIMENG, -999) AS MP_LIMENG,
            NULLIF(EP_MINRTY, -999) AS EP_MINRTY,
            NULLIF(MP_MINRTY, -999) AS MP_MINRTY,
            NULLIF(EP_MUNIT, -999) AS EP_MUNIT,
            NULLIF(MP_MUNIT, -999) AS MP_MUNIT,
            NULLIF(EP_MOBILE, -999) AS EP_MOBILE,
            NULLIF(MP_MOBILE, -999) AS MP_MOBILE,
            NULLIF(EP_CROWD, -999) AS EP_CROWD,
            NULLIF(MP_CROWD, -999) AS MP_CROWD,
            NULLIF(EP_NOVEH, -999) AS EP_NOVEH,
            NULLIF(MP_NOVEH, -999) AS MP_NOVEH,
            NULLIF(EP_GROUPQ, -999) AS EP_GROUPQ,
            NULLIF(MP_GROUPQ, -999) AS MP_GROUPQ,
            NULLIF(EPL_POV150, -999) AS EPL_POV150,
            NULLIF(EPL_UNEMP, -999) AS EPL_UNEMP,
            NULLIF(EPL_HBURD, -999) AS EPL_HBURD,
            NULLIF(EPL_NOHSDP, -999) AS EPL_NOHSDP,
            NULLIF(EPL_UNINSUR, -999) AS EPL_UNINSUR,
            NULLIF(SPL_THEME1, -999) AS SPL_THEME1,
            NULLIF(RPL_THEME1, -999) AS RPL_THEME1,
            NULLIF(EPL_AGE65, -999) AS EPL_AGE65,
            NULLIF(EPL_AGE17, -999) AS EPL_AGE17,
            NULLIF(EPL_DISABL, -999) AS EPL_DISABL,
            NULLIF(EPL_SNGPNT, -999) AS EPL_SNGPNT,
            NULLIF(EPL_LIMENG, -999) AS EPL_LIMENG,
            NULLIF(SPL_THEME2, -999) AS SPL_THEME2,
            NULLIF(RPL_THEME2, -999) AS RPL_THEME2,
            NULLIF(EPL_MINRTY, -999) AS EPL_MINRTY,
            NULLIF(SPL_THEME3, -999) AS SPL_THEME3,
            NULLIF(RPL_THEME3, -999) AS RPL_THEME3,
            NULLIF(EPL_MUNIT, -999) AS EPL_MUNIT,
            NULLIF(EPL_MOBILE, -999) AS EPL_MOBILE,
            NULLIF(EPL_CROWD, -999) AS EPL_CROWD,
            NULLIF(EPL_NOVEH, -999) AS EPL_NOVEH,
            NULLIF(EPL_GROUPQ, -999) AS EPL_GROUPQ,
            NULLIF(SPL_THEME4, -999) AS SPL_THEME4,
            NULLIF(RPL_THEME4, -999) AS RPL_THEME4,
            NULLIF(SPL_THEMES, -999) AS SPL_THEMES,
            NULLIF(RPL_THEMES, -999) AS RPL_THEMES,
            NULLIF(F_POV150, -999) AS F_POV150,
            NULLIF(F_UNEMP, -999) AS F_UNEMP,
            NULLIF(F_HBURD, -999) AS F_HBURD,
            NULLIF(F_NOHSDP, -999) AS F_NOHSDP,
            NULLIF(F_UNINSUR, -999) AS F_UNINSUR,
            NULLIF(F_THEME1, -999) AS F_THEME1,
            NULLIF(F_AGE65, -999) AS F_AGE65,
            NULLIF(F_AGE17, -999) AS F_AGE17,
            NULLIF(F_DISABL, -999) AS F_DISABL,
            NULLIF(F_SNGPNT, -999) AS F_SNGPNT,
            NULLIF(F_LIMENG, -999) AS F_LIMENG,
            NULLIF(F_THEME2, -999) AS F_THEME2,
            NULLIF(F_MINRTY, -999) AS F_MINRTY,
            NULLIF(F_THEME3, -999) AS F_THEME3,
            NULLIF(F_MUNIT, -999) AS F_MUNIT,
            NULLIF(F_MOBILE, -999) AS F_MOBILE,
            NULLIF(F_CROWD, -999) AS F_CROWD,
            NULLIF(F_NOVEH, -999) AS F_NOVEH,
            NULLIF(F_GROUPQ, -999) AS F_GROUPQ,
            NULLIF(F_THEME4, -999) AS F_THEME4,
            NULLIF(F_TOTAL, -999) AS F_TOTAL,
            NULLIF(EP_NOINT, -999) AS EP_NOINT,
            NULLIF(MP_NOINT, -999) AS MP_NOINT,
            NULLIF(EP_AFAM, -999) AS EP_AFAM,
            NULLIF(MP_AFAM, -999) AS MP_AFAM,
            NULLIF(EP_HISP, -999) AS EP_HISP,
            NULLIF(MP_HISP, -999) AS MP_HISP,
            NULLIF(EP_ASIAN, -999) AS EP_ASIAN,
            NULLIF(MP_ASIAN, -999) AS MP_ASIAN,
            NULLIF(EP_AIAN, -999) AS EP_AIAN,
            NULLIF(MP_AIAN, -999) AS MP_AIAN,
            NULLIF(EP_NHPI, -999) AS EP_NHPI,
            NULLIF(MP_NHPI, -999) AS MP_NHPI,
            NULLIF(EP_TWOMORE, -999) AS EP_TWOMORE,
            NULLIF(MP_TWOMORE, -999) AS MP_TWOMORE,
            NULLIF(EP_OTHERRACE, -999) AS EP_OTHERRACE,
            NULLIF(MP_OTHERRACE, -999) AS MP_OTHERRACE 
        )
    FROM svi;

--- Deduplicate schools

CREATE OR REPLACE TABLE schools AS
    SELECT DISTINCT * FROM schools;

--- Create valid geometries for hospitals and schools

ALTER TABLE hospitals ADD COLUMN geom GEOMETRY;

UPDATE hospitals
    SET geom = ST_Point(LON, LAT);

ALTER TABLE schools ADD COLUMN geom GEOMETRY;

UPDATE schools
    SET geom = ST_Point(LON, LAT);

--- Update census tract geometries with explicit CRS
--- (TIGER/Line data uses EPSG:4269)
UPDATE census_tracts
    SET geometry = ST_SetCRS(geometry, 'EPSG:4269');

-- Assign tract to hospitals and schools using spatial joins

--- Create RTREE index on census geometries
CREATE INDEX idx_tracts_geom ON census_tracts USING RTREE (geometry);

--- Points cleanly inside a tract
CREATE OR REPLACE VIEW hospital_tracts AS (
    WITH clean_matches AS (
        SELECT h.HOSPITAL_ID, ct.GEOID
        FROM hospitals h
        JOIN census_tracts ct ON ST_Within(h.geom, ct.geometry)
    ),
    --- Points that touched a boundary and got excluded from clean_matches
    boundary_points AS (
        SELECT h.HOSPITAL_ID, h.geom
        FROM hospitals h
        WHERE h.HOSPITAL_ID NOT IN (SELECT HOSPITAL_ID FROM clean_matches)
    ),
    --- Assign each to its single nearest tract centroid
    boundary_assigned AS (
        SELECT
            bp.HOSPITAL_ID,
            ct.GEOID,
            ROW_NUMBER() OVER (
                PARTITION BY bp.HOSPITAL_ID
                ORDER BY ST_Distance(bp.geom, ST_Centroid(ct.geometry))
            ) AS rn
        FROM boundary_points bp
        JOIN census_tracts ct ON ST_Intersects(bp.geom, ct.geometry)
    )
    SELECT HOSPITAL_ID, GEOID FROM clean_matches
    UNION ALL
    SELECT HOSPITAL_ID, GEOID FROM boundary_assigned WHERE rn = 1
);

CREATE OR REPLACE VIEW school_tracts AS (
    WITH clean_matches AS (
        SELECT s.SCHOOL_ID, ct.GEOID
        FROM schools s
        JOIN census_tracts ct ON ST_Within(s.geom, ct.geometry)
    ),
    --- Points that touched a boundary and got excluded from clean_matches
    boundary_points AS (
        SELECT s.SCHOOL_ID, s.geom
        FROM schools s
        WHERE s.SCHOOL_ID NOT IN (SELECT SCHOOL_ID FROM clean_matches)
    ),
    --- Assign each to its single nearest tract centroid
    boundary_assigned AS (
        SELECT
            bp.SCHOOL_ID,
            ct.GEOID,
            ROW_NUMBER() OVER (
                PARTITION BY bp.SCHOOL_ID
                ORDER BY ST_Distance(bp.geom, ST_Centroid(ct.geometry))
            ) AS rn
        FROM boundary_points bp
        JOIN census_tracts ct ON ST_Intersects(bp.geom, ct.geometry)
    )
    SELECT SCHOOL_ID, GEOID FROM clean_matches
    UNION ALL
    SELECT SCHOOL_ID, GEOID FROM boundary_assigned WHERE rn = 1
);

--- Create table of facility counts
CREATE TABLE h_s_counts AS (
WITH hosp_counts AS (
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
   )
   SELECT
       ct.GEOID,
       ct.NAME,
       COALESCE(h.hospital_count, 0) AS hospital_count,
       COALESCE(sc.school_count, 0) AS school_count
   FROM census_tracts ct
   LEFT JOIN hosp_counts h ON ct.GEOID = h.GEOID
   LEFT JOIN school_counts sc ON ct.GEOID = sc.GEOID
);

-- Compile tract-level data

CREATE OR REPLACE TABLE tract_level AS
    SELECT
        ct.GEOID,
        SUBSTRING(ct.GEOID, 0, 6) AS county_geoid,
        ct.NAME,
        metro.county_name,
        metro.metro_id AS metro_id,
        ST_Area(ST_Transform(geometry, 'EPSG:4269', 'EPSG:5070', always_xy := true)) AS area,
        nri.RFLD_EXP_AREA / NULLIF(ST_Area(ST_Transform(geometry, 'EPSG:4269', 'EPSG:5070', always_xy := true)) / 2589988.11, 0) AS H_raw,
        nri.RFLD_EXPP AS E_raw,
        nri.RFLD_EALB + nri.RFLD_EALA AS L_raw,
        svi.RPL_THEMES AS V_raw,
        hospital_count,
        school_count
    FROM census_tracts AS ct
    LEFT JOIN nri USING(GEOID)
    LEFT JOIN svi USING(GEOID)
    LEFT JOIN h_s_counts AS counts USING(GEOID)
    INNER JOIN six_metro AS metro
        ON SUBSTRING(ct.GEOID, 0, 6) = metro.county_geoid
    ORDER BY GEOID;

ALTER TABLE tract_level
    ADD COLUMN F_raw DOUBLE;

UPDATE tract_level
    SET F_raw = t.F_raw
    FROM (SELECT
            GEOID,
            (PERCENT_RANK() OVER (PARTITION BY metro_id ORDER BY school_count)
            + PERCENT_RANK() OVER (PARTITION BY metro_id ORDER BY hospital_count))
            / 2 AS F_raw
        FROM tract_level) t
    WHERE tract_level.GEOID = t.GEOID;

ALTER TABLE tract_level
    ADD COLUMN geometry GEOMETRY;

UPDATE tract_level
    SET geometry = ct.geometry
    FROM census_tracts ct
    WHERE ct.GEOID = tract_level.GEOID;

COPY tract_level
TO ('../outputs/tract_evidence.parquet') (FORMAT parquet);

-- Save county profiles

COPY
    (SELECT 
        metro_id,
        COUNT(*) AS n_tracts,
        
        AVG(CAST(H_raw IS NULL AS DOUBLE)) AS H_missing,
        AVG(CAST(E_raw IS NULL AS DOUBLE)) AS E_missing,
        AVG(CAST(L_raw IS NULL AS DOUBLE)) AS L_missing,
        AVG(CAST(V_raw IS NULL AS DOUBLE)) AS V_missing,
        SUM(CAST(H_raw > 0 AS DOUBLE)) AS H_gt_0,
        SUM(CAST(L_raw > 0 AS DOUBLE)) AS L_gt_0,
        SUM(CAST(hospital_count > 0 AS DOUBLE)) AS hos_gt_0,
        SUM(CAST(school_count > 0 AS DOUBLE)) AS school_gt_0,
        SUM(CAST(F_raw > 0 AS DOUBLE)) AS F_gt_0,

        MIN(H_raw) AS H_min,
        MAX(H_raw) AS H_max,
        AVG(H_raw) AS H_mean,
        MEDIAN(H_raw) AS H_med,
        STDDEV(H_raw) AS H_std,
        COUNT(DISTINCT H_raw) AS H_unq_ct,
        AVG(CAST(H_raw = 0 AS DOUBLE)) AS percent_H_equal_0,

        MIN(E_raw) AS E_min,
        MAX(E_raw) AS E_max,
        AVG(E_raw) AS E_mean,
        MEDIAN(E_raw) AS E_med,
        STDDEV(E_raw) AS E_std,
        COUNT(DISTINCT E_raw) AS E_unq_ct,
        AVG(CAST(E_raw = 0 AS DOUBLE)) AS percent_E_equal_0,

        MIN(L_raw) AS L_min,
        MAX(L_raw) AS L_max,
        AVG(L_raw) AS L_mean,
        MEDIAN(L_raw) AS L_med,
        STDDEV(L_raw) AS L_std,
        COUNT(DISTINCT L_raw) AS L_unq_ct,
        AVG(CAST(L_raw = 0 AS DOUBLE)) AS percent_L_equal_0,

        MIN(V_raw) AS V_min,
        MAX(V_raw) AS V_max,
        AVG(V_raw) AS V_mean,
        MEDIAN(V_raw) AS V_med,
        STDDEV(V_raw) AS V_std,
        COUNT(DISTINCT V_raw) AS V_unq_ct,
        AVG(CAST(V_raw = 0 AS DOUBLE)) AS percent_V_equal_0,

        MIN(F_raw) AS F_min,
        MAX(F_raw) AS F_max,
        AVG(F_raw) AS F_mean,
        MEDIAN(F_raw) AS F_med,
        STDDEV(F_raw) AS F_std,
        COUNT(DISTINCT F_raw) AS F_unq_ct,
        AVG(CAST(F_raw = 0 AS DOUBLE)) AS percent_F_equal_0,

    FROM tract_level
    GROUP BY metro_id
    )
TO ('../outputs/metro_profile.csv') (FORMAT csv);

--- Extra county summary view for analysis

CREATE OR REPLACE VIEW county_summary AS
           WITH tract_counts AS (
               SELECT
                   county_geoid,
                   COUNT(DISTINCT GEOID) AS n_tracts
               FROM tract_level
               GROUP BY county_geoid
           ),
           city_hospital_counts AS (
               SELECT
                   COUNTYFIPS,
                   CITY,
                   COUNT(*) AS n_hospitals
               FROM hospitals
               GROUP BY COUNTYFIPS, CITY
           ),
           ranked_cities AS (
               SELECT
                   COUNTYFIPS,
                   CITY,
                   n_hospitals,
                   ROW_NUMBER() OVER (
                       PARTITION BY COUNTYFIPS
                       ORDER BY n_hospitals DESC, CITY ASC
                   ) AS city_rank
               FROM city_hospital_counts
           )
           SELECT
               c.NAME as county_name,
               tc.county_geoid,
               tc.n_tracts,
               rc.CITY AS largest_city,
               rc.n_hospitals AS largest_city_hospital_count
           FROM tract_counts tc
           LEFT JOIN ranked_cities rc
             ON rc.COUNTYFIPS = tc.county_geoid
            AND rc.city_rank = 1
           LEFT JOIN county c
             ON rc.COUNTYFIPS = c.GEOID
           ORDER BY tc.county_geoid;

-- Set up normalized criterions

CREATE OR REPLACE VIEW tract_level_normalized AS
WITH ranked AS (
    SELECT
        GEOID,
        county_geoid,
        metro_id,
        H_raw, RANK() OVER (PARTITION BY metro_id ORDER BY H_raw) AS rank_h,
        E_raw, RANK() OVER (PARTITION BY metro_id ORDER BY E_raw) AS rank_e,
        L_raw, RANK() OVER (PARTITION BY metro_id ORDER BY L_raw) AS rank_l,
        V_raw, RANK() OVER (PARTITION BY metro_id ORDER BY V_raw) AS rank_v,
        F_raw, RANK() OVER (PARTITION BY metro_id ORDER BY F_raw) AS rank_f
    FROM tract_level
)
SELECT
    GEOID,
    county_geoid,
    metro_id,
    H_raw,
    CASE WHEN H_raw IS NULL THEN NULL
         ELSE (AVG(rank_h) OVER (PARTITION BY metro_id, H_raw) - 1)::DOUBLE
              / (COUNT(H_raw) OVER (PARTITION BY metro_id) - 1)
    END AS H_z,
    E_raw,
    CASE WHEN E_raw IS NULL THEN NULL
         ELSE (AVG(rank_e) OVER (PARTITION BY metro_id, E_raw) - 1)::DOUBLE
              / (COUNT(E_raw) OVER (PARTITION BY metro_id) - 1)
    END AS E_z,
    L_raw,
    CASE WHEN L_raw IS NULL THEN NULL
         ELSE (AVG(rank_l) OVER (PARTITION BY metro_id, L_raw) - 1)::DOUBLE
              / (COUNT(L_raw) OVER (PARTITION BY metro_id) - 1)
    END AS L_z,
    V_raw,
    CASE WHEN V_raw IS NULL THEN NULL
         ELSE (AVG(rank_v) OVER (PARTITION BY metro_id, V_raw) - 1)::DOUBLE
              / (COUNT(V_raw) OVER (PARTITION BY metro_id) - 1)
    END AS V_z,
    F_raw,
    CASE WHEN F_raw IS NULL THEN NULL
         ELSE (AVG(rank_f) OVER (PARTITION BY metro_id, F_raw) - 1)::DOUBLE
              / (COUNT(F_raw) OVER (PARTITION BY metro_id) - 1)
    END AS F_z
FROM ranked;

-- Normalized policy scores

CREATE OR REPLACE VIEW policy_normalized AS
SELECT
    GEOID,
    county_geoid,
    metro_id,
    H_z AS P1,
    E_z AS P2,
    (E_z + V_z) / 2 AS P3,
    L_z AS P4,
    (H_z + F_z) / 2 AS P5,
    (H_z + E_z + L_z + V_z + F_z) / 5 AS P6
FROM tract_level_normalized;

-- POLICY SEPARABILITY --

--- Unpivot policies to long format

CREATE OR REPLACE VIEW policy_long AS
    UNPIVOT policy_normalized
    ON P1, P2, P3, P4, P5, P6
    INTO NAME policy VALUE score;

--- Create policy ranks

CREATE OR REPLACE VIEW policy_ranks AS
    SELECT
        GEOID,
        county_geoid,
        metro_id,
        policy,
        score,
        ROW_NUMBER() OVER (
            PARTITION BY metro_id, policy
            ORDER BY score DESC, GEOID ASC
        ) AS score_rank,
        COUNT(score) OVER (PARTITION BY metro_id, policy) AS n_valid
    FROM policy_long
    WHERE score IS NOT NULL;

--- Top-10 Jaccard

CREATE OR REPLACE VIEW top10_sets AS
SELECT 
    policy,
    county_geoid,
    metro_id,
    GEOID,
    score,
    score_rank 
FROM policy_ranks 
WHERE score_rank <= 10
    AND county_geoid IN
        (SELECT county_geoid 
        FROM six_metro);

CREATE OR REPLACE VIEW top10_jaccard AS
    WITH sizes AS (
        SELECT policy, metro_id, COUNT(*) AS n
        FROM top10_sets
        GROUP BY policy, metro_id
        HAVING n>=10
    ),
    intersections AS (
        SELECT 
            a.policy AS policy_a,
            b.policy AS policy_b,
            a.metro_id AS metro_id,
            COUNT(*) AS n_intersect
        FROM top10_sets a
        JOIN top10_sets b 
            ON a.GEOID = b.GEOID 
            AND a.policy < b.policy
        GROUP BY a.policy, b.policy, a.metro_id
    )
    SELECT
        sa.metro_id,
        sa.policy AS policy_a,
        sb.policy AS policy_b,
        COALESCE(i.n_intersect, 0) AS n_intersect,
        (sa.n + sb.n) - COALESCE(i.n_intersect, 0) AS n_union,
        COALESCE(i.n_intersect, 0)::DOUBLE / ((sa.n + sb.n) - COALESCE(i.n_intersect, 0)) AS jaccard_top10
    FROM sizes sa
    INNER JOIN sizes sb
        ON sa.policy < sb.policy
        AND sa.metro_id = sb.metro_id
    LEFT JOIN intersections i 
        ON i.policy_a = sa.policy 
        AND i.policy_b = sb.policy 
        AND i.metro_id=sa.metro_id
    ORDER BY policy_a, policy_b;

--- Top 20pct Overlap

CREATE OR REPLACE VIEW top20pct_sets AS
SELECT
    policy,
    county_geoid,
    metro_id,
    GEOID,
    score,
    score_rank
FROM policy_ranks
WHERE score_rank <= FLOOR(0.2 * n_valid)
    AND county_geoid IN
        (SELECT county_geoid 
        FROM six_metro);

CREATE OR REPLACE VIEW top20pct_overlap AS
    WITH sizes AS (
        SELECT 
            policy,
            metro_id,
            COUNT(*) AS n
        FROM top20pct_sets
        GROUP BY policy, metro_id
        HAVING n>=2
    ),
    intersections AS (
        SELECT 
            a.policy AS policy_a,
            b.policy AS policy_b,
            a.metro_id AS metro_id,
            COUNT(*) AS n_intersect
        FROM top20pct_sets a
        JOIN top20pct_sets b
            ON a.GEOID = b.GEOID AND a.policy < b.policy
        GROUP BY a.policy, b.policy, a.metro_id
    )
    SELECT
        sa.metro_id,
        sa.policy AS policy_a,
        sb.policy AS policy_b,
        COALESCE(i.n_intersect, 0) AS n_intersect,
        LEAST(sa.n, sb.n) AS min_n,
        COALESCE(i.n_intersect, 0)::DOUBLE / LEAST(sa.n, sb.n) AS overlap_top20pct
    FROM sizes sa
    INNER JOIN sizes sb
        ON sa.policy < sb.policy
        AND sa.metro_id = sb.metro_id
    LEFT JOIN intersections i
        ON i.policy_a = sa.policy
        AND i.policy_b = sb.policy
        AND i.metro_id=sa.metro_id
    ORDER BY policy_a, policy_b;

--- Kendall's tau

CREATE OR REPLACE VIEW policy_pair_ranks AS
SELECT
    a.GEOID,
    a.metro_id,
    a.policy AS policy_a, a.score_rank AS rank_a, a.score AS score_a,
    b.policy AS policy_b, b.score_rank AS rank_b, b.score AS score_b
FROM policy_ranks a
JOIN policy_ranks b
  ON a.GEOID = b.GEOID
 AND a.policy < b.policy
WHERE a.score IS NOT NULL AND b.score IS NOT NULL
    AND a.county_geoid IN
        (SELECT county_geoid 
        FROM six_metro);

CREATE OR REPLACE VIEW kendall_tau AS
WITH compared AS (
    SELECT
        t1.metro_id,
        t1.policy_a, t1.policy_b,
        SIGN(t1.score_a - t2.score_a) AS sign_a,
        SIGN(t1.score_b - t2.score_b) AS sign_b
    FROM policy_pair_ranks t1
    JOIN policy_pair_ranks t2
      ON t1.metro_id = t2.metro_id
     AND t1.policy_a = t2.policy_a
     AND t1.policy_b = t2.policy_b
     AND t1.GEOID < t2.GEOID
),
counts AS (
    SELECT
        metro_id, policy_a, policy_b,
        COUNT(*) FILTER (WHERE sign_a = sign_b AND sign_a != 0) AS c,
        COUNT(*) FILTER (WHERE sign_a = -sign_b AND sign_a != 0 AND sign_b != 0) AS d,
        COUNT(*) FILTER (WHERE sign_a = 0 AND sign_b != 0) AS ties_a_only,
        COUNT(*) FILTER (WHERE sign_b = 0 AND sign_a != 0) AS ties_b_only,
        COUNT(*) AS n_pairs
    FROM compared
    GROUP BY metro_id, policy_a, policy_b
)
SELECT
    metro_id,
    policy_a,
    policy_b,
    n_pairs,
    c AS concordant,
    d AS discordant,
    (c - d)::DOUBLE / SQRT((c + d + ties_a_only)::DOUBLE * (c + d + ties_b_only)::DOUBLE) AS kendall_tau_b
FROM counts
ORDER BY metro_id, policy_a, policy_b;

--- Compile results

CREATE OR REPLACE VIEW policy_pairs AS
SELECT * FROM (VALUES
    ('P1','P2'), ('P1','P3'), ('P1','P4'), ('P1','P5'), ('P1','P6'),
    ('P2','P3'), ('P2','P4'), ('P2','P5'), ('P2','P6'),
    ('P3','P4'), ('P3','P5'), ('P3','P6'),
    ('P4','P5'), ('P4','P6'),
    ('P5','P6')
) AS t(policy_a, policy_b);

CREATE OR REPLACE TABLE policy_separability AS
SELECT DISTINCT
    c.metro_id AS metro_id,
    p.policy_a,
    p.policy_b,
    j.jaccard_top10,
    o.overlap_top20pct,
    k.kendall_tau_b AS kendall_tau
FROM six_metro c
CROSS JOIN policy_pairs p
LEFT JOIN top10_jaccard j
    ON c.metro_id = j.metro_id
   AND p.policy_a = j.policy_a
   AND p.policy_b = j.policy_b
LEFT JOIN top20pct_overlap o
    ON c.metro_id = o.metro_id
   AND p.policy_a = o.policy_a
   AND p.policy_b = o.policy_b
LEFT JOIN kendall_tau k
    ON c.metro_id = k.metro_id
   AND p.policy_a = k.policy_a
   AND p.policy_b = k.policy_b;

COPY policy_separability
TO ('../outputs/policy_separability.parquet') (FORMAT parquet);

-- LEAVE ONE OUT EXPERIMENTS --

--- Set up LOO policy scores

CREATE OR REPLACE VIEW policy_normalized_loo AS
SELECT
    GEOID,
    county_geoid,
    metro_id,
    (V_z) AS P3_loo_E,
    (E_z) AS P3_loo_V,
    (F_z) AS P5_loo_H,
    (H_z) AS P5_loo_F,
    (E_z + L_z + V_z + F_z) / 4 AS P6_loo_H,
    (H_z + L_z + V_z + F_z) / 4 AS P6_loo_E,
    (H_z + E_z + V_z + F_z) / 4 AS P6_loo_L,
    (H_z + E_z + L_z + F_z) / 4 AS P6_loo_V,
    (H_z + E_z + L_z + V_z) / 4 AS P6_loo_F
FROM tract_level_normalized;

--- LOO ranks
CREATE OR REPLACE VIEW policy_long_loo AS
UNPIVOT policy_normalized_loo
ON P3_loo_E, P3_loo_V, P5_loo_H, P5_loo_F, P6_loo_H, P6_loo_E, P6_loo_L, P6_loo_V, P6_loo_F
INTO NAME policy VALUE score;

CREATE OR REPLACE VIEW policy_ranks_loo AS
SELECT
    GEOID,
    county_geoid,
    metro_id,
    policy,
    score,
    ROW_NUMBER() OVER (
        PARTITION BY metro_id, policy
        ORDER BY score DESC, GEOID ASC
    ) AS score_rank,
    COUNT(score) OVER (PARTITION BY metro_id, policy) AS n_valid
FROM policy_long_loo
WHERE score IS NOT NULL;

--- LOO Top-10 Jaccard

CREATE OR REPLACE VIEW top10_sets_loo AS
    SELECT policy, metro_id, GEOID, score, score_rank 
    FROM policy_ranks_loo
    WHERE score_rank <= 10
        AND county_geoid IN
            (SELECT county_geoid 
            FROM six_metro);

CREATE OR REPLACE VIEW top10_jaccard_loo AS
    WITH parent_sizes AS (
        SELECT policy, metro_id, COUNT(*) AS n
        FROM top10_sets
        WHERE policy IN ('P3','P5','P6')
        GROUP BY policy, metro_id
        HAVING n >= 10
    ),
    loo_sizes AS (
        SELECT policy, metro_id, COUNT(*) AS n
        FROM top10_sets_loo
        GROUP BY policy, metro_id
        HAVING n >= 10
    ),
    intersections AS (
        SELECT
            a.policy AS policy_parent,
            b.policy AS policy_loo,
            a.metro_id,
            COUNT(*) AS n_intersect
        FROM top10_sets a
        JOIN top10_sets_loo b
            ON a.GEOID = b.GEOID
            AND a.policy = SPLIT_PART(b.policy, '_loo_', 1)
        WHERE a.policy IN ('P2','P3','P5','P6')
        GROUP BY a.policy, b.policy, a.metro_id
    )
    SELECT
        p.metro_id,
        p.policy AS policy_parent,
        l.policy AS policy_loo,
        COALESCE(i.n_intersect, 0) AS n_intersect,
        (p.n + l.n) - COALESCE(i.n_intersect, 0) AS n_union,
        COALESCE(i.n_intersect, 0)::DOUBLE / ((p.n + l.n) - COALESCE(i.n_intersect, 0)) AS jaccard_top10
    FROM parent_sizes p
    INNER JOIN loo_sizes l
        ON p.metro_id = l.metro_id
       AND p.policy = SPLIT_PART(l.policy, '_loo_', 1)
    LEFT JOIN intersections i
        ON i.policy_parent = p.policy
       AND i.policy_loo = l.policy
       AND i.metro_id = p.metro_id
    ORDER BY p.metro_id, policy_parent, policy_loo;

--- LOO Top 20pct Overlap

CREATE OR REPLACE VIEW top20pct_sets_loo AS
SELECT policy, metro_id, GEOID, score, score_rank
FROM policy_ranks_loo
WHERE score_rank <= FLOOR(0.2 * n_valid)
    AND county_geoid IN
        (SELECT county_geoid 
        FROM six_metro);

CREATE OR REPLACE VIEW top20pct_overlap_loo AS
    WITH parent_sizes AS (
        SELECT policy, metro_id, COUNT(*) AS n
        FROM top20pct_sets
        WHERE policy IN ('P3','P5','P6')
        GROUP BY policy, metro_id
        HAVING n>=2
    ),
    loo_sizes AS (
        SELECT policy, metro_id, COUNT(*) AS n
        FROM top20pct_sets_loo
        GROUP BY policy, metro_id
        HAVING n>=2
    ),
    intersections AS (
        SELECT
            a.policy AS policy_parent,
            b.policy AS policy_loo,
            a.metro_id AS metro_id,
            COUNT(*) AS n_intersect
        FROM top20pct_sets a
        JOIN top20pct_sets_loo b
            ON a.GEOID = b.GEOID
            AND a.policy = SPLIT_PART(b.policy, '_loo_', 1)
        GROUP BY a.policy, b.policy, a.metro_id
    )
    SELECT
        p.metro_id,
        p.policy AS policy_parent,
        l.policy AS policy_loo,
        COALESCE(i.n_intersect, 0) AS n_intersect,
        LEAST(p.n, l.n) AS min_n,
        COALESCE(i.n_intersect, 0)::DOUBLE / LEAST(p.n, l.n) AS overlap_top20pct
    FROM parent_sizes p
    INNER JOIN loo_sizes l
        ON p.policy = SPLIT_PART(l.policy, '_loo_', 1)
        AND p.metro_id = l.metro_id
    LEFT JOIN intersections i
        ON i.policy_parent = p.policy
        AND i.policy_loo = l.policy
        AND i.metro_id = p.metro_id
    ORDER BY p.metro_id, policy_parent, policy_loo;

--- LOO Kendall's Tau
CREATE OR REPLACE VIEW policy_pair_ranks_loo AS
SELECT
    p.GEOID,
    p.metro_id,
    p.policy AS policy_parent, p.score_rank AS rank_parent, p.score AS score_parent,
    l.policy AS policy_loo, l.score_rank AS rank_loo, l.score AS score_loo
FROM policy_ranks p
JOIN policy_ranks_loo l
  ON p.GEOID = l.GEOID
 AND p.policy = SPLIT_PART(l.policy, '_loo_', 1)
WHERE p.score_rank IS NOT NULL AND l.score_rank IS NOT NULL
    AND p.county_geoid IN
        (SELECT county_geoid 
        FROM six_metro);;

CREATE OR REPLACE VIEW kendall_tau_loo AS
WITH compared AS (
    SELECT
        t1.metro_id,
        t1.policy_parent, t1.policy_loo,
        SIGN(t1.score_parent - t2.score_parent) AS sign_parent,
        SIGN(t1.score_loo - t2.score_loo) AS sign_loo
    FROM policy_pair_ranks_loo t1
    JOIN policy_pair_ranks_loo t2
      ON t1.metro_id = t2.metro_id
     AND t1.policy_parent = t2.policy_parent
     AND t1.policy_loo = t2.policy_loo
     AND t1.GEOID < t2.GEOID
),
counts AS (
    SELECT
        metro_id, policy_parent, policy_loo,
        COUNT(*) FILTER (WHERE sign_parent = sign_loo AND sign_parent != 0) AS c,
        COUNT(*) FILTER (WHERE sign_parent = -sign_loo AND sign_parent != 0 AND sign_loo != 0) AS d,
        COUNT(*) FILTER (WHERE sign_parent = 0 AND sign_loo != 0) AS ties_parent_only,
        COUNT(*) FILTER (WHERE sign_loo = 0 AND sign_parent != 0) AS ties_loo_only,
        COUNT(*) AS n_pairs
    FROM compared
    GROUP BY metro_id, policy_parent, policy_loo
)
SELECT
    metro_id,
    policy_parent,
    policy_loo,
    n_pairs,
    c AS concordant,
    d AS discordant,
    ties_parent_only,
    ties_loo_only,
    (c - d)::DOUBLE / SQRT((c + d + ties_parent_only)::DOUBLE * (c + d + ties_loo_only)::DOUBLE) AS kendall_tau_b
FROM counts
ORDER BY metro_id, policy_parent, policy_loo;

--- LOO Rank Regret

---- Total scores

CREATE OR REPLACE VIEW policy_normalized_total AS
SELECT
    GEOID,
    county_geoid,
    metro_id,
    H_z AS P1,
    E_z AS P2,
    (E_z + V_z) AS P3,
    L_z AS P4,
    (H_z + F_z) AS P5,
    (H_z + E_z + L_z + V_z + F_z) AS P6
FROM tract_level_normalized;

CREATE OR REPLACE VIEW policy_normalized_total_loo AS
SELECT
    GEOID,
    county_geoid,
    metro_id,
    (V_z) AS P3_loo_E,
    (E_z) AS P3_loo_V,
    (F_z) AS P5_loo_H,
    (H_z) AS P5_loo_F,
    (E_z + L_z + V_z + F_z) AS P6_loo_H,
    (H_z + L_z + V_z + F_z) AS P6_loo_E,
    (H_z + E_z + V_z + F_z) AS P6_loo_L,
    (H_z + E_z + L_z + F_z) AS P6_loo_V,
    (H_z + E_z + L_z + V_z) AS P6_loo_F
FROM tract_level_normalized;

---- Long versions

CREATE OR REPLACE VIEW policy_total_long AS
    UNPIVOT policy_normalized_total
    ON P1, P2, P3, P4, P5, P6
    INTO NAME policy VALUE score;

CREATE OR REPLACE VIEW policy_total_long_loo AS
    UNPIVOT policy_normalized_total_loo
    ON P3_loo_E, P3_loo_V, P5_loo_H, P5_loo_F, P6_loo_H, P6_loo_E, P6_loo_L, P6_loo_V, P6_loo_F
    INTO NAME policy VALUE score;

---- Build rank regrets
---- Note: Policy-based rankings remain the same after totaling instead of
----       averaging criteria scores; since we're not comparing across policies,
----       we can use old ranks

CREATE OR REPLACE VIEW rank_regrets_loo AS    
    WITH ranks AS
        (SELECT 
            p.GEOID, p.metro_id,
            p.policy AS policy_parent, p.score_rank AS parent_rank,
            l.policy AS policy_loo, l.score_rank AS loo_rank
        FROM policy_ranks p
        JOIN policy_ranks_loo l
            ON p.GEOID = l.GEOID
            AND p.policy = SPLIT_PART(l.policy, '_loo_', 1)
        ),
    total_scores AS
        (SELECT
            p.GEOID, p.metro_id,
            p.policy AS policy_parent, p.score AS parent_score,
            l.policy AS policy_loo, l.score AS loo_score
        FROM policy_total_long p
        JOIN policy_total_long_loo l
            ON p.GEOID = l.GEOID
            AND p.policy = SPLIT_PART(l.policy, '_loo_', 1)
        )
    SELECT
        r.metro_id,
        r.policy_parent,
        r.policy_loo,
        COUNT(*) AS n_tracts,
        1 - (SUM(s.loo_score) / SUM(s.parent_score)) AS regret_10
    FROM ranks r
    JOIN total_scores s
        ON r.GEOID = s.GEOID
        AND r.policy_parent = s.policy_parent
        AND r.policy_loo = s.policy_loo
    WHERE parent_rank <= 10
    GROUP BY r.metro_id, r.policy_parent, r.policy_loo;

--- Compile results

CREATE OR REPLACE VIEW policy_pairs_loo AS
SELECT * FROM (VALUES
    ('P3', 'P3_loo_E'), ('P3', 'P3_loo_V'),
    ('P5', 'P5_loo_H'), ('P5', 'P5_loo_F'),
    ('P6', 'P6_loo_H'), ('P6', 'P6_loo_E'), ('P6', 'P6_loo_L'), ('P6', 'P6_loo_V'), ('P6', 'P6_loo_F')
) AS t(policy_parent, policy_loo);

CREATE OR REPLACE TABLE policy_separability_loo AS
SELECT DISTINCT
    c.metro_id AS metro_id,
    p.policy_parent,
    p.policy_loo,
    j.jaccard_top10,
    o.overlap_top20pct,
    k.kendall_tau_b AS kendall_tau,
    r.regret_10
FROM six_metro c
CROSS JOIN policy_pairs_loo p
LEFT JOIN top10_jaccard_loo j
    ON c.metro_id = j.metro_id
   AND p.policy_parent = j.policy_parent
   AND p.policy_loo = j.policy_loo
LEFT JOIN top20pct_overlap_loo o
    ON c.metro_id = o.metro_id
   AND p.policy_parent = o.policy_parent
   AND p.policy_loo = o.policy_loo
LEFT JOIN kendall_tau_loo k
    ON c.metro_id = k.metro_id
   AND p.policy_parent = k.policy_parent
   AND p.policy_loo = k.policy_loo
LEFT JOIN rank_regrets_loo r
    ON c.metro_id = r.metro_id
   AND p.policy_parent = r.policy_parent
   AND p.policy_loo = r.policy_loo;

COPY policy_separability_loo
TO ('../outputs/policy_separability_loo.parquet') (FORMAT parquet);

--- FUNDAMENTAL BENCHMARKS --

---- Use policy_ranks for benchmark

CREATE OR REPLACE TABLE benchmark_ranks
AS SELECT * FROM policy_ranks;

ALTER TABLE benchmark_ranks
ADD COLUMN benchmark VARCHAR;

UPDATE benchmark_ranks
SET benchmark = CONCAT(metro_id, '_', policy);

---- Set up dev and held-out test sets

ALTER TABLE benchmark_ranks
ADD COLUMN split VARCHAR;

UPDATE benchmark_ranks
SET split = 
    (
    CASE
        WHEN metro_id = 'DFW' 
            OR metro_id = 'SAN'
            THEN 'held_out_TX'
        WHEN metro_id = 'MFL'
            OR metro_id = 'NOL'
            THEN 'held_out_XS'
        WHEN metro_id = 'HOU'
            OR metro_id = 'AUS'
            THEN 'dev'
        ELSE 'train'
    END
    );


--- ANALYSIS QUERIES ---

--- Policy separability
SELECT
    policy_a,
    policy_b,
    AVG(jaccard_top10),
    AVG(overlap_top20pct),
    AVG(kendall_tau)
FROM policy_separability
GROUP BY policy_a, policy_b;

--- LOO effect
SELECT
    policy_parent,
    policy_loo,
    AVG(jaccard_top10) AS avg_jaccard_top10, COUNT(jaccard_top10) AS n_jaccard,
    AVG(overlap_top20pct) AS avg_overlap_top20pct, COUNT(overlap_top20pct) AS n_overlap,
    AVG(kendall_tau) AS avg_kendall_tau, COUNT(kendall_tau) AS n_tau,
    AVG(regret_10) AS avg_top10_score_regret, COUNT(regret_10) AS n_regret
FROM policy_separability_loo
GROUP BY policy_parent, policy_loo
ORDER BY policy_parent, policy_loo;

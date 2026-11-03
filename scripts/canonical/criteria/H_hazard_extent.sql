-- =========================
-- Canonical SQL query for H: Flood Hazard Extent
-- H_raw = nri.RFLD_EXP_AREA (flood-exposed area, sqmi) / tract area (sqmi)
-- =========================

SELECT
    ct.GEOID,
    nri.RFLD_EXP_AREA / NULLIF(ST_Area(ST_Transform(ct.geometry, 'EPSG:4269', 'EPSG:5070', always_xy := true)) / 2589988.11, 0) AS H_raw, -- constant converts meters to miles
FROM census_tracts ct
LEFT JOIN nri USING(GEOID)
INNER JOIN six_metro AS metro
    ON SUBSTRING(ct.GEOID, 0, 6) = metro.county_geoid;
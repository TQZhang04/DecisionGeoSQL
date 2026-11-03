-- =========================
-- Canonical SQL query for E: Population Exposure
-- E_raw = nri.RFLD_EXPP (Exposed population)
-- =========================

SELECT
    ct.GEOID,
    nri.RFLD_EXPP AS E_raw,
FROM census_tracts ct
LEFT JOIN nri USING(GEOID)
INNER JOIN six_metro AS metro
    ON SUBSTRING(ct.GEOID, 0, 6) = metro.county_geoid;
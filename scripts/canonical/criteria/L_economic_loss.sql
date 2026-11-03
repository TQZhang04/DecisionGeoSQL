-- =========================
-- Canonical SQL query for L: Potential Economic Loss
-- L_raw = nri.RFLD_EALB (Building economic loss) + nri.RFLD_EALA (Agricultural economic loss)
-- =========================

SELECT
    ct.GEOID,
    nri.RFLD_EALB + nri.RFLD_EALA AS L_raw,
FROM census_tracts ct
LEFT JOIN nri USING(GEOID)
INNER JOIN six_metro AS metro
    ON SUBSTRING(ct.GEOID, 0, 6) = metro.county_geoid;
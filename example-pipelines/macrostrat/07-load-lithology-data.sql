CREATE OR REPLACE VIEW weaver_macrostrat.unit_liths AS
SELECT
  unit_id,
  jsonb_agg(
    jsonb_strip_nulls(jsonb_build_object(
      'id', lith_id,
      'name', lith,
      'type', lith_type,
      'prop', dom
    ))
  ) liths FROM macrostrat.unit_liths ul
JOIN macrostrat.liths l
ON l.id = ul.lith_id
GROUP BY (unit_id);

SELECT DISTINCT
  m.id measuremeta_id,
  u.strat_name,
  c.col_id,
  u.id unit_id,
  ul.liths
FROM macrostrat.measuremeta m
JOIN macrostrat.units u ON
  u.strat_name = m.sample_geo_unit
JOIN macrostrat.col_areas c
 ON ST_Intersects(ST_SetSRID(ST_MakePoint(m.lng, m.lat), 4326), c.col_area)
JOIN weaver_macrostrat.unit_liths ul
  ON ul.unit_id = u.id
WHERE u.strat_name IS NOT NULL
  AND c.col_id = u.col_id;
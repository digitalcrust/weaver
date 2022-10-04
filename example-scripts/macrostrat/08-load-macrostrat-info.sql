WITH untracked_measurements AS (
  SELECT
    measuremeta_id,
    dataset_id
  FROM weaver_macrostrat.measuremeta_dataset
  EXCEPT
  SELECT DISTINCT
    measuremeta_id, dataset_id
  FROM weaver_macrostrat.measuremeta_dataset
  JOIN weaver.dataset_data USING (dataset_id)
  WHERE model_name = 'MacrostratMeasure'
), objects AS (
  SELECT
    jsonb_build_object(
      'measuremeta_id',
      m.id,
      'ref_id',
      m.ref_id,
      'url',
      'https://macrostrat.org/api/v2/measurements?measuremeta_id=' || m.id :: text
    ) data,
    um.dataset_id
  FROM macrostrat.measuremeta m
  JOIN untracked_measurements um ON um.measuremeta_id = m.id
)
SELECT weaver.add_datum(dataset_id, 'MacrostratMeasure', data)
FROM objects;

CREATE TABLE IF NOT EXISTS weaver_macrostrat.ref_datum (
  ref_id integer NOT NULL,
  datum_id uuid NOT NULL
);


WITH target AS (
  SELECT id FROM macrostrat.refs
  EXCEPT
  SELECT ref_id FROM weaver_macrostrat.ref_datum
), a AS (
  SELECT
    id,
    jsonb_strip_nulls(jsonb_build_object(
      'year', pub_year::integer,
      'author', author,
      'doi', CASE
        WHEN doi = '' THEN NULL
        ELSE doi
      END,
      'title', ref
    )) obj
  FROM macrostrat.refs
  JOIN target USING (id)
)
INSERT INTO weaver_macrostrat.ref_datum (ref_id, datum_id)
SELECT id, weaver.add_datum(null, 'Publication', obj) inserted_id
FROM a;

-- Add compilations to database
WITH compilations AS (
	SELECT DISTINCT compilation_code
	FROM macrostrat.refs
	WHERE compilation_code IS NOT null
	  AND compilation_code != ''
	EXCEPT
	SELECT data->>'name'
	FROM weaver.datum
	WHERE model_name = 'Compilation'
)
SELECT weaver.add_datum(null, 'Compilation'::text, jsonb_build_object('name', compilation_code))
FROM compilations;

-- Insert references and compilations into the dataset_data table
WITH target AS (
  SELECT
    m.id,
    m.ref_id,
    nullif(compilation_code, '') compilation_code,
    d.dataset_id,
    rd.datum_id
  FROM
    macrostrat.measuremeta m
    JOIN macrostrat.refs r ON m.ref_id = r.id
    JOIN weaver_macrostrat.measuremeta_dataset d ON d.measuremeta_id = m.id
    JOIN weaver_macrostrat.ref_datum rd ON rd.ref_id = r.id
)
INSERT INTO
  weaver.data_link (dataset_id, datum_id)
SELECT
  dataset_id,
  datum_id
FROM
  target
UNION
SELECT
  t.dataset_id,
  d.id
FROM
  target t
  JOIN weaver.datum d ON d.model_name = 'Compilation'
  AND d.data ->> 'name' = compilation_code
WHERE
  compilation_code IS NOT NULL ON CONFLICT (dataset_id, datum_id) DO NOTHING;


INSERT INTO weaver.data_source (name, url)
VALUES ('Macrostrat', 'https://macrostrat.org')
ON CONFLICT (name) DO NOTHING;

-- Add data source to dataset table
UPDATE weaver.dataset
SET source_id = (SELECT id FROM weaver.data_source WHERE name = 'Macrostrat')
WHERE id IN (SELECT dataset_id FROM weaver_macrostrat.measuremeta_dataset);
WITH target AS (
  SELECT
  DISTINCT m.id measuremeta_id,
  u.strat_name,
  c.col_id :: integer,
  u.id unit_id
FROM
  macrostrat.measuremeta m
  JOIN macrostrat.units u ON u.strat_name = m.sample_geo_unit
  JOIN macrostrat.col_areas c ON ST_Intersects(
    ST_SetSRID(ST_MakePoint(m.lng, m.lat), 4326),
    c.col_area
  )
WHERE
  u.strat_name IS NOT NULL
  AND c.col_id = u.col_id
EXCEPT
SELECT
  m.measuremeta_id,
  d.data ->> 'strat_name',
  (d.data ->> 'column_id') :: integer,
  (d.data ->> 'unit_id') :: integer
FROM
  weaver_macrostrat.measuremeta_dataset m
  JOIN weaver.dataset_data dd ON dd.dataset_id = m.dataset_id
  AND dd.model_name = 'MacrostratUnit'
  JOIN weaver.datum d ON dd.datum_id = d.id
), obj AS (
  SELECT
    md.dataset_id,
    jsonb_build_object(
      'column_id',
      col_id,
      'unit_id',
      a.unit_id,
      'strat_name',
      strat_name,
      'liths',
      ul.liths
    ) data
  FROM
    target a
    JOIN weaver_macrostrat.unit_liths ul USING (unit_id)
    JOIN weaver_macrostrat.measuremeta_dataset md USING (measuremeta_id)
)
INSERT INTO
  weaver.data_link (datum_id, dataset_id)
SELECT
  weaver.add_datum(NULL, 'MacrostratUnit', data) datum_id,
  obj.dataset_id
FROM
  obj;
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

-- Link references and compilations to the approriate datasets
WITH refs AS (
  SELECT
    ref_id,
    dataset_id
  FROM weaver_macrostrat.ref_datum
  JOIN macrostrat.measuremeta ON measuremeta.id = measuremeta_id
  WHERE ref_id IS NOT NULL
), compilations AS (
  SELECT
    compilation_code,
    dataset_id
  FROM weaver_macrostrat.measuremeta_dataset
  JOIN macrostrat.measuremeta USING (measuremeta_id)
  WHERE compilation_code IS NOT NULL
)

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

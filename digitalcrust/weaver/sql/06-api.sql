-- available at https://next.macrostrat.org/psql_api/

CREATE SCHEMA IF NOT EXISTS weaver_api;

/* New design idea:
- dataset should be reworked as "locale" which can be linked to a single datum or generalize among them
  - That way, 'locales' can be used to represent regions (e.g., formations) as well as individual measurements
- data should optionally be located (?) themselves
*/

DROP VIEW IF EXISTS weaver_api.dataset CASCADE;
CREATE VIEW weaver_api.dataset AS
WITH data AS (
SELECT
	id,
	ARRAY[model_name, id::text, data->>'url'] val
FROM weaver.datum
)
SELECT
  d.id,
  d.location,
  s.name,
  s.url,
  d.model_name,
  d.data,
  json_agg(dm.val) associated_data
FROM weaver.dataset d
JOIN weaver.data_link dl
  ON dl.dataset_id = d.id
JOIN weaver.data_source s
  ON d.source_id = s.id
JOIN data dm
  ON dl.datum_id = dm.id
GROUP BY d.id, s.name, s.url
ORDER BY d.id;

CREATE OR REPLACE VIEW weaver_api.data_unified_strict AS
SELECT
	dm.id id,
	dm.dataset_id,
	dm.model_name,
	'datum' type,
	dm.data ->> 'url' url,
	dm.data,
	s.id source_id,
	s.name source_name,
	s.url source_url,
	dm.created_at,
	dm.updated_at,
	d.location
FROM weaver.datum dm
JOIN weaver.dataset d
  ON dm.dataset_id = d.id
JOIN weaver.data_source s
  ON s.id = d.source_id
UNION ALL
SELECT
	d.id,
	d.id dataset_id,
	d.model_name,
	'dataset' type,
	d.data ->> 'url' url,
	d.data,
	s.id source_id,
	s.name source_name,
	s.url source_url,
	d.created_at,
	d.updated_at,
	d.location
FROM weaver.dataset d
JOIN weaver.data_source s
  ON d.source_id = s.id;


CREATE OR REPLACE VIEW weaver_api.data_unified_loose AS
SELECT
	dm.id id,
	dd.dataset_id,
	dm.model_name,
	'datum' type,
	dm.data ->> 'url' url,
	dm.data,
	s.id source_id,
	s.name source_name,
	s.url source_url,
	dm.created_at,
	dm.updated_at,
	d.location
FROM weaver.datum dm
JOIN weaver.dataset_data dd
  ON dm.id = dd.datum_id
JOIN weaver.dataset d
  ON dd.dataset_id = d.id
JOIN weaver.data_source s
  ON s.id = d.source_id
UNION ALL
SELECT
	d.id,
	d.id dataset_id,
	d.model_name,
	'dataset' type,
	d.data ->> 'url' url,
	d.data,
	s.id source_id,
	s.name source_name,
	s.url source_url,
	d.created_at,
	d.updated_at,
	d.location
FROM weaver.dataset d
JOIN weaver.data_source s
  ON d.source_id = s.id;

CREATE OR REPLACE VIEW weaver_api.data AS
SELECT
	id,
	d.dataset_id,
	model_name,
	data,
	s.source_name,
	coalesce(s.url, s.source_url) url,
	short_pub_info pub
FROM weaver_api.data_unified_strict d
JOIN weaver_api.dataset_source_index s
  ON d.dataset_id = s.dataset_id;

CREATE OR REPLACE VIEW weaver_api.model AS
SELECT * FROM weaver.model;

-- Reload the schema cache if needed
NOTIFY pgrst, 'reload schema';
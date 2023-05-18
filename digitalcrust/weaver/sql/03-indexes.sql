CREATE MATERIALIZED VIEW IF NOT EXISTS weaver_api.dataset_source_index AS
SELECT
	dd.dataset_id,
	dm.data pub_info,
	CASE
    WHEN dm.data IS NULL
    THEN null
    WHEN dm.data ->> 'doi' IS NULL
    THEN concat( dm.data ->> 'author', ', ', (dm.data ->> 'year')::text)
    ELSE dm.data ->> 'doi'
  END short_pub_info,
	s.id source_id,
	s.name source_name,
	s.url source_url
FROM weaver.datum dm
JOIN weaver.dataset_data dd
  ON dd.datum_id = dm.id
JOIN weaver.dataset d
  ON d.id = dd.dataset_id
JOIN weaver.data_source s
  ON s.id = d.source_id
WHERE dm.model_name = 'Publication'
  AND dm.data ->> 'doi' IS NULL;
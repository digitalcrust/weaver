-- Iterate through samples and link them weaver datasets
WITH sample_basic_info AS (
  SELECT
    id,
    uuid_generate_v4() uuid,
    sample_name,
    geometry
  FROM
    macrostrat.measuremeta m
  WHERE
    m.id NOT IN (SELECT measuremeta_id FROM weaver_macrostrat.measuremeta_dataset)
), with_schema AS (
  SELECT
    *,
    jsonb_build_object(
      'id', uuid,
      'name', sample_name,
      'location',
      ST_AsGeoJSON(geometry)::jsonb
    ) data
  FROM sample_basic_info
),
validated_data AS (
  SELECT * FROM with_schema
  WHERE weaver.validate_schema('Sample', data)
),
insert_data AS (
  INSERT INTO
    weaver.dataset(id, data, location, model_name)
  SELECT
    uuid,
    data,
    ST_SetSRID(geometry, 4326),
    'Sample'
  FROM
    validated_data
)
INSERT INTO
  weaver_macrostrat.measuremeta_dataset (measuremeta_id, dataset_id)
SELECT
  id,
  uuid
FROM
  validated_data;

-- available at https://next.macrostrat.org/psql_api/

CREATE SCHEMA IF NOT EXISTS weaver_api;

CREATE OR REPLACE VIEW weaver_api.dataset AS
SELECT
  d.id,
  d.location,
  s.name,
  s.url,
  json_agg(dm.data) data,
  array_agg(dm.model_name) models,
  array_agg(dm.id) datum_ids
FROM weaver.dataset d
JOIN weaver.data_link dl
  ON dl.dataset_id = d.id
JOIN weaver.data_source s
  ON d.source_id = s.id
JOIN weaver.datum dm
  ON (dl.datum_id = dm.id OR dm.dataset_id = d.id)
GROUP BY d.id, s.name, s.url;

CREATE OR REPLACE VIEW weaver_api.detrital_zircon_dataset AS
SELECT
  id,
  location,
  name,
  url,
  models,
  datum_ids
FROM weaver_api.dataset;

-- 
CREATE OR REPLACE VIEW weaver_api.dataset AS
SELECT
  d.id,
  d.location,
  s.name,
  s.url,
  json_agg(dm.data) data,
  array_agg(dm.model_name) models,
  array_agg(dm.id) datum_ids
FROM weaver.dataset d
JOIN weaver.data_link dl
  ON dl.dataset_id = d.id
JOIN weaver.data_source s
  ON d.source_id = s.id
JOIN weaver.datum dm
  ON (dl.datum_id = dm.id OR dm.dataset_id = d.id)
GROUP BY d.id, s.name, s.url;


/* A function to create vector tiles that doesn't require a separate tile server.
  This could be upgraded to pg_tileserv eventually.
 */
CREATE OR REPLACE FUNCTION weaver_api.detrital_zircon_tile(
  x integer,
  y integer,
  z integer
) RETURNS bytea AS $$
  WITH tile_loc AS (
    SELECT tile_utils.envelope(x, y, z) envelope 
  ),
  -- features in tile envelope
  tile_features AS (
    SELECT
      id,
	    models,
      ST_Transform(location, 3857) geometry
    FROM weaver_api.detrital_zircon_dataset
    WHERE ST_Intersects(location, ST_Transform((SELECT envelope FROM tile_loc), 4326))
  ),
  mvt_features AS (
    SELECT
      id,
      models,
      -- Get the geometry in vector-tile integer coordinates
      ST_AsMVTGeom(geometry, (SELECT envelope FROM tile_loc)) geometry
    FROM tile_features
  ),
  snapped_features AS (
    SELECT
      id,
      models,
      geometry,
      -- Snapping to a grid allows us to efficiently group nearby points together
      -- We could also use the ST_ClusterDBSCAN function for a less naive implementation
      ST_SnapToGrid(geometry, 8, 8) snapped_geometry
      --ST_ClusterDBSCAN(geometry, 16, 2) OVER () cluster_id
    FROM mvt_features
  ),
  grouped_features AS (
    SELECT
      -- Get cluster expansion zoom level
      tile_utils.cluster_expansion_zoom(ST_Collect(geometry), z) expansion_zoom,
      snapped_geometry geometry,
      count(*) n,
      CASE WHEN count(*) < 10 THEN
        string_agg(id::text, ',')
      ELSE
        null
      END id,
      CASE WHEN count(*) < 10 THEN
        string_agg(array_to_string(models, ','), ',')
      ELSE
        null
      END AS models
    FROM snapped_features
    GROUP BY snapped_geometry
    -- WHERE cluster_id IS NOT NULL
    -- GROUP BY cluster_id
    -- UNION ALL
    -- SELECT
    --   null,
    --   geometry,
    --   1 n,
    --   id::text,
    --   name,
    --   material
    -- FROM snapped_features
    --WHERE cluster_id IS NULL
  )
  SELECT ST_AsMVT(grouped_features)
  FROM grouped_features;
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE FUNCTION weaver_api.weaver_tile(
  x integer,
  y integer,
  z integer,
  query_params json
) RETURNS bytea AS $$
  WITH tile_loc AS (
    SELECT tile_utils.envelope(x, y, z) envelope 
  ),
  -- features in tile envelope
  tile_features AS (
    SELECT
      ST_Transform(location, 3857) geometry,
	  	d.id,
		d.model_name,
		s.name source_name
    FROM weaver.dataset d
 	JOIN weaver.data_source s
	  ON d.source_id = s.id
    WHERE ST_Intersects(location, ST_Transform((SELECT envelope FROM tile_loc), 4326))

  ),
  mvt_features AS (
    SELECT
      id,
      model_name,
      source_name,
      -- Get the geometry in vector-tile integer coordinates
      ST_AsMVTGeom(geometry, (SELECT envelope FROM tile_loc)) geometry
    FROM tile_features
  ),
  snapped_features AS (
    SELECT
      id,
      model_name,
      source_name,
      geometry,
      -- Snapping to a grid allows us to efficiently group nearby points together
      -- We could also use the ST_ClusterDBSCAN function for a less naive implementation
      ST_SnapToGrid(geometry, 16, 16) snapped_geometry
      --ST_ClusterDBSCAN(geometry, 16, 2) OVER () cluster_id
    FROM mvt_features
  ),
  grouped_features AS (
    SELECT
      -- Get cluster expansion zoom level
      tile_utils.cluster_expansion_zoom(ST_Collect(geometry), 8) expansion_zoom,
      snapped_geometry geometry,
      count(*) n,
      CASE WHEN count(*) < 2 THEN
        string_agg(id::text, ',')
      ELSE
        null
      END id,
      CASE WHEN count(*) < 2 THEN
        string_agg(model_name, ',')
      ELSE
        null
      END AS model_name
    FROM snapped_features
    GROUP BY snapped_geometry
    -- WHERE cluster_id IS NOT NULL
    -- GROUP BY cluster_id
    -- UNION ALL
    -- SELECT
    --   null,
    --   geometry,
    --   1 n,
    --   id::text,
    --   name,
    --   material
    -- FROM snapped_features
    --WHERE cluster_id IS NULL
  )
  SELECT ST_AsMVT(grouped_features)
  FROM grouped_features;
$$ LANGUAGE sql IMMUTABLE;

NOTIFY pgrst, 'reload schema';
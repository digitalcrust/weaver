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
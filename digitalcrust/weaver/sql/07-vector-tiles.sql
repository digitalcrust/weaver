


CREATE OR REPLACE FUNCTION weaver_api.weaver_tile_meta(
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
      ST_AsMVTGeom(geometry, (SELECT envelope FROM tile_loc)) geom_downscaled
    FROM tile_features
  ),
  grouped_features AS (
    SELECT
      -- Get cluster expansion zoom level
      tile_utils.cluster_expansion_zoom(ST_Collect(geom_downscaled), 16) expansion_zoom,
      geom_downscaled geometry,
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
    FROM mvt_features
    GROUP BY geom_downscaled
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
DECLARE
  tile bytea;
  _model_name text;
  _envelope geometry;
BEGIN
  _model_name := query_params ->> 'model_name';
  _envelope := tile_utils.envelope(x, y, z);

  IF _model_name IS NULL THEN
    RETURN weaver_api.weaver_tile_meta(x, y, z, query_params);
  END IF;

  WITH tile_features AS (
    SELECT
      ST_Transform(location, 3857) geometry,
	  	dm.id,
      dm.model_name
    FROM weaver_api.data_unified_strict dm
    WHERE ST_Intersects(location, ST_Transform(_envelope, 4326))
      AND model_name = _model_name
  ),
  mvt_features AS (
    SELECT
      id,
      -- Get the geometry in vector-tile integer coordinates
      ST_AsMVTGeom(ST_SnapToGrid(geometry, 16, 16), _envelope) geom_downscaled
    FROM tile_features
  ),
  grouped_features AS (
    SELECT
      -- Get cluster expansion zoom level
      tile_utils.cluster_expansion_zoom(ST_Collect(geom_downscaled), 16) expansion_zoom,
      geom_downscaled geometry,
      count(*) n,
      CASE WHEN count(*) < 2 THEN
        string_agg(id::text, ',')
      ELSE
        null
      END id
    FROM mvt_features
    GROUP BY geom_downscaled
  )
  SELECT ST_AsMVT(gg)
  FROM grouped_features gg
  INTO tile;

  RETURN tile;
END
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION weaver_api.weaver_nearby_data(
  x float,
  y float,
  query_params json
)
RETURNS record AS $$
DECLARE
  _model_name text;
  _zoom_level integer;
  _point geometry;
  _buffer_size float;
  _envelope geometry;
  _per_page integer;
BEGIN
  _model_name := query_params ->> 'model_name';
  _per_page := query_params ->> 'per_page';
  _point := ST_SetSRID(ST_MakePoint(x, y), 4326);
  _zoom_level := query_params ->> 'z';
  _buffer_size := tile_utils.tile_width(_zoom_level)/256;
  _envelope := ST_Transform(ST_Buffer(ST_Transform(_point, 3857), _buffer_size), 4326);

  RETURN
    *
  FROM weaver_api.data_unified_strict dm
  WHERE ST_Intersects(location, _envelope)
    AND model_name = _model_name
  ORDER BY id
  LIMIT _per_page;
END
$$ LANGUAGE plpgsql IMMUTABLE;



GRANT SELECT ON ALL TABLES IN SCHEMA weaver_api TO web_anon;
-- Reload the schema cache if needed
NOTIFY pgrst, 'reload schema';
/**
Some materialized views written in 2019 that extract detrital-zircon
data in a bit more of a legible format.
**/

CREATE MATERIALIZED VIEW weaver_macrostrat.detrital_zircon_grain AS
WITH a AS (
SELECT
 *
FROM macrostrat.measures m
JOIN macrostrat.measurements meas
  ON meas.id = m.measurement_id
WHERE meas.measurement_type = 'geochronological'
  AND measure_phase = 'zircon'
  AND units = 'Ma'
ORDER BY measuremeta_id
),
b AS (
SELECT
	measuremeta_id,
	sample_no,
	measurement_id,
	measure_value::numeric age_238U_206Pb,
	v_error::numeric err_238U_206Pb,
	null::numeric age_235U_207Pb,
	null::numeric err_235U_207Pb,
	null::numeric age_207Pb_206Pb,
	null::numeric err_207Pb_206Pb
FROM a WHERE measurement = '238U-206Pb'
UNION ALL
SELECT
	measuremeta_id ,
	sample_no,
	measurement_id,
	null::numeric age_238U_206Pb,
	null::numeric err_238U_206Pb,
	measure_value::numeric age_235U_207Pb,
	v_error::numeric err_235U_207Pb,
	null::numeric age_207Pb_206Pb,
	null::numeric err_207Pb_206Pb
FROM a
WHERE measurement = '235U-207Pb'
UNION ALL
SELECT
	measuremeta_id,
	sample_no,
	measurement_id,
	null::numeric age_238U_206Pb,
	null::numeric err_238U_206Pb,
	null::numeric age_235U_207Pb,
	null::numeric err_235U_207Pb,
	measure_value::numeric age_207Pb_206Pb,
	v_error::numeric err_207Pb_206Pb
FROM a
WHERE measurement = '207Pb-206Pb'
),
c AS (
SELECT
	measuremeta_id,
	sample_no,
	max(age_238U_206Pb) age_238U_206Pb,
	max(err_238U_206Pb) err_238U_206Pb,
	max(age_235U_207Pb) age_235U_207Pb,
	max(err_235U_207Pb) err_235U_207Pb,
  max(age_207Pb_206Pb) age_207Pb_206Pb,
	max(err_207Pb_206Pb) err_207Pb_206Pb
FROM b
GROUP BY measuremeta_id, sample_no
),
age_concordance AS (
SELECT *,
-- Concordance is a percentage value
-- Guard against division by zero
CASE age_207pb_206pb
WHEN 0
THEN null
ELSE
age_238u_206pb/age_207pb_206pb*100
END concordance
FROM c
)
SELECT *
FROM age_concordance dz;

CREATE MATERIALIZED VIEW weaver_macrostrat.detrital_zircon_sample AS
SELECT
  id measuremeta_id,
  sample_name,
  ST_SetSRID(ST_MakePoint(lng,lat), 4326) geometry,
  sample_geo_unit,
  sample_descrip,
  lith_id,
  lith_att_id,
  early_id,
  late_id
FROM macrostrat.measuremeta mm
WHERE mm.id IN (
  SELECT DISTINCT
    measuremeta_id
  FROM weaver_macrostrat.detrital_zircon_grain g
);
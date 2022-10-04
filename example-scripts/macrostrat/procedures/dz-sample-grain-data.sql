SELECT
  *
FROM
  weaver_macrostrat.detrital_zircon_grain
WHERE
  measuremeta_id = :measuremeta_id
AND concordance is not null
/** Get concordant grains that haven't been tracked by weaver */
SELECT
  DISTINCT s.measuremeta_id,
  md.dataset_id
FROM
  weaver_macrostrat.detrital_zircon_sample s
  JOIN weaver_macrostrat.detrital_zircon_grain g ON s.measuremeta_id = g.measuremeta_id
  JOIN weaver_macrostrat.measuremeta_dataset md ON s.measuremeta_id = md.measuremeta_id
WHERE
  g.concordance BETWEEN 80 AND 110
  AND NOT weaver.has_data(md.dataset_id, 'AgeSpectrum');
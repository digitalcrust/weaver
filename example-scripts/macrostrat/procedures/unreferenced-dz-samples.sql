SELECT
  measuremeta_id,
  md.dataset_id
FROM
  weaver_macrostrat.detrital_zircon_sample s
JOIN weaver_macrostrat.measuremeta_dataset md USING (measuremeta_id)
WHERE
  md.dataset_id NOT IN (
    SELECT
      dataset_id
    FROM
      weaver.datum
    WHERE
      model_name = 'AgeSpectrum'
  )
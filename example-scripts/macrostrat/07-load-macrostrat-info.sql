WITH a AS (
  SELECT
    jsonb_build_object(
      'measuremeta_id',
      m.id,
      'ref_id',
      m.ref_id,
      'url',
      'https://macrostrat.org/api/v2/measurements?measuremeta_id=' || m.id :: text
    ) data,
    md.dataset_id
  FROM
    macrostrat.measuremeta m
    JOIN weaver_macrostrat.measuremeta_dataset md ON m.id = md.measuremeta_id
    JOIN weaver.dataset d ON md.dataset_id = d.id
  WHERE NOT weaver.has_data(md.dataset_id, 'MacrostratMeasure')
)
SELECT weaver.add_datum(dataset_id, 'MacrostratMeasure', data)
FROM a;
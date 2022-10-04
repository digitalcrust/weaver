CREATE SCHEMA IF NOT EXISTS weaver_macrostrat;

CREATE TABLE IF NOT EXISTS weaver_macrostrat.measuremeta_dataset (
  measuremeta_id integer NOT NULL REFERENCES macrostrat.measuremeta(id) ON DELETE CASCADE,
  dataset_id uuid NOT NULL REFERENCES weaver.dataset(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS macrostrat_measuremeta_id_idx ON macrostrat.measuremeta(id);
CREATE INDEX IF NOT EXISTS measuremeta_dataset_measuremeta_id_idx ON weaver_macrostrat.measuremeta_dataset(measuremeta_id);
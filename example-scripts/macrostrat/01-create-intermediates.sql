CREATE SCHEMA IF NOT EXISTS weaver_macrostrat;

CREATE TABLE IF NOT EXISTS weaver_macrostrat.measuremeta_dataset (
  measuremeta_id integer NOT NULL REFERENCES macrostrat.measuremeta(id) ON DELETE CASCADE,
  dataset_id uuid NOT NULL REFERENCES weaver.dataset(id) ON DELETE CASCADE
);
CREATE SCHEMA IF NOT EXISTS weaver;

CREATE TABLE IF NOT EXISTS weaver.data_source (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    name text UNIQUE NOT NULL,
    url text UNIQUE NOT NULL,
    last_fetched_at timestamp with time zone,
    last_online_at timestamp with time zone,
    created_at timestamp WITH time zone NOT NULL DEFAULT NOW(),
    updated_at timestamp WITH time zone NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS weaver.model (
    name text PRIMARY KEY,
    is_meta boolean NOT NULL,
    is_data boolean NOT NULL,
    is_root boolean NOT NULL,
    definition jsonb NOT NULL
);

CREATE TABLE IF NOT EXISTS weaver.dataset (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id uuid REFERENCES weaver.data_source(id),
    model_name text NOT NULL REFERENCES weaver.model(name),
    data jsonb NOT NULL, 
    location geometry(Geometry, 4326),
    location_precision numeric,
    created_at timestamp WITH time zone NOT NULL DEFAULT NOW(),
    updated_at timestamp WITH time zone NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS weaver.datum (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    dataset_id uuid REFERENCES weaver.dataset(id),
    model_name text NOT NULL REFERENCES weaver.model(name),
    data jsonb NOT NULL,
    created_at timestamp WITH time zone NOT NULL DEFAULT NOW(),
    updated_at timestamp WITH time zone NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS weaver.data_link (
    dataset_id uuid NOT NULL REFERENCES weaver.dataset(id),
    datum_id uuid NOT NULL REFERENCES weaver.datum(id),
    created_at timestamp WITH time zone NOT NULL DEFAULT NOW(),
    updated_at timestamp WITH time zone NOT NULL DEFAULT NOW(),
    PRIMARY KEY (dataset_id, datum_id)
);

CREATE INDEX IF NOT EXISTS weaver_data_link_dataset_id_idx ON weaver.data_link (dataset_id);
CREATE INDEX IF NOT EXISTS weaver_data_link_datum_id_idx ON weaver.data_link (datum_id);

-- Delete data that aren't referenced by any dataset
DELETE FROM weaver.datum
WHERE dataset_id IS NULL
  AND id IN (
    SELECT id FROM weaver.datum
    EXCEPT
    SELECT datum_id FROM weaver.data_link
);

CREATE MATERIALIZED VIEW IF NOT EXISTS weaver.dataset_data AS
SELECT
    coalesce(dl.dataset_id, d.dataset_id) dataset_id,
    d.id datum_id,
    d.model_name
FROM weaver.datum d
LEFT JOIN weaver.data_link dl ON d.id = dl.datum_id;

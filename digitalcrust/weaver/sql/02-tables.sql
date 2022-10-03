CREATE SCHEMA IF NOT EXISTS weaver;

CREATE TABLE IF NOT EXISTS weaver.data_source (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    url text NOT NULL,
    data jsonb NOT NULL,
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
    dataset_id uuid NOT NULL REFERENCES weaver.dataset(id),
    model_name text NOT NULL REFERENCES weaver.model(name),
    data jsonb NOT NULL,
    created_at timestamp WITH time zone NOT NULL DEFAULT NOW(),
    updated_at timestamp WITH time zone NOT NULL DEFAULT NOW()
);
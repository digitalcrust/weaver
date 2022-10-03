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

CREATE TABLE IF NOT EXISTS weaver.dataset (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id uuid NOT NULL REFERENCES weaver.data_source(id),
    model_name text NOT NULL,
    model_data jsonb NOT NULL,
    geometry geometry(Geometry, 4326),
    created_at timestamp WITH time zone NOT NULL DEFAULT NOW(),
    updated_at timestamp WITH time zone NOT NULL DEFAULT NOW()
);
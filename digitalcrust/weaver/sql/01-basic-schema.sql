CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

/*
 Drop extra schemas and extensions created by PostGIS,
 because they interfere with generation of migrations
 */
DROP EXTENSION IF EXISTS "postgis_tiger_geocoder" CASCADE;
DROP EXTENSION IF EXISTS "postgis_topology" CASCADE;
DROP EXTENSION IF EXISTS "fuzzystrmatch";
DROP SCHEMA IF EXISTS "tiger";
DROP SCHEMA IF EXISTS "tiger_data";
DROP SCHEMA IF EXISTS "topology";
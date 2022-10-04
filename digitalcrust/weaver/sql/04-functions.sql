-- Validate data against a schema
CREATE OR REPLACE FUNCTION weaver.validate_schema(_name text, _data jsonb)
RETURNS boolean AS $$
DECLARE
    _schema jsonb;
BEGIN
  SELECT definition INTO _schema FROM weaver.model WHERE name = _name;
  IF _schema IS NULL THEN
    RAISE EXCEPTION 'Model % does not exist', _name;
  END IF;

  RETURN validate_json_schema(_schema, _data);
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION weaver.add_datum(_dataset_id uuid, _schema text, _data jsonb)
RETURNS uuid AS $$
DECLARE
    _datum_id uuid;
BEGIN
  IF NOT weaver.validate_schema(_schema, _data) THEN
    RAISE EXCEPTION 'Invalid data % for schema %', _data, _schema;
  END IF;
  INSERT INTO
    weaver.datum (dataset_id, model_name, data)
  SELECT _dataset_id, _schema, _data
  RETURNING id INTO _datum_id;
  RETURN _datum_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION weaver.get_data(_dataset_id uuid, _schema text) RETURNS jsonb AS $$
SELECT jsonb_agg(data) data
FROM weaver.datum d
LEFT JOIN weaver.data_link dl ON d.id = dl.datum_id
WHERE
  (
    d.dataset_id = _dataset_id
    OR dl.dataset_id = _dataset_id
  )
  AND model_name = _schema
GROUP BY model_name;
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION weaver.has_data(_dataset_id uuid, _schema text) RETURNS boolean AS $$
  SELECT _dataset_id IN (
  SELECT
    coalesce(dl.dataset_id, d.dataset_id)
  FROM weaver.datum d
  LEFT JOIN weaver.data_link dl
    ON d.id = dl.datum_id
  ) AS q;
$$ LANGUAGE SQL IMMUTABLE;
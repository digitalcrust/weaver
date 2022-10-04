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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION weaver.add_datum(_dataset_id uuid, _schema text, _data jsonb)
RETURNS text AS $$
BEGIN
  IF NOT weaver.validate_schema(_schema, _data) THEN
    RAISE EXCEPTION 'Invalid data';
  END IF;
  INSERT INTO
    weaver.datum (dataset_id, model_name, data)
  SELECT _dataset_id, _schema, _data
  RETURNING id;
END;
$$ LANGUAGE plpgsql;
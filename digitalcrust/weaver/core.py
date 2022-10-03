from macrostrat.database import Database
from os import environ
from rich import print
from json import dumps
from digitalcrust.weaver.schemas.base import MetaModel, DataModel, WeaverModel
from .schemas.dataset import Dataset
from typing import List


def register_schemas(*schemas: List[WeaverModel]):
    db_url = environ.get("WEAVER_DATABASE_URL")

    print(f"[bold]Registering schemas in database [cyan]{db_url}")

    # Convert schemas to JSON schema and store in database
    db = Database(db_url)

    # convert pydantic schemas to JSON schema
    for schema in schemas:
        name = schema.__name__
        print(f"[bold]Registering schema [cyan]{name}")
        schema_json = schema.schema()
        schema_json["$schema"] = "http://json-schema.org/draft-07/schema#"
        schema_json["$id"] = f"weaver.{name}"
        # Insert into database

        db.session.execute(
            """INSERT INTO weaver.model (name, definition, is_meta, is_data, is_root)
            VALUES (:name, :def, :is_meta, :is_data, :is_root)
            ON CONFLICT (name) DO UPDATE SET
                definition = :def,
                is_meta = :is_meta,
                is_data = :is_data,
                is_root = :is_root
            """,
            {
                "name": name,
                "def": dumps(schema_json),
                "is_meta": issubclass(schema, MetaModel),
                "is_data": issubclass(schema, DataModel),
                "is_root": issubclass(schema, Dataset),
            },
        )
        db.session.commit()

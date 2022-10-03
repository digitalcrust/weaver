from typer import Typer, echo
from macrostrat.database import Database
from macrostrat.database.utils import run_sql
from pathlib import Path
from os import environ
from dotenv import load_dotenv
from rich import print
from json import dumps
from digitalcrust.weaver.schemas.base import MetaModel

from digitalcrust.weaver.schemas.metadata import ContributionType

from .schemas.base import MetaModel, DataModel
from .schemas.dataset import Dataset, Sample
from .schemas.metadata import Contribution, Researcher, Publication, Organization


app = Typer(no_args_is_help=True)

load_dotenv()


@app.command(name="create-tables", help="Create tables in the database")
def create_models(drop: bool = False):
    db_url = environ.get("WEAVER_DATABASE_URL")

    print(f"[bold]Creating tables in database [cyan]{db_url}")

    db = Database(db_url)

    if drop:
        print("[bold]Dropping tables")
        db.engine.execute("DROP SCHEMA IF EXISTS weaver CASCADE")

    sqldir = Path(__file__).parent / "sql"
    files = sorted(sqldir.glob("*.sql"))

    for file in files:
        sql = file.read_text()
        # For now we load the validation schema as its own table
        if file.name == "03-validation.sql":
            sql = sql.replace("@extschema@", "public")
        run_sql(db.engine, sql)


@app.command(name="register-schemas", help="Register schemas in the database")
def register_schemas():
    db_url = environ.get("WEAVER_DATABASE_URL")

    print(f"[bold]Registering schemas in database [cyan]{db_url}")

    # Convert schemas to JSON schema and store in database
    db = Database(db_url)

    schemas = [
        Dataset,
        Sample,
        Contribution,
        Publication,
        Researcher,
        Organization,
    ]
    # convert pydantic schemas to JSON schema
    for schema in schemas:
        name = schema.__name__
        print(f"[bold]Registering schema [cyan]{name}")
        schema = schema.schema()
        schema["$schema"] = "http://json-schema.org/draft-07/schema#"
        schema["$id"] = f"weaver.{name}"
        # Insert into database

        res = db.session.execute(
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
                "def": dumps(schema),
                "is_meta": issubclass(type(schema), MetaModel),
                "is_data": issubclass(type(schema), DataModel),
                "is_root": issubclass(type(schema), Dataset),
            },
        )
        db.session.commit()


@app.command(name="load-data", help="Load data into weaver schemas")
def load_data():
    loader_dir = environ.get("WEAVER_LOADER_DIR")
    if not loader_dir:
        raise ValueError("WEAVER_LOADER_DIR not set")

    db_url = environ.get("WEAVER_DATABASE_URL")

    print(f"[bold]Loading data into database [cyan]{db_url}")

    db = Database(db_url)

    # Load data
    loader_dir = Path(loader_dir)
    files = sorted(loader_dir.glob("*.sql"))
    for file in files:
        print(f"[bold]Loading data from [cyan]{file}")
        if file.suffix == ".sql":
            sql = file.read_text()
            run_sql(db.session, sql)


if __name__ == "__main__":
    app()

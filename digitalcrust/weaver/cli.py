from typer import Typer, echo, Argument
from macrostrat.database import Database
from macrostrat.utils import cmd
from macrostrat.database.utils import run_sql, connection_args

from pathlib import Path
from os import environ
from dotenv import load_dotenv
from rich import print
from json import dumps
from digitalcrust.weaver.schemas.base import MetaModel
import sys

from digitalcrust.weaver.schemas.metadata import ContributionType

from .schemas.base import MetaModel, DataModel
from .schemas.dataset import Dataset, Sample
from .schemas.metadata import (
    Contribution,
    Researcher,
    Publication,
    Organization,
    Compilation,
)
from .core import register_schemas

app = Typer(no_args_is_help=True)



@app.command(name="create-tables", help="Create tables in the database")
def create_models(drop: bool = False):
    db_url = environ.get("WEAVER_DATABASE_URL")
    if not db_url:
        raise ValueError("WEAVER_DATABASE_URL not set")

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
        sql = sql.replace("@extschema@", "public")
        db.run_sql(sql, has_server_binds=False)

    # Reload schema cache
    


@app.command(name="register-schemas", help="Register schemas in the database")
def _register_schemas():
    register_schemas(
        Dataset,
        Sample,
        Contribution,
        Publication,
        Researcher,
        Organization,
        Compilation,
    )


@app.command()
def pipelines():
    print("Available [bold cyan]Weaver[/] pipelines:")
    _pipelines()


def _pipelines():
    for pipeline in Path(environ["WEAVER_LOADER_DIR"]).iterdir():
        if pipeline.is_dir():
            print(f"  [cyan]{pipeline.name}")


@app.command(name="load", help="Load data into weaver schemas")
def load_data(pipeline: str = Argument(default=None)):
    if pipeline is None:
        print(
            "Whoops, no [bold cyan]Weaver[/] pipeline specified. Available pipelines:"
        )
        _pipelines()
        return

    loader_dir = environ.get("WEAVER_LOADER_DIR")
    if not loader_dir:
        raise ValueError("WEAVER_LOADER_DIR not set")
    # Load data
    loader_dir = Path(loader_dir) / pipeline
    if not loader_dir.exists():
        raise ValueError(f"Loader directory {loader_dir} does not exist")

    db_url = environ.get("WEAVER_DATABASE_URL")

    print(f"[bold]Loading data into database [cyan]{db_url}")

    db = Database(db_url)

    files = []
    files.extend(loader_dir.glob("*.sql"))
    files.extend(loader_dir.glob("*.py"))
    files.sort()
    for file in files:
        print(f"[bold]Loading data from [cyan]{file}")
        if file.suffix == ".sql":
            sql = file.read_text()
            run_sql(db.session, sql)
        elif file.suffix == ".py":
            # Execute in file's working directory
            pytext = file.read_text()
            exec(
                pytext, {**globals(), "__file__": str(file.absolute()), "weaver_db": db}
            )


@app.command(
    name="export-dump",
    help="Export a dump file suitable for loading into a new database.",
)
def export_dump():
    db_url = environ.get("WEAVER_DATABASE_URL")
    print(f"[bold]Exporting dump from database [cyan]{db_url}", file=sys.stderr)

    db = Database(db_url)

    command = f"pg_dump -Fc --data-only --schema=weaver {db.engine.url.database}"
    print(f"[cyan]{command}", file=sys.stderr)
    cmd(
        command,
        env={
            **environ,
            "PGPASSWORD": db.engine.url.password,
            "PGUSER": db.engine.url.username,
            "PGHOST": db.engine.url.host,
            "PGPORT": str(db.engine.url.port),
        },
    )


if __name__ == "__main__":
    load_dotenv()
    app()

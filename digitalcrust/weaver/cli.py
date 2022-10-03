from typer import Typer, echo
from macrostrat.database import Database
from pathlib import Path
from os import environ
from dotenv import load_dotenv
from rich import print


app = Typer(no_args_is_help=True)

load_dotenv()


@app.command()
def main():
    pass


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
        db.exec_sql(file)

@app.command(name="register-schemas", help="Register schemas in the database")


if __name__ == "__main__":
    app()

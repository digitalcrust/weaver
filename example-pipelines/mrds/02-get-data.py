import zipfile
import requests
import pandas as P
import numpy as N
from pathlib import Path
from digitalcrust.weaver.schemas.dataset import Dataset
from digitalcrust.weaver.schemas.base import WeaverModel
from digitalcrust.weaver.core import register_schemas
from enum import Enum
from geojson_pydantic import Point
from typing import IO

# Download the MRDS zip file to the data/ directory
url = "https://mrdata.usgs.gov/mrds/mrds-csv.zip"

datadir = Path("data")
datadir.mkdir(exist_ok=True)

mrds = datadir / "mrds-csv.zip"

# https://mrdata.usgs.gov/mrds/about.php
if not mrds.exists():
    print("Downloading MRDS zip file")
    r = requests.get(url)
    with mrds.open("wb") as f:
        f.write(r.content)
else:
    print("MRDS zip file already downloaded")


def chunked_iterrows(f: IO[bytes], chunksize: int = 1000):
    """Iterate over a CSV file in chunks."""
    reader = P.read_csv(f, chunksize=chunksize)
    for chunk in reader:
        yield from chunk.iterrows()


def read_mrds_data(zip_file: Path):
    with zipfile.ZipFile(str(zip_file)) as zf:
        print(zf.namelist())
        # Load the MRDS zip file into a Pandas dataframe, and print the first few rows
        with zf.open("mrds.csv") as f:
            yield from chunked_iterrows(f)


# Schemas


class Score(Enum):
    A = "A"
    B = "B"
    C = "C"
    D = "D"
    E = "E"


class Commodities(WeaverModel):
    primary: list[str]
    secondary: list[str]
    accessory: list[str]
    metallic: bool
    nonmetallic: bool


class History(WeaverModel):
    discovery_year: int | None
    production_years: str | None
    development_status: str | None
    operation_type: str | None


class MineralResourceSite(Dataset):
    """A mineral resource site from MRDS."""

    deposit_id: int
    mrds_id: str | None
    url: str
    area_name: str | None
    minerals: list[str]
    location: Point
    commodities: Commodities
    history: History
    reporter: str | None
    ref: str | None
    score: Score


# Schemas can conform to other ones by inheriting from them or by declaring conformance
# with the `conforms_to` attribute. This is useful for schemas that are not directly loaded
# into the database, but are used to validate other schemas.


register_schemas(MineralResourceSite)


def build_region(row) -> str | None:
    region = ""
    for col in ["county", "region", "state", "country"]:
        if not P.isna(row[col]):
            val = row[col].strip()
            if col == "county":
                val += " County"
            region += val + ", "
    if region == "":
        return None
    return region[:-2]


def build_materials(row) -> list[str]:
    materials = []
    for col in ["ore", "gangue", "other_matl"]:
        if not P.isna(row[col]):
            vals = row[col].split(",")
            materials.extend(vals)
    return materials


def build_commodities(val) -> list[str]:
    if P.isna(val):
        return []
    return [v.strip() for v in val.split(",")]


def row_to_schema(row):
    row = row.replace({N.nan: None})
    if row.dep_id is None or row.latitude is None or row.longitude is None:
        return None

    return MineralResourceSite(
        deposit_id=row.dep_id,
        mrds_id=row.mrds_id,
        url=row.url,
        name=row.site_name,
        area_name=build_region(row),
        minerals=build_materials(row),
        location=Point(coordinates=[row.longitude, row.latitude]),
        commodities=Commodities(
            primary=build_commodities(row.commod1),
            secondary=build_commodities(row.commod2),
            accessory=build_commodities(row.commod3),
            metallic=row.com_type in ["M", "B"],
            nonmetallic=row.com_type in ["N", "B"],
        ),
        history=History(
            discovery_year=row.disc_yr,
            production_years=row.prod_yrs,
            development_status=row.dev_stat,
            operation_type=row.oper_type,
        ),
        reporter=row.reporter,
        ref=row.ref,
        score=Score(row.score),
    )


# Delete all existing data
weaver_db.session.execute(
    "DELETE FROM weaver.dataset WHERE model_name = :model",
    dict(model=MineralResourceSite.__name__),
)

weaver_db.session.commit()

source_id = weaver_db.session.execute(
    "SELECT id FROM weaver.data_source WHERE name = 'USGS Mineral Resources Data System'"
).scalar()

failures = 0
skipped = 0
for ix, row in read_mrds_data(mrds):
    model = None
    try:
        model = row_to_schema(row)
        print(model)
    except Exception as e:
        print(e)
        failures += 1
        continue

    if model is None:
        skipped += 1
        continue

    res = weaver_db.session.execute(
        "INSERT INTO weaver.dataset (source_id, model_name, data, location) SELECT :source_id, :model, :data, ST_GeomFromGeoJSON(:location) RETURNING id",
        params=dict(
            source_id=source_id,
            model=MineralResourceSite.__name__,
            data=model.json(),
            location=model.location.json(),
        ),
    ).fetchone()
    weaver_db.session.commit()

print(f"Failed to load {failures} rows")
print(f"Skipped {skipped} incomplete rows")

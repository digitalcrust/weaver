from pathlib import Path
from rich import print
from digitalcrust.weaver.schemas.ext.detrital_zircon import (
    AgeSpectrum,
    SpectrumAge,
    DecaySystem,
    UPbAge,
)
from digitalcrust.weaver import register_schemas


def get_procedure(name):
    return Path(__file__).parent / "procedures" / (name + ".sql")


proc1 = get_procedure("dz-sample-grain-data")


def best_ages(measuremeta_id):
    grains = weaver_db.exec_sql(proc1, dict(measuremeta_id=measuremeta_id))
    for grain in grains:
        # Really loose concordance boundaries
        if grain.concordance is None:
            continue

        if grain.concordance < 80 or grain.concordance > 110:
            continue

        age = UPbAge(
            value=grain.age_238u_206pb,
            error=grain.err_238u_206pb,
            unit="Ma",
            system=DecaySystem._238U_206PB,
        )

        if grain.err_207pb_206pb < grain.err_238u_206pb:
            age = UPbAge(
                value=grain.age_207pb_206pb,
                error=grain.err_207pb_206pb,
                unit="Ma",
                system=DecaySystem._207PB_206PB,
            )

        yield SpectrumAge(best_age=age, concordance=grain.concordance)


proc = get_procedure("unreferenced-dz-samples")

# Register schemas
register_schemas(AgeSpectrum)

all_rows = weaver_db.exec_sql(proc)

for row in all_rows:
    ages = list(best_ages(row.measuremeta_id))

    print(row)

    if len(ages) == 0:
        continue

    # Create a new AgeSpectrum object
    spectrum = AgeSpectrum(ages=ages)

    # Insert the spectrum into the database

    res = weaver_db.session.execute(
        "INSERT INTO weaver.datum (dataset_id, model_name, data) SELECT :dataset, :model, :datum RETURNING id",
        params=dict(
            dataset=row.dataset_id, model=AgeSpectrum.__name__, datum=spectrum.json()
        ),
    ).fetchone()
    print(res)
    weaver_db.session.commit()

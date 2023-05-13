from digitalcrust.weaver.schemas.base import MetaModel
from typing import Optional
from digitalcrust.weaver.core import register_schemas


class MacrostratMeasure(MetaModel):
    measuremeta_id: int
    ref_id: int
    url: str


class Lithology(MetaModel):
    id: int
    name: str
    type: Optional[str] = None


class LithologyComponent(Lithology):
    prop: float


class MacrostratUnit(MetaModel):
    unit_id: int
    column_id: int
    strat_name: str
    liths: list[Lithology | LithologyComponent]


register_schemas(MacrostratMeasure, MacrostratUnit)

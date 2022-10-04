from digitalcrust.weaver.schemas.base import MetaModel
from typing import Optional
from digitalcrust.weaver.core import register_schemas


class MacrostratMeasure(MetaModel):
    measuremeta_id: int
    ref_id: int
    url: str


register_schemas(MacrostratMeasure)

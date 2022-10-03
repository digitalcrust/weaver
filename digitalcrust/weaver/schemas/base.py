from pydantic import BaseModel
from typing import Literal


class WeaverModel(BaseModel):
    ...


class MetaModel(WeaverModel):
    ...


class DataModel(WeaverModel):
    ...

from typing import Optional
from pydantic import BaseModel
from pydantic.types import UUID4

from decimal import Decimal
from typing import List, Union
from geojson_pydantic import Point

from .base import DataModel, MetaModel


class DescModel(BaseModel):
    type: str


class UncertainLocation(BaseModel):
    """A location with an uncertainty radius in meters."""

    location: Point
    uncertainty: Decimal


class Dataset(BaseModel):
    name: str
    id: UUID4
    igsn: Optional[str] = None
    description: Optional[str] = None
    location: Union[Point, UncertainLocation, None] = None
    meta: List[MetaModel] = []
    data: List[DataModel] = []

from typing import Optional
from pydantic.types import UUID4

from decimal import Decimal
from typing import List
from geojson_pydantic.geometries import Point, Geometry

from .base import WeaverModel, DataModel, MetaModel


class UncertainLocation(WeaverModel):
    """A location with an uncertainty radius in meters."""

    location: Point
    uncertainty: Decimal


class Dataset(WeaverModel):
    name: str
    id: UUID4
    description: Optional[str] = None
    location: Geometry
    meta: List[MetaModel] = []
    data: List[DataModel] = []


class Sample(Dataset):
    igsn: Optional[str] = None
    location: Point
    location_precision: Optional[Decimal] = None

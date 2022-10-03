from pydantic import BaseModel

from .metadata import Contribution


class WeaverInstance(BaseModel):
    name: str
    version: str
    url: str
    contribution: Contribution


class DataSource(BaseModel):
    name: str
    url: str

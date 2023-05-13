from typing import Optional
from pydantic import BaseModel
from typing import List, Union
from enum import Enum
from .base import MetaModel


class Researcher(MetaModel):
    name: str
    email: Optional[str] = None
    orcid: Optional[str] = None


class Publication(MetaModel):
    title: str
    author: Union[List[Researcher], List[str], str]
    year: int
    journal: Optional[str] = None
    doi: Optional[str] = None
    volume: Optional[str] = None
    issue: Optional[str] = None
    pages: Optional[str] = None
    publisher: Optional[str] = None


class Organization(MetaModel):
    name: str
    description: Optional[str] = None
    url: Optional[str] = None


class Compilation(MetaModel):
    name: str
    url: Optional[str] = None
    description: Optional[str] = None
    organization: Optional[Organization] = None


class ContributionType(Enum):
    SPONSOR = "sponsor"
    INVESTIGATOR = "investigator"
    AUTHOR = "author"
    EDITOR = "editor"
    COMPILER = "compiler"
    ARCHIVE = "archive"
    INDEXER = "indexer"
    PUBLISHER = "publisher"


class Contribution(MetaModel):
    """A contribution to the data ecosystem."""

    contributor: Union[Researcher, Organization]
    type: ContributionType
    details: Optional[str] = None


## Links between schemas
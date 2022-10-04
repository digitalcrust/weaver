from enum import Enum
from decimal import Decimal
from typing import List, Optional

from ..base import DataModel


class NumericDatum(DataModel):
    value: Decimal
    error: Optional[Decimal] = None
    unit: str


class Age(NumericDatum):
    unit = "Ma"


class DecaySystem(str, Enum):
    _235U_207PB = "235U_207Pb"
    _238U_206PB = "238U_206Pb"
    _207PB_206PB = "207Pb_206Pb"
    _232TH_208PB = "232Th_208Pb"


class UPbAge(Age):
    system: DecaySystem


class SpectrumAge(DataModel):
    best_age: UPbAge
    concordance: Decimal


class AgeSpectrum(DataModel):
    ages: List[SpectrumAge]


class ConcordiaAge(DataModel):
    age206Pb_238U: Age
    age207Pb_235U: Age
    age206Pb_207Pb: Age

    # We should have a set of transformers
    def calc_best_age(self) -> SpectrumAge:
        # We should do an actual conconrdance calculation here
        return SpectrumAge(
            best_age=self.age206Pb_238U,
            concordance=self.age206Pb_238U.value / self.age206Pb_207Pb.value,
        )


class ConcordiaSpectrum(DataModel):
    ages: List[ConcordiaAge]

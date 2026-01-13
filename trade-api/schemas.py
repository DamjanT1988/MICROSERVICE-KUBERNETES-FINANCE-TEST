from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class Side(str, Enum):
    BUY = "BUY"
    SELL = "SELL"


class TradeCreate(BaseModel):
    instrument: str = Field(..., min_length=1, max_length=32, examples=["AAPL"])
    side: Side
    quantity: int = Field(..., gt=0, examples=[10])
    price: float = Field(..., gt=0, examples=[170.0])


class TradeOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    instrument: str
    side: Side
    quantity: int
    price: float
    traded_at: datetime
    processed: bool


class PositionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    instrument: str
    net_quantity: int
    last_price: float
    exposure: float
    updated_at: datetime


class PnlOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    trade_id: int
    instrument: str
    direction: int
    quantity: int
    trade_price: float
    current_price: float
    pnl: float
    computed_at: datetime



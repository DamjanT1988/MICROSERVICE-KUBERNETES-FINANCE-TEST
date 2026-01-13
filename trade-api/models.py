from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class Trade(Base):
    __tablename__ = "trades"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    instrument: Mapped[str] = mapped_column(String(32), index=True, nullable=False)
    side: Mapped[str] = mapped_column(String(4), nullable=False)  # BUY | SELL
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    price: Mapped[float] = mapped_column(Float, nullable=False)
    traded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    processed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)


class Position(Base):
    """
    Latest position snapshot per instrument (very simplified).

    net_quantity = sum(quantity * direction)
    exposure = abs(net_quantity) * last_price
    """

    __tablename__ = "positions"

    instrument: Mapped[str] = mapped_column(String(32), primary_key=True)
    net_quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    last_price: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    exposure: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class PnlRecord(Base):
    __tablename__ = "pnl_records"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    trade_id: Mapped[int] = mapped_column(Integer, ForeignKey("trades.id"), index=True)
    instrument: Mapped[str] = mapped_column(String(32), index=True, nullable=False)
    direction: Mapped[int] = mapped_column(Integer, nullable=False)  # BUY=+1, SELL=-1
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    trade_price: Mapped[float] = mapped_column(Float, nullable=False)
    current_price: Mapped[float] = mapped_column(Float, nullable=False)
    pnl: Mapped[float] = mapped_column(Float, nullable=False)
    computed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )



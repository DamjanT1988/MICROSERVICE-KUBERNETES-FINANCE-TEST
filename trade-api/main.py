import os

from fastapi import Depends, FastAPI, HTTPException
from redis import Redis
from sqlalchemy import select
from sqlalchemy.orm import Session

from db import engine, get_db
from models import Base, PnlRecord, Position, Trade
from schemas import PnlOut, PositionOut, TradeCreate, TradeOut


APP_NAME = "trade-api"
TRADE_QUEUE_NAME = os.getenv("TRADE_QUEUE_NAME", "trade_queue")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")


def get_redis() -> Redis:
    # decode_responses=True => strings in/out (nice for queue payloads)
    return Redis.from_url(REDIS_URL, decode_responses=True)


app = FastAPI(title="Trade Risk & PnL Engine - Trade API", version="1.0.0")


@app.on_event("startup")
def startup() -> None:
    Base.metadata.create_all(bind=engine)


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok", "service": APP_NAME}


@app.post("/trades", response_model=TradeOut, status_code=201)
def create_trade(payload: TradeCreate, db: Session = Depends(get_db)) -> Trade:
    instrument = payload.instrument.strip().upper()
    if not instrument:
        raise HTTPException(status_code=400, detail="instrument must be non-empty")

    trade = Trade(
        instrument=instrument,
        side=payload.side.value,
        quantity=payload.quantity,
        price=float(payload.price),
        processed=False,
    )
    db.add(trade)
    db.commit()
    db.refresh(trade)

    # enqueue for async processing
    try:
        r = get_redis()
        r.rpush(TRADE_QUEUE_NAME, str(trade.id))
    except Exception as e:
        # Trade is persisted even if the queue is down; worker can be rerun / requeue later.
        raise HTTPException(status_code=503, detail=f"trade stored but queue unavailable: {e}")

    return trade


@app.get("/trades", response_model=list[TradeOut])
def list_trades(db: Session = Depends(get_db)) -> list[Trade]:
    return list(db.scalars(select(Trade).order_by(Trade.id.desc())).all())


@app.get("/positions", response_model=list[PositionOut])
def list_positions(db: Session = Depends(get_db)) -> list[Position]:
    return list(db.scalars(select(Position).order_by(Position.instrument.asc())).all())


@app.get("/pnl", response_model=list[PnlOut])
def list_pnl(db: Session = Depends(get_db)) -> list[PnlRecord]:
    return list(db.scalars(select(PnlRecord).order_by(PnlRecord.id.desc()).limit(200)).all())



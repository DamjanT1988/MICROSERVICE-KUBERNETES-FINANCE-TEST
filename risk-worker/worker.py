import os
import time

import requests
from redis import Redis
from sqlalchemy import select
from sqlalchemy.orm import Session

from db import SessionLocal, engine
from models import Base, PnlRecord, Position, Trade


APP_NAME = "risk-worker"

TRADE_QUEUE_NAME = os.getenv("TRADE_QUEUE_NAME", "trade_queue")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
PRICING_URL = os.getenv("PRICING_URL", "http://localhost:8001")

# lightweight backoff when dependencies are flaky
ERROR_SLEEP_SECONDS = float(os.getenv("ERROR_SLEEP_SECONDS", "1.0"))


def direction_from_side(side: str) -> int:
    s = side.strip().upper()
    if s == "BUY":
        return 1
    if s == "SELL":
        return -1
    raise ValueError(f"unknown side: {side}")


def fetch_price(instrument: str) -> float:
    resp = requests.get(f"{PRICING_URL}/price/{instrument}", timeout=5)
    resp.raise_for_status()
    data = resp.json()
    return float(data["price"])


def process_trade(db: Session, trade_id: int) -> None:
    trade = db.scalar(select(Trade).where(Trade.id == trade_id))
    if trade is None:
        print(f"[{APP_NAME}] trade_id={trade_id} not found, skipping")
        return
    if trade.processed:
        print(f"[{APP_NAME}] trade_id={trade_id} already processed, skipping")
        return

    instrument = trade.instrument.strip().upper()
    direction = direction_from_side(trade.side)
    current_price = fetch_price(instrument)

    # Core finance math (simple & explicit):
    # pnl = (current_price - trade_price) * quantity * direction
    pnl_value = (current_price - float(trade.price)) * int(trade.quantity) * int(direction)

    # Upsert position snapshot
    pos = db.get(Position, instrument)
    if pos is None:
        pos = Position(instrument=instrument, net_quantity=0, last_price=0.0, exposure=0.0)
        db.add(pos)
        db.flush()

    pos.net_quantity = int(pos.net_quantity) + int(trade.quantity) * int(direction)
    pos.last_price = float(current_price)
    pos.exposure = abs(int(pos.net_quantity)) * float(current_price)

    db.add(
        PnlRecord(
            trade_id=trade.id,
            instrument=instrument,
            direction=direction,
            quantity=int(trade.quantity),
            trade_price=float(trade.price),
            current_price=float(current_price),
            pnl=float(pnl_value),
        )
    )

    trade.processed = True


def main() -> None:
    print(f"[{APP_NAME}] starting")
    Base.metadata.create_all(bind=engine)

    r = Redis.from_url(REDIS_URL, decode_responses=True)

    while True:
        try:
            item = r.blpop(TRADE_QUEUE_NAME, timeout=5)
            if item is None:
                continue

            _, trade_id_str = item
            trade_id = int(trade_id_str)

            db = SessionLocal()
            try:
                process_trade(db, trade_id)
                db.commit()
            finally:
                db.close()

        except Exception as e:
            # If processing fails, we put the trade back so it can be retried.
            # This is not exactly-once; it's "at-least-once" (good enough for this portfolio demo).
            print(f"[{APP_NAME}] error: {e}")
            try:
                if "trade_id" in locals():
                    r.rpush(TRADE_QUEUE_NAME, str(trade_id))
            except Exception as re:
                print(f"[{APP_NAME}] failed to requeue: {re}")
            time.sleep(ERROR_SLEEP_SECONDS)


if __name__ == "__main__":
    main()



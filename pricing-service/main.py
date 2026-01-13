import json
import os
from typing import Any

from fastapi import FastAPI, HTTPException


APP_NAME = "pricing-service"

DEFAULT_PRICES: dict[str, float] = {
    "AAPL": 175.20,
    "MSFT": 415.80,
    "TSLA": 248.10,
    "AMZN": 158.30,
    "GOOG": 142.15,
}


def load_price_map() -> dict[str, float]:
    """
    Optional override via env var:
      PRICE_MAP_JSON='{"AAPL": 180.0, "MSFT": 420.0}'
    """
    raw = os.getenv("PRICE_MAP_JSON")
    if not raw:
        return DEFAULT_PRICES

    try:
        parsed: Any = json.loads(raw)
        out: dict[str, float] = {}
        for k, v in parsed.items():
            out[str(k).strip().upper()] = float(v)
        return out
    except Exception:
        return DEFAULT_PRICES


app = FastAPI(title="Trade Risk & PnL Engine - Pricing Service", version="1.0.0")


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok", "service": APP_NAME}


@app.get("/price/{instrument}")
def get_price(instrument: str) -> dict:
    prices = load_price_map()
    key = instrument.strip().upper()
    if not key:
        raise HTTPException(status_code=400, detail="instrument must be non-empty")

    price = prices.get(key)
    if price is None:
        raise HTTPException(status_code=404, detail=f"unknown instrument: {key}")
    return {"instrument": key, "price": price}



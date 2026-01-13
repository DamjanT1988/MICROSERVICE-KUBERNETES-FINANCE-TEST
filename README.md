# Trade Risk & PnL Engine (Kubernetes Portfolio Project)

This repository contains a small microservice-based system that demonstrates **financial trade processing**, **position/PnL calculation**, and **local Kubernetes fundamentals** (Kind or k3d).

> **Portfolio Project**
>
> This project was created by **Damjan** as a portfolio demonstration of backend engineering, financial domain modeling, and Kubernetes fundamentals.
>
> Development was assisted by **Cursor (AI pair programmer)**.

---

## Project Overview

The system accepts simple equity-style trades (BUY/SELL), persists them in PostgreSQL, and asynchronously calculates:

- **Positions** per instrument
- **PnL** per trade (mark-to-market using a mock pricing service)
- **Exposure** (simplified)

The goal is clarity and interview-readiness rather than production completeness.

---

## Architecture Overview

**Services**

- **`trade-api` (FastAPI)**: Accepts trades and exposes read endpoints for trades, positions, and PnL.
- **`pricing-service` (FastAPI)**: Returns mock prices per instrument (no external API calls).
- **`risk-worker` (Python worker)**: Consumes trade IDs from Redis, fetches the trade from Postgres, calls pricing-service, computes position & PnL, and writes results back to Postgres.

**Data Flow**

1. Client submits trade → `trade-api` writes it to Postgres
2. `trade-api` enqueues `trade_id` → Redis
3. `risk-worker` consumes `trade_id` → loads trade from Postgres → fetches price from `pricing-service` → computes position/PnL → writes results to Postgres
4. Client reads `GET /positions` and `GET /pnl` from `trade-api`

---

## Financial Domain Explanation (Simplified)

### Trade
A trade is an execution record such as “BUY 10 AAPL @ 170.00”.

### Position
Position is the net quantity held per instrument:

- BUY = +1 direction
- SELL = -1 direction

Formula per instrument:

\[
position = \sum (quantity \times direction)
\]

### PnL (Profit & Loss)
PnL is mark-to-market using a current price:

\[
pnl = (current\_price - trade\_price)\times quantity \times direction
\]

This mirrors real systems conceptually (trades → positions → valuation), but is intentionally simplified.

---

## Kubernetes Concepts Demonstrated

- **Deployments** for stateless services (`trade-api`, `pricing-service`, `risk-worker`)
- **Services (ClusterIP)** for internal discovery
- **ConfigMaps** for non-secret configuration (risk/pricing parameters)
- **Secrets** for DB credentials (example-only)
- **Health checks** (liveness/readiness on HTTP services)
- **Horizontal scaling** (HPA for worker, optional — requires metrics-server)
- **Rolling updates** via Deployment strategy (default)

---

## Repository Structure

```text
trade-risk-pnl-k8s/
├── trade-api/
│   ├── main.py
│   ├── db.py
│   ├── models.py
│   ├── schemas.py
│   ├── requirements.txt
│   └── Dockerfile
├── pricing-service/
│   ├── main.py
│   ├── requirements.txt
│   └── Dockerfile
├── risk-worker/
│   ├── worker.py
│   ├── db.py
│   ├── models.py
│   ├── requirements.txt
│   └── Dockerfile
├── k8s/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secrets.example.yaml
│   ├── postgres.yaml
│   ├── redis.yaml
│   ├── trade-api.yaml
│   ├── pricing.yaml
│   ├── risk-worker.yaml
│   ├── hpa-risk-worker.yaml
│   └── ingress.yaml
└── README.md
```

---

## Local Setup (Kind or k3d)

### Prerequisites

- Docker
- kubectl
- Either Kind **or** k3d

You also need a way to build container images locally (Docker).

---

### One-command scripts (recommended)

This repo includes a `scripts/` folder with one-command workflows for **up** (create cluster + build images + load/import + deploy) and **down** (delete cluster).

**Windows PowerShell**

```powershell
.\scripts\kind-up.ps1
# or
.\scripts\k3d-up.ps1
```

**macOS/Linux (bash)**

```bash
chmod +x ./scripts/*.sh
./scripts/kind-up.sh
# or
./scripts/k3d-up.sh
```

To tear down:

```powershell
.\scripts\kind-down.ps1
# or
.\scripts\k3d-down.ps1
```

```bash
./scripts/kind-down.sh
# or
./scripts/k3d-down.sh
```

After the script finishes, port-forward the API:

```bash
kubectl -n trade-risk-pnl port-forward svc/trade-api 8000:8000
```

### Troubleshooting (Windows + Kind)

If `.\scripts\kind-up.ps1` fails with errors like **“kubelet is not healthy”** during cluster creation:

- **Docker Desktop must be in Linux containers mode** (Kind runs Kubernetes-in-Docker on Linux).
- **Enable WSL2 backend** in Docker Desktop (recommended).
- **Increase Docker resources** (CPU/RAM) and try again.
- **Fallback**: use k3d (often more forgiving on Windows):

```powershell
.\scripts\k3d-up.ps1
```

You can also pin the Kind node image (if a specific K8s version is problematic):

```powershell
$env:KIND_NODE_IMAGE="kindest/node:v1.34.2"
.\scripts\kind-up.ps1
```

---

### Option A: Kind

1) Create a cluster:

```bash
kind create cluster --name trade-risk-pnl
```

2) Build images:

```bash
docker build -t trade-api:local ./trade-api
docker build -t pricing-service:local ./pricing-service
docker build -t risk-worker:local ./risk-worker
```

3) Load images into Kind:

```bash
kind load docker-image trade-api:local --name trade-risk-pnl
kind load docker-image pricing-service:local --name trade-risk-pnl
kind load docker-image risk-worker:local --name trade-risk-pnl
```

4) Apply Kubernetes manifests:

```bash
kubectl apply -f k8s/
kubectl -n trade-risk-pnl get pods
```

5) Port-forward the Trade API:

```bash
kubectl -n trade-risk-pnl port-forward svc/trade-api 8000:8000
```

---

### Option B: k3d

1) Create a cluster:

```bash
k3d cluster create trade-risk-pnl
```

2) Build images:

```bash
docker build -t trade-api:local ./trade-api
docker build -t pricing-service:local ./pricing-service
docker build -t risk-worker:local ./risk-worker
```

3) Import images into the cluster:

```bash
k3d image import trade-api:local -c trade-risk-pnl
k3d image import pricing-service:local -c trade-risk-pnl
k3d image import risk-worker:local -c trade-risk-pnl
```

4) Apply Kubernetes manifests:

```bash
kubectl apply -f k8s/
kubectl -n trade-risk-pnl get pods
```

5) Port-forward:

```bash
kubectl -n trade-risk-pnl port-forward svc/trade-api 8000:8000
```

---

## Example API Usage

### Create a trade

**PowerShell (Windows)**

```powershell
curl.exe -X POST "http://127.0.0.1:8000/trades" `
  -H "Content-Type: application/json" `
  -d "{\"instrument\":\"AAPL\",\"side\":\"BUY\",\"quantity\":10,\"price\":170.0}"
```

**PowerShell (Windows) - recommended (avoids curl quoting issues)**

```powershell
$body = @{
  instrument = "AAPL"
  side       = "BUY"
  quantity   = 10
  price      = 170.0
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8000/trades" -ContentType "application/json" -Body $body
```

**bash**

```bash
curl -X POST "http://127.0.0.1:8000/trades" \
  -H "Content-Type: application/json" \
  -d "{\"instrument\":\"AAPL\",\"side\":\"BUY\",\"quantity\":10,\"price\":170.0}"
```

### List trades

```bash
curl "http://127.0.0.1:8000/trades"
```

### Get positions

```bash
curl "http://127.0.0.1:8000/positions"
```

### Get PnL

```bash
curl "http://127.0.0.1:8000/pnl"
```

> Note: PnL/positions update asynchronously (worker). If you query immediately after `POST /trades`, wait a second and retry.

---

## Scaling & Resilience Tests

### Scale the worker

```bash
kubectl -n trade-risk-pnl scale deploy/risk-worker --replicas=3
kubectl -n trade-risk-pnl get pods -l app=risk-worker
```

### Kill a pod and observe recovery

```bash
kubectl -n trade-risk-pnl delete pod -l app=trade-api --grace-period=0 --force
kubectl -n trade-risk-pnl get pods -l app=trade-api
```

### Optional: HPA

`k8s/hpa-risk-worker.yaml` is included but requires **metrics-server** on your local cluster.

---

## Disclaimer

This is **not** a production system.

- The financial logic is intentionally simplified.
- Authentication/authorization is not implemented.
- Secrets are example-only.
- Observability (metrics/tracing) is minimal.

---

## Future Improvements (Ideas)

- Real market data integration (with caching and rate limits)
- Auth (JWT/OAuth2), role-based access
- Idempotency keys for `POST /trades`
- Metrics (Prometheus), tracing (OpenTelemetry)
- CI/CD pipelines and image scanning



#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-trade-risk-pnl}"
NAMESPACE="${NAMESPACE:-trade-risk-pnl}"

echo "[k3d-up] creating k3d cluster: ${CLUSTER_NAME}"
k3d cluster create "${CLUSTER_NAME}"

echo "[k3d-up] building images"
docker build -t trade-api:local ./trade-api
docker build -t pricing-service:local ./pricing-service
docker build -t risk-worker:local ./risk-worker

echo "[k3d-up] importing images into k3d"
k3d image import trade-api:local -c "${CLUSTER_NAME}"
k3d image import pricing-service:local -c "${CLUSTER_NAME}"
k3d image import risk-worker:local -c "${CLUSTER_NAME}"

echo "[k3d-up] deploying k8s manifests"
# Apply in a deterministic order (avoids directory-walk ordering issues)
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.example.yaml -f k8s/configmap.yaml
kubectl apply -f k8s/postgres.yaml -f k8s/redis.yaml
kubectl apply -f k8s/pricing.yaml -f k8s/trade-api.yaml -f k8s/risk-worker.yaml
# Optional extras
kubectl apply -f k8s/hpa-risk-worker.yaml -f k8s/ingress.yaml

echo "[k3d-up] waiting for pods"
kubectl -n "${NAMESPACE}" rollout status deploy/postgres --timeout=180s
kubectl -n "${NAMESPACE}" rollout status deploy/redis --timeout=180s
kubectl -n "${NAMESPACE}" rollout status deploy/pricing-service --timeout=180s
kubectl -n "${NAMESPACE}" rollout status deploy/trade-api --timeout=180s
kubectl -n "${NAMESPACE}" rollout status deploy/risk-worker --timeout=180s

echo ""
echo "[k3d-up] done."
echo "Port-forward Trade API:"
echo "  kubectl -n ${NAMESPACE} port-forward svc/trade-api 8000:8000"



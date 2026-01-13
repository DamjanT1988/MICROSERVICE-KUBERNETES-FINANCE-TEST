#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-trade-risk-pnl}"
NAMESPACE="${NAMESPACE:-trade-risk-pnl}"

echo "[kind-up] creating kind cluster: ${CLUSTER_NAME}"
kind create cluster --name "${CLUSTER_NAME}"

echo "[kind-up] building images"
docker build -t trade-api:local ./trade-api
docker build -t pricing-service:local ./pricing-service
docker build -t risk-worker:local ./risk-worker

echo "[kind-up] loading images into kind"
kind load docker-image trade-api:local --name "${CLUSTER_NAME}"
kind load docker-image pricing-service:local --name "${CLUSTER_NAME}"
kind load docker-image risk-worker:local --name "${CLUSTER_NAME}"

echo "[kind-up] deploying k8s manifests"
kubectl apply -f k8s/

echo "[kind-up] waiting for pods"
kubectl -n "${NAMESPACE}" rollout status deploy/postgres --timeout=180s
kubectl -n "${NAMESPACE}" rollout status deploy/redis --timeout=180s
kubectl -n "${NAMESPACE}" rollout status deploy/pricing-service --timeout=180s
kubectl -n "${NAMESPACE}" rollout status deploy/trade-api --timeout=180s
kubectl -n "${NAMESPACE}" rollout status deploy/risk-worker --timeout=180s

echo ""
echo "[kind-up] done."
echo "Port-forward Trade API:"
echo "  kubectl -n ${NAMESPACE} port-forward svc/trade-api 8000:8000"



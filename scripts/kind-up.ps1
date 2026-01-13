$ErrorActionPreference = "Stop"

$CLUSTER_NAME = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "trade-risk-pnl" }
$NAMESPACE = if ($env:NAMESPACE) { $env:NAMESPACE } else { "trade-risk-pnl" }

Write-Host "[kind-up] creating kind cluster: $CLUSTER_NAME"
kind create cluster --name $CLUSTER_NAME

Write-Host "[kind-up] building images"
docker build -t trade-api:local ./trade-api
docker build -t pricing-service:local ./pricing-service
docker build -t risk-worker:local ./risk-worker

Write-Host "[kind-up] loading images into kind"
kind load docker-image trade-api:local --name $CLUSTER_NAME
kind load docker-image pricing-service:local --name $CLUSTER_NAME
kind load docker-image risk-worker:local --name $CLUSTER_NAME

Write-Host "[kind-up] deploying k8s manifests"
kubectl apply -f k8s/

Write-Host "[kind-up] waiting for pods"
kubectl -n $NAMESPACE rollout status deploy/postgres --timeout=180s
kubectl -n $NAMESPACE rollout status deploy/redis --timeout=180s
kubectl -n $NAMESPACE rollout status deploy/pricing-service --timeout=180s
kubectl -n $NAMESPACE rollout status deploy/trade-api --timeout=180s
kubectl -n $NAMESPACE rollout status deploy/risk-worker --timeout=180s

Write-Host ""
Write-Host "[kind-up] done."
Write-Host "Port-forward Trade API:"
Write-Host "  kubectl -n $NAMESPACE port-forward svc/trade-api 8000:8000"



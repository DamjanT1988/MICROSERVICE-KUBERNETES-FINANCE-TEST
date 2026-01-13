$ErrorActionPreference = "Stop"

$CLUSTER_NAME = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "trade-risk-pnl" }
$NAMESPACE = if ($env:NAMESPACE) { $env:NAMESPACE } else { "trade-risk-pnl" }

Write-Host "[k3d-up] creating k3d cluster: $CLUSTER_NAME"
k3d cluster create $CLUSTER_NAME

Write-Host "[k3d-up] building images"
docker build -t trade-api:local ./trade-api
docker build -t pricing-service:local ./pricing-service
docker build -t risk-worker:local ./risk-worker

Write-Host "[k3d-up] importing images into k3d"
k3d image import trade-api:local -c $CLUSTER_NAME
k3d image import pricing-service:local -c $CLUSTER_NAME
k3d image import risk-worker:local -c $CLUSTER_NAME

Write-Host "[k3d-up] deploying k8s manifests"
kubectl apply -f k8s/

Write-Host "[k3d-up] waiting for pods"
kubectl -n $NAMESPACE rollout status deploy/postgres --timeout=180s
kubectl -n $NAMESPACE rollout status deploy/redis --timeout=180s
kubectl -n $NAMESPACE rollout status deploy/pricing-service --timeout=180s
kubectl -n $NAMESPACE rollout status deploy/trade-api --timeout=180s
kubectl -n $NAMESPACE rollout status deploy/risk-worker --timeout=180s

Write-Host ""
Write-Host "[k3d-up] done."
Write-Host "Port-forward Trade API:"
Write-Host "  kubectl -n $NAMESPACE port-forward svc/trade-api 8000:8000"



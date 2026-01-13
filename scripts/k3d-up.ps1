$ErrorActionPreference = "Stop"

$CLUSTER_NAME = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "trade-risk-pnl" }
$NAMESPACE = if ($env:NAMESPACE) { $env:NAMESPACE } else { "trade-risk-pnl" }
$KUBE_CONTEXT = "k3d-$CLUSTER_NAME"

function Assert-LastExitCode([string]$Step) {
  if ($LASTEXITCODE -ne 0) {
    throw "$Step failed with exit code $LASTEXITCODE"
  }
}

Write-Host "[k3d-up] creating k3d cluster: $CLUSTER_NAME"
& k3d cluster create $CLUSTER_NAME
Assert-LastExitCode "k3d cluster create"

& kubectl config use-context $KUBE_CONTEXT | Out-Null
Assert-LastExitCode "kubectl config use-context $KUBE_CONTEXT"

Write-Host "[k3d-up] building images"
& docker build -t trade-api:local ./trade-api
Assert-LastExitCode "docker build trade-api"
& docker build -t pricing-service:local ./pricing-service
Assert-LastExitCode "docker build pricing-service"
& docker build -t risk-worker:local ./risk-worker
Assert-LastExitCode "docker build risk-worker"

Write-Host "[k3d-up] importing images into k3d"
& k3d image import trade-api:local -c $CLUSTER_NAME
Assert-LastExitCode "k3d image import trade-api"
& k3d image import pricing-service:local -c $CLUSTER_NAME
Assert-LastExitCode "k3d image import pricing-service"
& k3d image import risk-worker:local -c $CLUSTER_NAME
Assert-LastExitCode "k3d image import risk-worker"

Write-Host "[k3d-up] deploying k8s manifests"
# Apply in a deterministic order (avoids directory-walk ordering issues)
& kubectl --context $KUBE_CONTEXT apply -f k8s/namespace.yaml
Assert-LastExitCode "kubectl apply namespace"

& kubectl --context $KUBE_CONTEXT apply -f k8s/secrets.example.yaml -f k8s/configmap.yaml
Assert-LastExitCode "kubectl apply secrets/configmap"

& kubectl --context $KUBE_CONTEXT apply -f k8s/postgres.yaml -f k8s/redis.yaml
Assert-LastExitCode "kubectl apply postgres/redis"

& kubectl --context $KUBE_CONTEXT apply -f k8s/pricing.yaml -f k8s/trade-api.yaml -f k8s/risk-worker.yaml
Assert-LastExitCode "kubectl apply app deployments"

# Optional extras (safe to create even if controllers aren't installed)
& kubectl --context $KUBE_CONTEXT apply -f k8s/hpa-risk-worker.yaml -f k8s/ingress.yaml
Assert-LastExitCode "kubectl apply optional extras"

Write-Host "[k3d-up] waiting for pods"
& kubectl --context $KUBE_CONTEXT -n $NAMESPACE rollout status deploy/postgres --timeout=180s
Assert-LastExitCode "rollout postgres"
& kubectl --context $KUBE_CONTEXT -n $NAMESPACE rollout status deploy/redis --timeout=180s
Assert-LastExitCode "rollout redis"
& kubectl --context $KUBE_CONTEXT -n $NAMESPACE rollout status deploy/pricing-service --timeout=180s
Assert-LastExitCode "rollout pricing-service"
& kubectl --context $KUBE_CONTEXT -n $NAMESPACE rollout status deploy/trade-api --timeout=180s
Assert-LastExitCode "rollout trade-api"
& kubectl --context $KUBE_CONTEXT -n $NAMESPACE rollout status deploy/risk-worker --timeout=180s
Assert-LastExitCode "rollout risk-worker"

Write-Host ""
Write-Host "[k3d-up] done."
Write-Host "Port-forward Trade API:"
Write-Host "  kubectl -n $NAMESPACE port-forward svc/trade-api 8000:8000"



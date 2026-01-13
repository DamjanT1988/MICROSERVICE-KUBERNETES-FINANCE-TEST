$ErrorActionPreference = "Stop"

$CLUSTER_NAME = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "trade-risk-pnl" }
$NAMESPACE = if ($env:NAMESPACE) { $env:NAMESPACE } else { "trade-risk-pnl" }
$KIND_NODE_IMAGE = if ($env:KIND_NODE_IMAGE) { $env:KIND_NODE_IMAGE } else { "" }
$KUBE_CONTEXT = "kind-$CLUSTER_NAME"

function Assert-LastExitCode([string]$Step) {
  if ($LASTEXITCODE -ne 0) {
    throw "$Step failed with exit code $LASTEXITCODE"
  }
}

Write-Host "[kind-up] creating kind cluster: $CLUSTER_NAME"
$kindArgs = @("create", "cluster", "--name", $CLUSTER_NAME, "--wait", "120s")
if ($KIND_NODE_IMAGE) {
  Write-Host "[kind-up] using node image override: $KIND_NODE_IMAGE"
  $kindArgs += @("--image", $KIND_NODE_IMAGE)
}
& kind @kindArgs
Assert-LastExitCode "kind create cluster"

& kubectl config use-context $KUBE_CONTEXT | Out-Null
Assert-LastExitCode "kubectl config use-context $KUBE_CONTEXT"

Write-Host "[kind-up] building images"
& docker build -t trade-api:local ./trade-api
Assert-LastExitCode "docker build trade-api"
& docker build -t pricing-service:local ./pricing-service
Assert-LastExitCode "docker build pricing-service"
& docker build -t risk-worker:local ./risk-worker
Assert-LastExitCode "docker build risk-worker"

Write-Host "[kind-up] loading images into kind"
& kind load docker-image trade-api:local --name $CLUSTER_NAME
Assert-LastExitCode "kind load trade-api"
& kind load docker-image pricing-service:local --name $CLUSTER_NAME
Assert-LastExitCode "kind load pricing-service"
& kind load docker-image risk-worker:local --name $CLUSTER_NAME
Assert-LastExitCode "kind load risk-worker"

Write-Host "[kind-up] deploying k8s manifests"
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

Write-Host "[kind-up] waiting for pods"
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
Write-Host "[kind-up] done."
Write-Host "Port-forward Trade API:"
Write-Host "  kubectl -n $NAMESPACE port-forward svc/trade-api 8000:8000"



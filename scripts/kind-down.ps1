$ErrorActionPreference = "Stop"

$CLUSTER_NAME = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "trade-risk-pnl" }

Write-Host "[kind-down] deleting kind cluster: $CLUSTER_NAME"
kind delete cluster --name $CLUSTER_NAME



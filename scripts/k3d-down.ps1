$ErrorActionPreference = "Stop"

$CLUSTER_NAME = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "trade-risk-pnl" }

Write-Host "[k3d-down] deleting k3d cluster: $CLUSTER_NAME"
k3d cluster delete $CLUSTER_NAME



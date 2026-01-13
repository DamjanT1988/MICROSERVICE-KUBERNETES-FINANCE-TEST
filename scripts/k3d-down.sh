#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-trade-risk-pnl}"

echo "[k3d-down] deleting k3d cluster: ${CLUSTER_NAME}"
k3d cluster delete "${CLUSTER_NAME}"



#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${NAMESPACE:=ghidrai-api}"
: "${RELEASE:=ghidrai-api}"
: "${VALUES_FILE:=${repo_root}/deploy/values.yaml}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install "${RELEASE}" "${repo_root}/charts/ghidrai-api" \
  --namespace "${NAMESPACE}" \
  -f "${VALUES_FILE}"

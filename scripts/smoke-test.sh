#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${NAMESPACE:=ghidrai-api}"
: "${RELEASE:=ghidrai-api}"

if [[ -f "${repo_root}/deploy/cloudflare.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/deploy/cloudflare.env"
fi

if [[ -z "${HOSTNAME:-}" ]]; then
  echo "HOSTNAME is not set." >&2
  exit 1
fi

kubectl -n "${NAMESPACE}" rollout status deploy/"${RELEASE}" --timeout=10m
kubectl -n "${NAMESPACE}" rollout status deploy/"${RELEASE}"-cloudflared --timeout=10m

internal="$(kubectl -n "${NAMESPACE}" run curl-smoke --rm -i --restart=Never --image=curlimages/curl:8.12.1 -- \
  -fsS "http://${RELEASE}.${NAMESPACE}.svc.cluster.local:8089/api/v1/health")"
external="$(curl -fsS "https://${HOSTNAME}/api/v1/health")"

echo "Internal health:"
echo "${internal}" | jq .
echo "External health:"
echo "${external}" | jq .

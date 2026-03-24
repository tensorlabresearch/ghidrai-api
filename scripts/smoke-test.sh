#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${NAMESPACE:=ghidrai-api}"
: "${RELEASE:=ghidrai-api}"
: "${KEYCLOAK_TOKEN_URL:=}"
: "${KEYCLOAK_CLIENT_ID:=}"
: "${KEYCLOAK_CLIENT_SECRET:=}"
: "${ACCESS_TOKEN:=}"

if [[ -f "${repo_root}/deploy/cloudflare.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/deploy/cloudflare.env"
fi

if [[ -z "${HOSTNAME:-}" ]]; then
  echo "HOSTNAME is not set." >&2
  exit 1
fi

auth_headers=()

if [[ -z "${ACCESS_TOKEN}" && -n "${KEYCLOAK_TOKEN_URL}" && -n "${KEYCLOAK_CLIENT_ID}" && -n "${KEYCLOAK_CLIENT_SECRET}" ]]; then
  ACCESS_TOKEN="$(curl -fsS -X POST "${KEYCLOAK_TOKEN_URL}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode grant_type=client_credentials \
    --data-urlencode client_id="${KEYCLOAK_CLIENT_ID}" \
    --data-urlencode client_secret="${KEYCLOAK_CLIENT_SECRET}" | jq -r '.access_token')"
fi

if [[ -n "${ACCESS_TOKEN}" ]]; then
  auth_headers=(-H "Authorization: Bearer ${ACCESS_TOKEN}")
fi

kubectl -n "${NAMESPACE}" rollout status deploy/"${RELEASE}" --timeout=10m

if kubectl -n "${NAMESPACE}" get deploy/"${RELEASE}"-cloudflared >/dev/null 2>&1; then
  kubectl -n "${NAMESPACE}" rollout status deploy/"${RELEASE}"-cloudflared --timeout=10m
fi

internal="$(kubectl -n "${NAMESPACE}" run curl-smoke --rm -i --restart=Never --image=curlimages/curl:8.12.1 -- \
  -fsS "http://${RELEASE}.${NAMESPACE}.svc.cluster.local:8089/api/v1/health")"
external="$(curl -fsS "${auth_headers[@]}" "https://${HOSTNAME}/api/v1/health")"

echo "Internal health:"
echo "${internal}" | jq .
echo "External health:"
echo "${external}" | jq .

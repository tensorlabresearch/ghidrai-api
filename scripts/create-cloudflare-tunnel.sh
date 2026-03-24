#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${API_BASE:=https://api.cloudflare.com/client/v4}"
: "${TUNNEL_NAME:=ghidrai-api}"
: "${NAMESPACE:=ghidrai-api}"
: "${SERVICE_NAME:=ghidrai-api}"
: "${SERVICE_PORT:=8089}"
: "${SECRET_NAME:=ghidrai-api-tunnel-token}"

if [[ -f "${HOME}/.cloudflared/.env" ]]; then
  # shellcheck disable=SC1091
  source "${HOME}/.cloudflared/.env"
fi

if [[ -f "${repo_root}/deploy/cloudflare.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/deploy/cloudflare.env"
fi

required_vars=(
  CLOUDFLARE_API_TOKEN
  CLOUDFLARE_ACCOUNT_ID
  CLOUDFLARE_ZONE_ID
  HOSTNAME
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "${var_name} is not set." >&2
    exit 1
  fi
done

existing_id="${TUNNEL_ID:-}"

if [[ -z "${existing_id}" ]]; then
  list_json="$(curl -s "${API_BASE}/accounts/${CLOUDFLARE_ACCOUNT_ID}/cfd_tunnel?is_deleted=false" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" || true)"
  existing_id="$(echo "${list_json}" | jq -r --arg name "${TUNNEL_NAME}" 'select(.success == true) | .result[]? | select(.name == $name) | .id' | head -n1)"
fi

if [[ -z "${existing_id}" ]]; then
  create_json="$(curl -fsS "${API_BASE}/accounts/${CLOUDFLARE_ACCOUNT_ID}/cfd_tunnel" \
    --request POST \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$(jq -n --arg name "${TUNNEL_NAME}" '{name:$name,config_src:"cloudflare"}')")"
  tunnel_id="$(echo "${create_json}" | jq -r '.result.id')"
  tunnel_token="$(echo "${create_json}" | jq -r '.result.token')"
else
  tunnel_id="${existing_id}"
  tunnel_token="$(curl -fsS "${API_BASE}/accounts/${CLOUDFLARE_ACCOUNT_ID}/cfd_tunnel/${tunnel_id}/token" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" | jq -r '.result')"
fi

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "${NAMESPACE}" create secret generic "${SECRET_NAME}" \
  --from-literal=token="${tunnel_token}" \
  --dry-run=client -o yaml | kubectl apply -f -

subdomain="${HOSTNAME%%.*}"
tunnel_cname="${tunnel_id}.cfargotunnel.com"
existing_record="$(curl -s "${API_BASE}/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=CNAME&name=${HOSTNAME}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}")"
record_id="$(echo "${existing_record}" | jq -r '.result[0].id // empty')"
dns_payload="$(jq -n \
  --arg name "${subdomain}" \
  --arg content "${tunnel_cname}" \
  '{type:"CNAME",name:$name,content:$content,proxied:true,ttl:1}')"

if [[ -n "${record_id}" ]]; then
  curl -fsS -X PUT "${API_BASE}/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${record_id}" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "${dns_payload}" >/dev/null
else
  curl -fsS -X POST "${API_BASE}/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "${dns_payload}" >/dev/null
fi

origin_service="http://${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local:${SERVICE_PORT}"
config_payload="$(jq -n \
  --arg hostname "${HOSTNAME}" \
  --arg service "${origin_service}" \
  '{config:{ingress:[{hostname:$hostname,service:$service},{service:"http_status:404"}]}}')"

curl -fsS -X PUT "${API_BASE}/accounts/${CLOUDFLARE_ACCOUNT_ID}/cfd_tunnel/${tunnel_id}/configurations" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "${config_payload}" >/dev/null

echo "Tunnel ready:"
echo "  name: ${TUNNEL_NAME}"
echo "  id: ${tunnel_id}"
echo "  hostname: ${HOSTNAME}"
echo "  secret: ${NAMESPACE}/${SECRET_NAME}"

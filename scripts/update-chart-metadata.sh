#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <image-tag> <upstream-sha>" >&2
  exit 1
fi

image_tag="$1"
upstream_sha="$2"
short_sha="${upstream_sha:0:12}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
chart_file="${repo_root}/charts/ghidrai-api/Chart.yaml"
values_file="${repo_root}/charts/ghidrai-api/values.yaml"
deploy_values_file="${repo_root}/deploy/values.yaml"

current_version="$(awk '/^version: / { print $2; exit }' "${chart_file}")"
current_app_version="$(awk -F'"' '/^appVersion: / { print $2; exit }' "${chart_file}")"
current_values_tag="$(awk '/^  tag: / { print $2; exit }' "${values_file}")"
current_deploy_tag="$(awk '/^  tag: / { print $2; exit }' "${deploy_values_file}")"

if [[ "${current_app_version}" == "${short_sha}" && "${current_values_tag}" == "${image_tag}" && "${current_deploy_tag}" == "${image_tag}" ]]; then
  echo "Chart metadata already points at ${image_tag} (${short_sha}); nothing to update."
  exit 0
fi

IFS=. read -r major minor patch <<< "${current_version}"
next_version="${major}.${minor}.$((patch + 1))"

sed -i.bak -E "0,/^version: .*/s//version: ${next_version}/" "${chart_file}"
sed -i.bak -E "0,/^appVersion: .*/s//appVersion: \"${short_sha}\"/" "${chart_file}"
sed -i.bak -E "0,/^  tag: .*/s//  tag: ${image_tag}/" "${values_file}"
sed -i.bak -E "0,/^  tag: .*/s//  tag: ${image_tag}/" "${deploy_values_file}"
rm -f "${chart_file}.bak" "${values_file}.bak" "${deploy_values_file}.bak"

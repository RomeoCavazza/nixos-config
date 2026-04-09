#!/usr/bin/env bash
set -euo pipefail

cache_file="${XDG_RUNTIME_DIR:-/tmp}/conky-gpu-name.cache"
now="$(date +%s)"

if [[ -f "${cache_file}" ]]; then
  read -r ts name < "${cache_file}" || true
else
  ts=0
  name="n/a"
fi

[[ "${ts:-0}" =~ ^[0-9]+$ ]] || ts=0
name="${name:-n/a}"

if (( now - ts < 86400 )); then
  echo "${name}"
  exit 0
fi

new_name="$(timeout 0.45s nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 || true)"
if [[ -n "${new_name}" ]]; then
  safe_name="$(echo "${new_name}" | tr ' ' '_')"
  printf '%s %s\n' "${now}" "${safe_name}" > "${cache_file}"
  echo "${new_name}"
  exit 0
fi

if [[ "${name}" != "n/a" ]]; then
  echo "${name//_/ }"
else
  echo "n/a"
fi

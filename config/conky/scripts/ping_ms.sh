#!/usr/bin/env bash
set -euo pipefail

host="${1:-1.1.1.1}"
cache_file="${XDG_RUNTIME_DIR:-/tmp}/conky-ping-${host//[^a-zA-Z0-9]/_}.cache"
now="$(date +%s)"

if ! command -v ping >/dev/null 2>&1; then
  echo 0
  exit 0
fi

if [[ -f "${cache_file}" ]]; then
  read -r ts cached_ms < "${cache_file}" || true
else
  ts=0
  cached_ms=0
fi

[[ "${ts:-0}" =~ ^[0-9]+$ ]] || ts=0
[[ "${cached_ms:-0}" =~ ^[0-9]+$ ]] || cached_ms=0

if (( now - ts <= 2 )); then
  echo "${cached_ms}"
  exit 0
fi

line="$(timeout 0.45s ping -n -q -c 1 -W 1 "${host}" 2>/dev/null | awk -F'/' '/^rtt|^round-trip/ {print $5; exit}' || true)"
if [[ -z "${line}" ]]; then
  echo "${cached_ms}"
  exit 0
fi

ms="${line%.*}"
[[ "${ms}" =~ ^[0-9]+$ ]] || ms=0
if (( ms > 500 )); then ms=500; fi

printf '%s %s\n' "${now}" "${ms}" > "${cache_file}"
echo "${ms}"

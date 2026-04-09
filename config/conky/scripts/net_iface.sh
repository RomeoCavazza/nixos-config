#!/usr/bin/env bash
set -euo pipefail

iface="$(ip route show default 2>/dev/null | awk '/default/ { print $5; exit }' || true)"

if [[ -z "${iface}" ]]; then
  iface="$(ip -o link show up 2>/dev/null | awk -F': ' '$2 != "lo" { print $2; exit }' || true)"
fi

if [[ -z "${iface}" ]]; then
  echo "n/a"
  exit 0
fi

printf '%s\n' "${iface}"

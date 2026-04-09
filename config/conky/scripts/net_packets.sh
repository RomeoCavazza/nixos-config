#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
iface="$(${SCRIPT_DIR}/net_iface.sh)"

if [[ "${iface}" == "n/a" ]]; then
  echo "n/a"
  exit 0
fi

rx="$(cat "/sys/class/net/${iface}/statistics/rx_packets" 2>/dev/null || true)"
tx="$(cat "/sys/class/net/${iface}/statistics/tx_packets" 2>/dev/null || true)"

rx="${rx:-0}"
tx="${tx:-0}"

echo "r:${rx}  s:${tx}"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
iface="$("${SCRIPT_DIR}/net_iface.sh")"
[[ "${iface}" != "n/a" ]] || { echo 0; exit 0; }

stat_file="/sys/class/net/${iface}/statistics/tx_bytes"
[[ -r "${stat_file}" ]] || { echo 0; exit 0; }

now="$(date +%s)"
current="$(cat "${stat_file}")"
state_file="${XDG_RUNTIME_DIR:-/tmp}/conky-net-tx.state"

if [[ -f "${state_file}" ]]; then
  read -r last_iface last_time last_value last_rate < "${state_file}" || true
else
  last_iface=""
  last_time=0
  last_value="${current}"
  last_rate=0
fi

last_rate="${last_rate:-0}"

if [[ "${iface}" == "${last_iface}" && "${now}" -eq "${last_time}" ]]; then
  echo "${last_rate}"
  exit 0
fi

if [[ "${iface}" != "${last_iface}" || "${last_time}" -eq 0 || "${now}" -le "${last_time}" ]]; then
  printf '%s %s %s %s\n' "${iface}" "${now}" "${current}" "0" > "${state_file}"
  echo 0
  exit 0
fi

delta_bytes=$((current - last_value))
delta_time=$((now - last_time))

if (( delta_bytes < 0 )); then
  delta_bytes=0
fi

if (( delta_time < 1 )); then delta_time=1; fi

rate="$(awk -v bytes="${delta_bytes}" -v secs="${delta_time}" 'BEGIN { printf "%.0f", bytes / secs / 1024 }')"
printf '%s %s %s %s\n' "${iface}" "${now}" "${current}" "${rate}" > "${state_file}"
echo "${rate}"

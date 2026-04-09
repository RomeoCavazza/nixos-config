#!/usr/bin/env bash
set -euo pipefail

key="${1:-util}"
cache_file="${XDG_RUNTIME_DIR:-/tmp}/conky-gpu-info.cache"
now="$(date +%s)"

read_cache() {
  [[ -f "${cache_file}" ]] || return 1
  IFS='|' read -r ts util temp power mem_used mem_total sm_clock mem_clock < "${cache_file}" || return 1
  [[ "${ts:-0}" =~ ^[0-9]+$ ]] || return 1
  (( now - ts <= 5 )) || return 1
  return 0
}

refresh_cache() {
  local line
  line="$(timeout 0.45s nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,power.draw,memory.used,memory.total,clocks.sm,clocks.mem --format=csv,noheader,nounits 2>/dev/null | head -n1 || true)"
  if [[ -z "${line}" ]]; then
    if [[ -f "${cache_file}" ]]; then
      return
    fi
    printf '%s|%s|%s|%s|%s|%s|%s|%s\n' "${now}" 0 0 0 0 0 0 0 > "${cache_file}"
    return
  fi

  IFS=',' read -r util temp power mem_used mem_total sm_clock mem_clock <<< "${line}"

  clean() {
    echo "$1" | sed -E 's/^ +| +$//g'
  }

  util="$(clean "${util}")"
  temp="$(clean "${temp}")"
  power="$(clean "${power}")"
  mem_used="$(clean "${mem_used}")"
  mem_total="$(clean "${mem_total}")"
  sm_clock="$(clean "${sm_clock}")"
  mem_clock="$(clean "${mem_clock}")"

  [[ "${util}" =~ ^[0-9]+([.][0-9]+)?$ ]] || util=0
  [[ "${temp}" =~ ^[0-9]+([.][0-9]+)?$ ]] || temp=0
  [[ "${power}" =~ ^[0-9]+([.][0-9]+)?$ ]] || power=0
  [[ "${mem_used}" =~ ^[0-9]+$ ]] || mem_used=0
  [[ "${mem_total}" =~ ^[0-9]+$ ]] || mem_total=0
  [[ "${sm_clock}" =~ ^[0-9]+$ ]] || sm_clock=0
  [[ "${mem_clock}" =~ ^[0-9]+$ ]] || mem_clock=0

  util="${util%.*}"
  temp="${temp%.*}"
  power="${power%.*}"

  printf '%s|%s|%s|%s|%s|%s|%s|%s\n' "${now}" "${util}" "${temp}" "${power}" "${mem_used}" "${mem_total}" "${sm_clock}" "${mem_clock}" > "${cache_file}"
}

if ! read_cache; then
  refresh_cache
  IFS='|' read -r ts util temp power mem_used mem_total sm_clock mem_clock < "${cache_file}" || true
fi

case "${key}" in
  name)
    nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 || echo "n/a"
    ;;
  util) echo "${util:-0}" ;;
  temp) echo "${temp:-0}" ;;
  power) echo "${power:-0}" ;;
  mem_used) echo "${mem_used:-0}" ;;
  mem_total) echo "${mem_total:-0}" ;;
  sm_clock) echo "${sm_clock:-0}" ;;
  mem_clock) echo "${mem_clock:-0}" ;;
  mem_pct)
    if [[ "${mem_total:-0}" -gt 0 ]]; then
      echo $(( mem_used * 100 / mem_total ))
    else
      echo 0
    fi
    ;;
  *) echo 0 ;;
esac

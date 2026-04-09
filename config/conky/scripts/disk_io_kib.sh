#!/usr/bin/env bash
set -euo pipefail

state_file="${XDG_RUNTIME_DIR:-/tmp}/conky-disk-io.state"
now="$(date +%s)"

root_src="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
[[ -n "${root_src}" ]] || { echo 0; exit 0; }

dev="${root_src##*/}"
pkname="$(lsblk -ndo PKNAME "/dev/${dev}" 2>/dev/null || true)"
if [[ -n "${pkname}" ]]; then
  dev="${pkname}"
fi

stats="$(awk -v d="${dev}" '$3==d { print $6, $10; exit }' /proc/diskstats 2>/dev/null || true)"
[[ -n "${stats}" ]] || { echo 0; exit 0; }

read -r read_sectors write_sectors <<< "${stats}"
read_sectors="${read_sectors:-0}"
write_sectors="${write_sectors:-0}"

current_total_bytes=$(( (read_sectors + write_sectors) * 512 ))

if [[ -f "${state_file}" ]]; then
  read -r last_dev last_time last_total_bytes last_rate < "${state_file}" || true
else
  last_dev=""
  last_time=0
  last_total_bytes="${current_total_bytes}"
  last_rate=0
fi

last_rate="${last_rate:-0}"

if [[ "${dev}" == "${last_dev}" && "${now}" -eq "${last_time}" ]]; then
  echo "${last_rate}"
  exit 0
fi

if [[ "${dev}" != "${last_dev}" || "${last_time}" -eq 0 || "${now}" -le "${last_time}" ]]; then
  printf '%s %s %s %s\n' "${dev}" "${now}" "${current_total_bytes}" "0" > "${state_file}"
  echo 0
  exit 0
fi

delta_bytes=$((current_total_bytes - last_total_bytes))
delta_time=$((now - last_time))

if (( delta_bytes < 0 )); then delta_bytes=0; fi
if (( delta_time < 1 )); then delta_time=1; fi

rate="$(awk -v bytes="${delta_bytes}" -v secs="${delta_time}" 'BEGIN { printf "%.0f", bytes / secs / 1024 }')"
printf '%s %s %s %s\n' "${dev}" "${now}" "${current_total_bytes}" "${rate}" > "${state_file}"
echo "${rate}"

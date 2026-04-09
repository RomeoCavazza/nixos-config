#!/usr/bin/env bash
set -euo pipefail

if command -v sensors >/dev/null 2>&1; then
  v="$(sensors 2>/dev/null | awk '
    /Package id 0:/ { gsub(/[^0-9.]/, "", $4); print $4; exit }
    /Tctl:/ { gsub(/[^0-9.]/, "", $2); print $2; exit }
    /Tdie:/ { gsub(/[^0-9.]/, "", $2); print $2; exit }
  ' || true)"
  if [[ -n "${v}" ]]; then
    echo "${v%.*}"
    exit 0
  fi
fi

max=0
for f in /sys/class/thermal/thermal_zone*/temp; do
  [[ -r "${f}" ]] || continue
  t="$(cat "${f}" 2>/dev/null || echo 0)"
  [[ "${t}" =~ ^[0-9]+$ ]] || continue
  if (( t > max )); then
    max="${t}"
  fi
done

if (( max > 0 )); then
  echo $(( max / 1000 ))
else
  echo 0
fi

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
raw="$(${SCRIPT_DIR}/gpu_info.sh power)"
[[ "${raw}" =~ ^[0-9]+$ ]] || raw=0

state_file="${XDG_RUNTIME_DIR:-/tmp}/conky-gpu-power-graph.state"
min_max=12

if [[ -f "${state_file}" ]]; then
  read -r max_seen < "${state_file}" || true
else
  max_seen=35
fi

[[ "${max_seen:-}" =~ ^[0-9]+$ ]] || max_seen=35

if (( raw > max_seen )); then
  max_seen=${raw}
else
  drop=$(( max_seen / 25 ))
  if (( drop < 1 )); then drop=1; fi
  max_seen=$(( max_seen - drop ))
fi

if (( max_seen < min_max )); then
  max_seen=${min_max}
fi

pct=$(( raw * 100 / max_seen ))
if (( pct > 100 )); then pct=100; fi
if (( pct < 0 )); then pct=0; fi

printf '%s\n' "${max_seen}" > "${state_file}"
echo "${pct}"

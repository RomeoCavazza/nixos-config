#!/usr/bin/env bash
set -euo pipefail

WIDTH=110
ROFI_CMD=(rofi -show drun -theme "$HOME/.config/rofi/custom/column-tco.rasi" -normal-window)
CONKY_STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/conky-left-gap.base"

# Read the base gaps_out value.
BASE_GAP="$(hyprctl getoption general:gaps_out -j | jq -r '.int' 2>/dev/null || echo 16)"
[[ "$BASE_GAP" =~ ^[0-9]+$ ]] || BASE_GAP=16

# Apply a left-only gaps_out value when supported.
apply_left_only_gap() {
  local left="$1"
  local base="$2"

  # 1) Comma-separated format, commonly accepted.
  if hyprctl keyword general:gaps_out "${base},${base},${base},${left}" >/dev/null 2>&1; then
    return 0
  fi

  # 2) Space-separated format, accepted by some builds.
  if hyprctl keyword general:gaps_out "${base} ${base} ${base} ${left}" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

restore_gap() {
  # Restore the global base value.
  hyprctl keyword general:gaps_out "$BASE_GAP" >/dev/null 2>&1 || true
}

stop_conky_rails() {
  # Kill all conky variants (left, right, legacy)
  pkill -f 'conky -q -c.*conky-left' >/dev/null 2>&1 || true
  pkill -f 'conky -q -c.*conky-right' >/dev/null 2>&1 || true
  pkill -f 'conky -q -c.*conky\.txt' >/dev/null 2>&1 || true
  pkill -f 'conky .*system_panel' >/dev/null 2>&1 || true
  pkill -f 'conky .*network_panel' >/dev/null 2>&1 || true

  if [[ -f "$CONKY_STATE_FILE" ]]; then
    hyprctl keyword general:gaps_out "$(cat "$CONKY_STATE_FILE" 2>/dev/null || echo "$BASE_GAP")" >/dev/null 2>&1 || true
    rm -f "$CONKY_STATE_FILE"
  fi
}

if pgrep -x rofi >/dev/null 2>&1; then
  pkill -x rofi
  restore_gap
  exit 0
fi

stop_conky_rails

LEFT_GAP=$((BASE_GAP + WIDTH))

# If unsupported, apply nothing to avoid shrinking every edge.
if ! apply_left_only_gap "$LEFT_GAP" "$BASE_GAP"; then
  exit 1
fi

"${ROFI_CMD[@]}" || true
restore_gap

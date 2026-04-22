#!/usr/bin/env bash
set -euo pipefail

GAP_HELPER="/etc/nixos/config/bin/hypr-gap-state.sh"
# shellcheck source=/etc/nixos/config/bin/hypr-gap-state.sh
source "$GAP_HELPER"

WIDTH=110
ROFI_CMD=(rofi -show drun -theme "$HOME/.config/rofi/custom/column-tco.rasi" -normal-window)
CONKY_STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/conky-left-gap.base"
ROFI_PUSH_STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/rofi-push.state"

# --- ACTIONS ---

stop_conky_rails() {
  pkill -f 'conky -q -c.*conky-left' >/dev/null 2>&1 || true
  pkill -f 'conky -q -c.*conky-right' >/dev/null 2>&1 || true
  pkill -f 'conky -q -c.*conky\.txt' >/dev/null 2>&1 || true
  pkill -f 'conky .*system_panel' >/dev/null 2>&1 || true
  pkill -f 'conky .*network_panel' >/dev/null 2>&1 || true

  if [[ -f "$CONKY_STATE_FILE" ]]; then
    hypr_restore_workspace_state "$CONKY_STATE_FILE" "$(hypr_get_global_gap_fallback "general:gaps_out" "16 16 16 16")"
  fi
}

# Toggle logic
if pgrep -x rofi >/dev/null 2>&1; then
  pkill -x rofi
  hypr_restore_workspace_state "$ROFI_PUSH_STATE_FILE"
  exit 0
fi

stop_conky_rails
hyprctl dispatch overview:close all >/dev/null 2>&1 || true

# Calculate and apply new gaps
ACTIVE_WS="$(hyprctl activeworkspace -j | jq -r '.name // (.id | tostring)')"
GAPS_IN="$(hypr_get_workspace_gaps "$ACTIVE_WS" "in")"
GAPS_OUT="$(hypr_get_workspace_gaps "$ACTIVE_WS" "out")"

# Normalize GAPS_OUT to 4 values for left-side push
read -r top right bottom left _rest <<<"$GAPS_OUT"
top=${top:-16}; right=${right:-16}; bottom=${bottom:-16}; left=${left:-16}

NEW_LEFT=$((left + WIDTH))
NEW_GAPS_OUT="${top} ${right} ${bottom} ${NEW_LEFT}"

hypr_capture_workspace_state "$ROFI_PUSH_STATE_FILE" "$ACTIVE_WS"
if ! hypr_apply_workspace_gaps "$ACTIVE_WS" "$GAPS_IN" "$NEW_GAPS_OUT"; then
  rm -f "$ROFI_PUSH_STATE_FILE"
  exit 1
fi

"${ROFI_CMD[@]}" || true
hypr_restore_workspace_state "$ROFI_PUSH_STATE_FILE"

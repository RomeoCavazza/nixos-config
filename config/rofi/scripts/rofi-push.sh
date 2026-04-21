#!/usr/bin/env bash
set -euo pipefail

WIDTH=110
ROFI_CMD=(rofi -show drun -theme "$HOME/.config/rofi/custom/column-tco.rasi" -normal-window)
CONKY_STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/conky-left-gap.base"
ROFI_PUSH_STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/rofi-push.state"

# --- GAP FETCHING UTILITIES ---

# Fetch a fallback gap value from general:gaps_in/out
get_global_gap_fallback() {
  local option="$1"
  local fallback="$2"
  local data
  data="$(hyprctl getoption "$option" -j 2>/dev/null || true)"
  
  # Try custom first
  local custom; custom="$(echo "$data" | jq -r '.custom // empty')"
  [[ -n "$custom" ]] && { echo "$custom"; return; }
  
  # Try int
  local val; val="$(echo "$data" | jq -r '.int // empty')"
  [[ "$val" =~ ^[0-9]+$ ]] && { echo "$val $val $val $val"; return; }
  
  echo "$fallback"
}

# Get specialized gaps for a workspace, falling back to global options
get_workspace_gaps() {
  local ws="$1"
  local type="$2" # "in" or "out"
  local field="gaps${type^}" # gapsIn or gapsOut
  local global_opt="general:gaps_${type}"
  local default_val=$([[ "$type" == "in" ]] && echo "8 8 8 8" || echo "16 16 16 16")

  # 1. Try workspace rules
  local from_rule
  from_rule="$(hyprctl workspacerules -j 2>/dev/null | jq -r --arg ws "$ws" --arg f "$field" '
    map(select(.workspaceString == $ws)) | .[0][$f] |
    if type == "array" then map(tostring) | join(" ") else tostring // empty end
  ')"

  if [[ -n "$from_rule" ]]; then
    echo "$from_rule"
  else
    get_global_gap_fallback "$global_opt" "$default_val"
  fi
}

# --- STATE MANAGEMENT ---

apply_workspace_gap_override() {
  local ws="$1" gaps_in="$2" gaps_out="$3"
  hyprctl -r keyword workspace "${ws}, gapsin:${gaps_in}, gapsout:${gaps_out}" >/dev/null 2>&1
}

write_state() {
  printf 'workspace=%q\ngaps_in=%q\ngaps_out=%q\n' "$@" >"$ROFI_PUSH_STATE_FILE"
}

restore_gap_from_state() {
  [[ -f "$ROFI_PUSH_STATE_FILE" ]] || return 0
  local workspace="" gaps_in="" gaps_out=""
  # shellcheck disable=SC1090
  source "$ROFI_PUSH_STATE_FILE"
  if [[ -n "$workspace" && -n "$gaps_in" && -n "$gaps_out" ]]; then
    apply_workspace_gap_override "$workspace" "$gaps_in" "$gaps_out" || true
  fi
  rm -f "$ROFI_PUSH_STATE_FILE"
}

# --- ACTIONS ---

stop_conky_rails() {
  pkill -f 'conky -q -c.*conky-left' >/dev/null 2>&1 || true
  pkill -f 'conky -q -c.*conky-right' >/dev/null 2>&1 || true
  pkill -f 'conky -q -c.*conky\.txt' >/dev/null 2>&1 || true
  pkill -f 'conky .*system_panel' >/dev/null 2>&1 || true
  pkill -f 'conky .*network_panel' >/dev/null 2>&1 || true

  if [[ -f "$CONKY_STATE_FILE" ]]; then
    local base_gap; base_gap="$(cat "$CONKY_STATE_FILE" 2>/dev/null || echo "16")"
    hyprctl keyword general:gaps_out "$base_gap" >/dev/null 2>&1 || true
    rm -f "$CONKY_STATE_FILE"
  fi
}

# Toggle logic
if pgrep -x rofi >/dev/null 2>&1; then
  pkill -x rofi
  restore_gap_from_state
  exit 0
fi

stop_conky_rails

# Calculate and apply new gaps
ACTIVE_WS="$(hyprctl activeworkspace -j | jq -r '.name // (.id | tostring)')"
GAPS_IN="$(get_workspace_gaps "$ACTIVE_WS" "in")"
GAPS_OUT="$(get_workspace_gaps "$ACTIVE_WS" "out")"

# Normalize GAPS_OUT to 4 values for left-side push
read -r top right bottom left _rest <<<"$GAPS_OUT"
top=${top:-16}; right=${right:-16}; bottom=${bottom:-16}; left=${left:-16}

NEW_LEFT=$((left + WIDTH))
NEW_GAPS_OUT="${top} ${right} ${bottom} ${NEW_LEFT}"

write_state "$ACTIVE_WS" "$GAPS_IN" "$GAPS_OUT"
if ! apply_workspace_gap_override "$ACTIVE_WS" "$GAPS_IN" "$NEW_GAPS_OUT"; then
  rm -f "$ROFI_PUSH_STATE_FILE"
  exit 1
fi

"${ROFI_CMD[@]}" || true
restore_gap_from_state

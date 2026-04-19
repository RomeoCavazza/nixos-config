#!/usr/bin/env bash
set -euo pipefail

THEME="$HOME/.config/rofi/themes/apps-grid.rasi"
WAYBAR_CFG="$HOME/.config/waybar/config.jsonc"
WAYBAR_CSS="$HOME/.config/waybar/style.css"
CONKY_STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/conky-left-gap.base"

getopt_int() { hyprctl getoption "$1" | awk '/int:/ {print $2; exit}'; }

OLD_SIZE="$(getopt_int decoration:blur:size)"
OLD_PASSES="$(getopt_int decoration:blur:passes)"
OLD_IGNORE="$(getopt_int decoration:blur:ignore_opacity)"
BASE_GAP="$(hyprctl getoption general:gaps_out -j | jq -r '.int' 2>/dev/null || echo 16)"
[[ "$BASE_GAP" =~ ^[0-9]+$ ]] || BASE_GAP=16

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

restore() {
  hyprctl keyword decoration:blur:size "$OLD_SIZE" >/dev/null 2>&1 || true
  hyprctl keyword decoration:blur:passes "$OLD_PASSES" >/dev/null 2>&1 || true
  hyprctl keyword decoration:blur:ignore_opacity "$OLD_IGNORE" >/dev/null 2>&1 || true

  # Always restart Waybar; avoid fragile conditions.
  nohup waybar -c "$WAYBAR_CFG" -s "$WAYBAR_CSS" >/dev/null 2>&1 &
}
trap restore EXIT INT TERM

# Slightly boost blur.
hyprctl keyword decoration:blur:size 8 >/dev/null 2>&1

# Rofi sidebar and Conky rails must not overlap.
stop_conky_rails

# Kill waybar (match cmdline, version nix/wrapped friendly)
pkill -u "$USER" -f 'waybar' 2>/dev/null || true

# Run rofi (blocking)
rofi -show drun -theme "$THEME"

#!/usr/bin/env bash
set -euo pipefail

WIDTH=110
ROFI_CMD=(rofi -show drun -theme "$HOME/.config/rofi/custom/column-tco.rasi" -normal-window)

# Récupère le gaps_out "base" (chez toi c'est 16)
BASE_GAP="$(hyprctl getoption general:gaps_out -j | jq -r '.int' 2>/dev/null || echo 16)"
[[ "$BASE_GAP" =~ ^[0-9]+$ ]] || BASE_GAP=16

# Applique un gaps_out gauche uniquement (si supporté)
apply_left_only_gap() {
  local left="$1"
  local base="$2"

  # 1) format avec virgules (souvent accepté)
  if hyprctl keyword general:gaps_out "${base},${base},${base},${left}" >/dev/null 2>&1; then
    return 0
  fi

  # 2) format avec espaces (certaines builds)
  if hyprctl keyword general:gaps_out "${base} ${base} ${base} ${left}" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

restore_gap() {
  # on restaure "global" base; si tu avais déjà 4 valeurs dans ton conf, tu peux les remettre ici
  hyprctl keyword general:gaps_out "$BASE_GAP" >/dev/null 2>&1 || true
}

if pgrep -x rofi >/dev/null 2>&1; then
  pkill -x rofi
  restore_gap
  exit 0
fi

LEFT_GAP=$((BASE_GAP + WIDTH))

# IMPORTANT: si pas supporté -> on n'applique rien (sinon ça shrink partout)
if ! apply_left_only_gap "$LEFT_GAP" "$BASE_GAP"; then
  exit 1
fi

"${ROFI_CMD[@]}" || true
restore_gap

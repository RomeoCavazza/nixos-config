#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/conky"
REPO_DIR="/etc/nixos/config/conky"
CONKY_CFG="$CONFIG_DIR/conky-left.txt"
CONKY_RIGHT_CFG="$CONFIG_DIR/conky-right.txt"
CONKY_RE='conky .*(conky-left\.txt|conky-right\.txt|conky\.txt)'
LEGACY_RE='conky .*system_panel\.conkyrc|conky .*network_panel\.conkyrc'

# Conky and Rofi sidebar are mutually exclusive.
pkill -x rofi >/dev/null 2>&1 || true

pkill -f "$CONKY_RE" >/dev/null 2>&1 || true
pkill -f "$LEGACY_RE" >/dev/null 2>&1 || true
sleep 0.2

# Prefer the repository config if available; it may be newer than ~/.config.
if [[ -f "$REPO_DIR/conky-left.txt" ]]; then
  CONKY_CFG="$REPO_DIR/conky-left.txt"
  CONKY_RIGHT_CFG="$REPO_DIR/conky-right.txt"
  export PATH="$REPO_DIR/scripts:$REPO_DIR:$CONFIG_DIR/scripts:$CONFIG_DIR:$PATH"
elif [[ -f "$CONKY_CFG" ]]; then
  export PATH="$CONFIG_DIR/scripts:$CONFIG_DIR:$PATH"
else
  echo "Conky config missing in $REPO_DIR and $CONFIG_DIR" >&2
  exit 1
fi

# Warm caches asynchronously so startup is instant.
(
  gpu_info.sh util >/dev/null 2>&1 || true
  gpu_name.sh >/dev/null 2>&1 || true
  ping_ms.sh 1.1.1.1 >/dev/null 2>&1 || true
  nix_store_size.sh >/dev/null 2>&1 || true
) >/dev/null 2>&1 &

conky -q -c "$CONKY_CFG" -d

if [[ -f "$CONKY_RIGHT_CFG" ]]; then
  conky -q -c "$CONKY_RIGHT_CFG" -d
fi

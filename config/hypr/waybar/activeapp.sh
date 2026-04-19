#!/usr/bin/env bash
set -euo pipefail

# Read the active window from Hyprland as JSON.
j="$(hyprctl -j activewindow 2>/dev/null || echo '{}')"

cls="$(echo "$j" | jq -r '.class // ""')"
title="$(echo "$j" | jq -r '.title // ""')"

icon=""  # fallback

# Basic mapping, easy to extend.
case "${cls,,}" in
  foot|alacritty|kitty|wezterm) icon="" ;;
  firefox) icon="" ;;
  chromium|google-chrome|brave-browser) icon="" ;;
  code|codium|vscodium) icon="󰨞" ;;
  cursor) icon="󰚩" ;;
  nemo|nautilus|thunar|dolphin) icon="" ;;
  org.gnome.nautilus) icon="" ;;
  virt-manager|virt-manager.py|org.virt_manager.virt-manager) icon="󰣇" ;;
  dbeaver) icon="󰆼" ;;
  steam) icon="" ;;
  discord) icon="󰙯" ;;
  spotify) icon="" ;;
  mpv|vlc) icon="󰕼" ;;
esac

# Waybar JSON output (return-type=json).
# Tooltip is the full title; text is the icon only.
printf '{"text":"%s","tooltip":"%s"}\n' "$icon" "${title//\"/\\\"}"

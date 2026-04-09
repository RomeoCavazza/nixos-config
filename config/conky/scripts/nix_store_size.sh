#!/usr/bin/env bash
set -euo pipefail

cache_file="${XDG_RUNTIME_DIR:-/tmp}/conky-nix-store-size.cache"
now="$(date +%s)"

if [[ -f "${cache_file}" ]]; then
  read -r ts cached_value < "${cache_file}" || true
else
  ts=0
  cached_value="n/a"
fi

[[ "${ts:-0}" =~ ^[0-9]+$ ]] || ts=0
cached_value="${cached_value:-n/a}"

# Refresh at most every 10 minutes.
if (( now - ts < 600 )); then
  echo "${cached_value}"
  exit 0
fi

new_value="$(timeout 1.2s du -sh /nix/store 2>/dev/null | awk '{print $1}' || true)"
if [[ -n "${new_value}" ]]; then
  printf '%s %s\n' "${now}" "${new_value}" > "${cache_file}"
  echo "${new_value}"
  exit 0
fi

# Fall back to cached value if refresh times out.
echo "${cached_value}"

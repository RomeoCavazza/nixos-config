#!/usr/bin/env bash

hypr_normalize_gap_values() {
  tr ',' ' ' <<<"$1" | xargs
}

hypr_get_global_gap_fallback() {
  local option="$1"
  local fallback="$2"
  local data custom value

  data="$(hyprctl getoption "$option" -j 2>/dev/null || true)"
  custom="$(jq -r '.custom // empty' <<<"$data")"
  if [[ -n "$custom" ]]; then
    hypr_normalize_gap_values "$custom"
    return 0
  fi

  value="$(jq -r '.int // empty' <<<"$data")"
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    printf '%s %s %s %s\n' "$value" "$value" "$value" "$value"
    return 0
  fi

  printf '%s\n' "$fallback"
}

hypr_get_workspace_gaps() {
  local workspace="$1"
  local type="$2"
  local field="gaps${type^}"
  local option="general:gaps_${type}"
  local fallback=$([[ "$type" == "in" ]] && echo "8 8 8 8" || echo "16 16 16 16")
  local value

  value="$(hyprctl workspacerules -j 2>/dev/null | jq -r --arg ws "$workspace" --arg field "$field" '
    map(select(.workspaceString == $ws)) | .[0][$field] |
    if type == "array" then map(tostring) | join(" ") else empty end
  ' 2>/dev/null || true)"

  if [[ -n "$value" ]]; then
    printf '%s\n' "$value"
    return 0
  fi

  hypr_get_global_gap_fallback "$option" "$fallback"
}

hypr_list_target_workspaces() {
  {
    hyprctl workspacerules -j 2>/dev/null | jq -r '.[]?.workspaceString // empty' 2>/dev/null || true
    hyprctl workspaces -j 2>/dev/null | jq -r '.[] | (.name // (.id | tostring))' 2>/dev/null || true
    hyprctl activeworkspace -j 2>/dev/null | jq -r '.name // (.id | tostring) // empty' 2>/dev/null || true
  } | awk 'NF && !seen[$0]++'
}

hypr_apply_workspace_gaps() {
  local workspace="$1"
  local gaps_in="$2"
  local gaps_out="$3"

  hyprctl -r keyword workspace "${workspace}, gapsin:${gaps_in}, gapsout:${gaps_out}" >/dev/null 2>&1
}

hypr_capture_workspace_state() {
  local state_file="$1"
  shift

  : >"$state_file"

  local workspace gaps_in gaps_out
  for workspace in "$@"; do
    [[ -n "$workspace" ]] || continue
    gaps_in="$(hypr_get_workspace_gaps "$workspace" in)"
    gaps_out="$(hypr_get_workspace_gaps "$workspace" out)"
    printf '%s, gapsin:%s, gapsout:%s\n' "$workspace" "$gaps_in" "$gaps_out" >>"$state_file"
  done
}

hypr_restore_workspace_state() {
  local state_file="$1"
  local legacy_fallback="${2:-16 16 16 16}"
  local line restored=1

  [[ -f "$state_file" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue

    if [[ "$line" == *,\ gapsin:*\,\ gapsout:* ]]; then
      hyprctl -r keyword workspace "$line" >/dev/null 2>&1 || true
      restored=0
      continue
    fi

    legacy_fallback="$line"
  done <"$state_file"

  if (( restored )); then
    hyprctl keyword general:gaps_out "$legacy_fallback" >/dev/null 2>&1 || true
  fi

  rm -f "$state_file"
}

# Hyprchroma v3.3.1-v054 Publishing Bundle

## Scope

This patch release is intentionally small:

- reduce workspace-switch tint suspension from `900 ms` to `150 ms`
- add configurable `plugin:darkwindow:suspend_on_workspace_switch_ms`
- smooth Hyprchroma behavior during animated workspace transitions, especially with Hyprspace
- lighten README history/docs and update release metadata to `v3.3.1-v054`

## Files to sync to `RomeoCavazza/Hyprchroma`

- `src/main.cpp`
- `README.md`
- `RELEASE_NOTES.md`
- `flake.nix`

Optional:

- `res/preview.png` only if you want new visuals
- repo workflows only if the public repo differs from local CI

Do not sync NixOS-local files:

- `/etc/nixos/config/hypr/theme/hyprchroma.conf`
- `/etc/nixos/home/tco/home.nix`

## Suggested tag

`v3.3.1-v054`

## Suggested release title

`v3.3.1-v054 — Workspace switch smoothing for Hyprland v0.54.2`

## Suggested release body

```md
## Highlights

- Adds `plugin:darkwindow:suspend_on_workspace_switch_ms`
- Reduces the default workspace-switch tint suspension to `150 ms`
- Prevents stale blue chroma carry-over during animated workspace transitions
- Keeps the grouped adaptive shader path introduced in `v3.3.0-v054`

## Why this release exists

Some animated workspace transitions could keep the previous workspace visually alive for a short time while Hyprchroma was still shading it. In practice, that looked like a lingering blue glow from the old workspace.

`v3.3.1-v054` adds a tiny configurable suspension window after `workspace.active` events so tinting drops out during the transition and returns cleanly once the new workspace settles.

## New config

```conf
plugin:darkwindow:suspend_on_workspace_switch_ms = 150
```

Set it to `0` to disable the behavior entirely.

## Compatibility

- Target Hyprland: `v0.54.2`
- Existing `plugin:darkwindow:*` settings remain compatible
```

## Publish checklist

1. Sync the four files above into `RomeoCavazza/Hyprchroma`
2. Commit with something like:
   `release: cut v3.3.1-v054`
3. Tag:
   `git tag v3.3.1-v054`
4. Push branch + tag
5. Create GitHub release using the body above

## Local verification already done

`nix build /etc/nixos/home/tco/pkgs/Hyprchroma-fork#hyprchroma -L`

Result: passes as `hyprchroma-3.3.1-v054`

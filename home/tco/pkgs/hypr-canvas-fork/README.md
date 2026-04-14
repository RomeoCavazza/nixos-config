# hypr-canvas

An infinite canvas plugin for [Hyprland](https://hyprland.org). Zoom out to see all your windows at once, pan around a vast virtual desktop, and zoom back in to work — like Google Maps for your desktop.

> **⚠️ Super alpha.** This plugin hooks deep into Hyprland's internals. It may set your computer on fire, cause a divide by zero when maximizing an application, and form a black hole ending our universe. ABI-locked to Hyprland v0.54.2. You have been warned.

## Demo

**Super+Scroll** to zoom in/out. **Super+Left-Drag** on empty space to pan.

Works with both native Wayland apps and XWayland apps (Chrome, Discord, Electron).

## Building

Requires Hyprland v0.54.2 and its development headers.

```bash
make
make reload   # copies to /tmp to bypass dlopen cache, then loads
```

## How It Works

The plugin hooks 12 functions inside Hyprland to intercept rendering, input, coordinate mapping, and popup positioning. No source patches needed — it's a pure plugin using `createFunctionHook`.

### Coordinate Spaces

```
Physical space: monitor pixels (0,0)-(7680,2160)
                hardware cursor always lives here
                                    │
                          position() hook
                          offset + physical / zoom
                                    │
                                    ▼
Canvas space:   infinite plane where windows exist
                at their normal Hyprland positions
```

**Rendering** transforms canvas → physical: `screenPos = (canvasPos - offset) * zoom`

**Input** transforms physical → canvas: `canvasPos = offset + screenPos / zoom`

### Hook Summary

| Hook | What it does |
|------|-------------|
| `onMouseWheel` | Super+scroll → cursor-anchored zoom |
| `onMouseButton` | Super+left-click on empty desktop → start/stop pan |
| `onMouseMoved` | Pan drag via raw delta (divided by zoom for canvas-space movement) |
| `position()` | Core coordinate remap — returns canvas coords to all 16 callers |
| `closestValid()` | Disables cursor clamping so pointer can reach beyond monitor bounds |
| `getMonitorFromCursor()` | Returns focused monitor when canvas coords are out of bounds |
| `getMonitorFromVector()` | Same fallback for position-based lookups (vectorToWindowUnified etc.) |
| `shouldRenderWindow()` | Forces all windows visible when zoomed out |
| `CRenderPass::render()` | Expands damage region to full virtual viewport |
| `renderAllClientsForWorkspace()` | Applies zoom transform via SRenderModifData + clears framebuffer |
| `applyPositioning()` | Expands popup constraint box so menus aren't clamped to monitor |
| `waylandToXWaylandCoords()` | Converts canvas→physical for XWayland apps (Chrome, Discord) |

### Why So Many Hooks?

Hyprland wasn't designed for viewport transforms. The compositor assumes cursor position = screen position = window position. Breaking that assumption requires intercepting every layer:

- **Input layer**: the cursor must move 1:1 with the physical mouse, but all coordinate consumers need canvas-space values
- **Rendering layer**: windows must be offset and scaled, damage regions expanded, render pass simplification disabled
- **Protocol layer**: XWayland apps use absolute X11 coordinates mapped through a separate transform — needs its own hook
- **UI layer**: popup menus (xdg_positioner) are constrained to the monitor — needs expanded bounds

## Prior Work

- **kwin-map**: KWin effect prototype that proved the concept. Hit API limits with input routing.
- **driftwm**: Existing infinite canvas compositor in Rust/smithay. Can't drive ultrawide at native res (no DSC). The coordinate math patterns from driftwm informed our approach.

## License

MIT

# Architecture

## The Problem

Hyprland assumes a 1:1 mapping between cursor position, screen pixels, and window coordinates. An infinite canvas breaks this assumption at every layer of the compositor.

## Coordinate Model

Two coordinate spaces coexist:

**Physical space** — the actual monitor pixels. The hardware cursor lives here. Mouse deltas from libinput are applied here. The DRM backend renders here. Range: `(0,0)` to `(monitorWidth, monitorHeight)`.

**Canvas space** — an infinite plane where windows exist at their normal Hyprland positions. When zoomed out, you can see windows far beyond the monitor bounds. When panned, the viewport shifts across the canvas.

The transforms:

```
canvas = offset + physical / zoom       (input: physical → canvas)
physical = (canvas - offset) * zoom     (render: canvas → physical)
```

`offset` is the canvas-space position of the viewport's top-left corner. `zoom` is the scale factor (1.0 = normal, 0.5 = zoomed out 2x).

## Zoom Anchoring

When zooming, the canvas point under the cursor should stay fixed on screen. This requires adjusting the offset when zoom changes:

```cpp
void applyZoom(double newZoom, const Vector2D& anchorScreen) {
    Vector2D anchorCanvas = screenToCanvas(anchorScreen);
    zoom = clamp(newZoom, ZOOM_MIN, ZOOM_MAX);
    offset = anchorCanvas - anchorScreen / zoom;
}
```

## Hook Architecture

### Input Hooks

**`position()`** — the most important hook. `CPointerManager::position()` returns `m_pointerPos`, which is in physical space. Our hook transforms it to canvas space. This function has 16 call sites, including `mouseMoveUnified` which handles all pointer event routing. By hooking here, every coordinate consumer in Hyprland sees canvas coords.

**`closestValid()`** — `CPointerManager::closestValid()` clamps `m_pointerPos` to the monitor layout. When zoomed, we bypass this clamping so the logical pointer position can extend beyond the monitor bounds.

**`getMonitorFromCursor()` / `getMonitorFromVector()`** — these return null when coordinates are outside all monitors. Canvas coords can be anywhere, so we fall back to the focused monitor. `getMonitorFromVector` is critical — `vectorToWindowUnified` uses it as its first operation and returns null (no window found) if the monitor lookup fails.

### Rendering Hooks

**`renderAllClientsForWorkspace()`** — applies the zoom transform via Hyprland's `SRenderModifData` system, which takes a translate and scale: `(windowPos + translate) * scale`. We pass `translate = -offset, scale = zoom`.

**`shouldRenderWindow()`** — returns true for all windows when zoomed. Without this, windows outside the physical monitor are culled.

**`CRenderPass::render()`** — expands the damage region to the full virtual viewport. Without this, `CRenderPass::simplify()` culls render elements whose bounding boxes (in virtual coords) don't intersect the damage region (in physical coords).

We also clear the framebuffer before rendering when zoomed to prevent stale pixel trails in areas outside the wallpaper.

### Protocol Hooks

**`applyPositioning()`** — Wayland's xdg_positioner constrains popup menus to the monitor bounds. When zoomed, we expand the constraint box so menus appear at the correct canvas position.

**`waylandToXWaylandCoords()`** — XWayland maps Wayland coords to X11 absolute coords via the closest monitor. Canvas coords outside the monitor produce wrong mappings. We convert canvas → physical before the mapping so X11 clients get correct screen-relative positions.

## Why Not Just Hook `position()`?

The initial assumption was that hooking `position()` alone would be sufficient — all coordinate consumers would see canvas coords and everything would work. In practice, multiple layers need separate fixes:

1. **Cursor clamping** (`closestValid`) prevents the pointer from reaching canvas positions outside the monitor
2. **Monitor lookups** (`getMonitorFromVector`) return null for out-of-bounds canvas coords, blocking window finding
3. **Render culling** (`shouldRenderWindow`, `CRenderPass::simplify`) hides windows and elements outside physical bounds
4. **Popup constraints** (`applyPositioning`) clamp menus to monitor geometry
5. **XWayland mapping** (`waylandToXWaylandCoords`) assumes coords are in physical monitor space

Each layer independently enforces the "cursor = screen = window" assumption.

## XWayland vs Native Wayland

Native Wayland apps receive surface-local coordinates via `wl_pointer.motion`. These are computed as `position() - surfacePos` inside `mouseMoveUnified`. Since our `position()` hook returns canvas coords and `surfacePos` is in the same canvas space, the surface-local coords are correct.

XWayland apps use absolute X11 screen coordinates. Hyprland's `waylandToXWaylandCoords` maps Wayland coords to X11 coords via monitor positions. Canvas coords outside the monitor produce distorted X11 coords. Our hook converts canvas → physical before the mapping, giving X11 clients correct positions.

## Panning

Pan uses raw mouse deltas from `IPointer::SMotionEvent`, not position. The offset is adjusted by `delta / zoom` to convert physical-space mouse movement to canvas-space viewport movement. This avoids all the coordinate transform complexity — deltas are always relative.

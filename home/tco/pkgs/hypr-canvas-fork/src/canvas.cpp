#include "canvas.hpp"

#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/managers/PointerManager.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/helpers/Monitor.hpp>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdarg>
#include <linux/input-event-codes.h>

static void logf(const char* fmt, ...) {
    FILE* f = fopen("/tmp/hypr-canvas.log", "a");
    if (!f) return;
    va_list args;
    va_start(args, fmt);
    vfprintf(f, fmt, args);
    va_end(args);
    fclose(f);
}

static void scheduleFrame() {
    auto mon = Desktop::focusState()->monitor();
    if (mon) {
        g_pHyprRenderer->damageMonitor(mon);
        g_pCompositor->scheduleFrameForMonitor(mon);
    }
}

// --- Forward typedefs ---
using PHLWINDOW = SP<Desktop::View::CWindow>;

// --- Scroll/zoom hook ---

typedef void (*onMouseWheelFn)(CInputManager*, IPointer::SAxisEvent, SP<IPointer>);
typedef Vector2D (*positionFn)(CPointerManager*);

static void hkOnMouseWheel(CInputManager* self, IPointer::SAxisEvent e, SP<IPointer> pointer) {
    const uint32_t mods = g_pInputManager->getModsFromAllKBs();

    if (g_pCanvas && g_pCanvas->workspaceChanged())
        g_pCanvas->resetForWorkspaceChange();

    if ((mods & HL_MODIFIER_META) && g_pCanvas && e.axis == WL_POINTER_AXIS_VERTICAL_SCROLL) {
        const double scrollDelta = (e.deltaDiscrete != 0) ? (double)e.deltaDiscrete : e.delta;
        if (scrollDelta != 0) {
            if (!g_pCanvas->active)
                g_pCanvas->enter();

            const double zoomFactor = std::pow(CCanvas::ZOOM_STEP, std::abs(scrollDelta));
            double       newZoom    = g_pCanvas->zoom;
            if (scrollDelta < 0)
                newZoom *= zoomFactor;
            else
                newZoom /= zoomFactor;

            // Center-anchored zoom feels more like a desktop camera than a drag.
            auto mon = Desktop::focusState()->monitor();
            if (!mon)
                return;

            const auto monSize = mon->m_transformedSize;
            const Vector2D center = {monSize.x / 2.0, monSize.y / 2.0};

            g_pCanvas->applyZoom(newZoom, center);
            g_pCanvas->repositionWindows();

            logf("[hypr-canvas] zoom=%.3f offset=(%.1f, %.1f)\n",
                 g_pCanvas->zoom, g_pCanvas->offset.x, g_pCanvas->offset.y);
            scheduleFrame();
            return;
        }
    }

    auto original = (onMouseWheelFn)g_pCanvas->m_mouseWheelHook->m_original;
    original(self, e, pointer);
}

// --- Mouse button hook (pan start/stop) ---

typedef void (*onMouseButtonFn)(CInputManager*, IPointer::SButtonEvent);

static void hkOnMouseButton(CInputManager* self, IPointer::SButtonEvent e) {
    if (g_pCanvas && g_pCanvas->workspaceChanged())
        g_pCanvas->resetForWorkspaceChange();

    if (g_pCanvas && (e.button == BTN_LEFT || e.button == BTN_RIGHT)) {
        const uint32_t mods = g_pInputManager->getModsFromAllKBs();
        if ((mods & HL_MODIFIER_META) && e.state == WL_POINTER_BUTTON_STATE_PRESSED) {
            if (!g_pCanvas->active && e.button == BTN_LEFT) {
                const auto coords = g_pInputManager->getMouseCoordsInternal();
                using namespace Desktop::View;
                auto windowUnder = g_pCompositor->vectorToWindowUnified(coords, RESERVED_EXTENTS | INPUT_EXTENTS | ALLOW_FLOATING);

                if (!windowUnder) {
                    g_pCanvas->enter();
                    g_pCanvas->m_panning = true;
                    logf("[hypr-canvas] pan start\n");
                    return;
                }
            }

            if (!g_pCanvas->active) {
                auto original = (onMouseButtonFn)g_pCanvas->m_mouseButtonHook->m_original;
                original(self, e);
                return;
            }

            if (e.state == WL_POINTER_BUTTON_STATE_PRESSED) {
                const auto coords = g_pInputManager->getMouseCoordsInternal();
                using namespace Desktop::View;
                auto windowUnder = g_pCompositor->vectorToWindowUnified(coords, RESERVED_EXTENTS | INPUT_EXTENTS | ALLOW_FLOATING);

                if (e.button == BTN_LEFT && !windowUnder) {
                    g_pCanvas->m_panning = true;
                    logf("[hypr-canvas] pan start\n");
                    return;
                }

                if (windowUnder) {
                    const uint64_t id = (uint64_t)windowUnder.get();
                    if (g_pCanvas->m_savedStates.contains(id)) {
                        g_pCanvas->m_dragWindow = id;

                        if (e.button == BTN_LEFT) {
                            g_pCanvas->m_movingWindow = true;
                            g_pCanvas->m_resizingWindow = false;
                            logf("[hypr-canvas] window move start id=%lx\n", id);
                            return;
                        }

                        if (e.button == BTN_RIGHT) {
                            g_pCanvas->m_resizingWindow = true;
                            g_pCanvas->m_movingWindow = false;
                            logf("[hypr-canvas] window resize start id=%lx\n", id);
                            return;
                        }
                    }
                }
            }
        }
    }

    if (g_pCanvas && g_pCanvas->m_panning && e.button == BTN_LEFT && e.state == WL_POINTER_BUTTON_STATE_RELEASED) {
        g_pCanvas->m_panning = false;
        logf("[hypr-canvas] pan stop\n");
        return;
    }

    if (g_pCanvas && g_pCanvas->m_movingWindow && e.button == BTN_LEFT && e.state == WL_POINTER_BUTTON_STATE_RELEASED) {
        logf("[hypr-canvas] window move stop id=%lx\n", g_pCanvas->m_dragWindow);
        g_pCanvas->m_movingWindow = false;
        g_pCanvas->m_dragWindow = 0;
        return;
    }

    if (g_pCanvas && g_pCanvas->m_resizingWindow && e.button == BTN_RIGHT && e.state == WL_POINTER_BUTTON_STATE_RELEASED) {
        logf("[hypr-canvas] window resize stop id=%lx\n", g_pCanvas->m_dragWindow);
        g_pCanvas->m_resizingWindow = false;
        g_pCanvas->m_dragWindow = 0;
        return;
    }

    auto original = (onMouseButtonFn)g_pCanvas->m_mouseButtonHook->m_original;
    original(self, e);
}

// --- Mouse move hook (pan drag) ---

typedef void (*onMouseMovedFn)(CInputManager*, IPointer::SMotionEvent);

static void hkOnMouseMoved(CInputManager* self, IPointer::SMotionEvent e) {
    const uint32_t mods = g_pInputManager->getModsFromAllKBs();

    if (g_pCanvas && g_pCanvas->workspaceChanged())
        g_pCanvas->resetForWorkspaceChange();

    // If we ever miss a button-release event, do not stay stuck in a drag mode.
    if (g_pCanvas && !(mods & HL_MODIFIER_META) &&
        (g_pCanvas->m_panning || g_pCanvas->m_movingWindow || g_pCanvas->m_resizingWindow)) {
        logf("[hypr-canvas] drag watchdog reset (mods released)\n");
        g_pCanvas->m_panning = false;
        g_pCanvas->m_movingWindow = false;
        g_pCanvas->m_resizingWindow = false;
        g_pCanvas->m_dragWindow = 0;
    }

    if (g_pCanvas && g_pCanvas->m_panning) {
        // Pan: move viewport by mouse delta
        g_pCanvas->offset.x -= e.delta.x / g_pCanvas->zoom;
        g_pCanvas->offset.y -= e.delta.y / g_pCanvas->zoom;
        g_pCanvas->repositionWindows();
        scheduleFrame();
        return;
    }

    if (g_pCanvas && g_pCanvas->m_movingWindow && g_pCanvas->m_dragWindow != 0) {
        auto it = g_pCanvas->m_savedStates.find(g_pCanvas->m_dragWindow);
        if (it != g_pCanvas->m_savedStates.end()) {
            it->second.canvasPos.x += e.delta.x / g_pCanvas->zoom;
            it->second.canvasPos.y += e.delta.y / g_pCanvas->zoom;
            g_pCanvas->repositionWindows();
            scheduleFrame();
            return;
        }
    }

    if (g_pCanvas && g_pCanvas->m_resizingWindow && g_pCanvas->m_dragWindow != 0) {
        auto it = g_pCanvas->m_savedStates.find(g_pCanvas->m_dragWindow);
        if (it != g_pCanvas->m_savedStates.end()) {
            it->second.canvasSize.x = std::max(CCanvas::MIN_WINDOW_W, it->second.canvasSize.x + e.delta.x / g_pCanvas->zoom);
            it->second.canvasSize.y = std::max(CCanvas::MIN_WINDOW_H, it->second.canvasSize.y + e.delta.y / g_pCanvas->zoom);
            g_pCanvas->repositionWindows();
            scheduleFrame();
            return;
        }
    }

    auto original = (onMouseMovedFn)g_pCanvas->m_mouseMovedHook->m_original;
    original(self, e);
}

// --- Dispatchers ---

SDispatchResult dispatchReset(std::string args) {
    if (g_pCanvas && g_pCanvas->workspaceChanged())
        g_pCanvas->resetForWorkspaceChange();

    if (g_pCanvas && g_pCanvas->active) {
        g_pCanvas->exit();
        logf("[hypr-canvas] exit canvas mode\n");
        scheduleFrame();
    }
    return {};
}

SDispatchResult dispatchPan(std::string args) {
    if (!g_pCanvas)
        return {};

    if (g_pCanvas->workspaceChanged())
        g_pCanvas->resetForWorkspaceChange();

    Vector2D delta = {0, 0};
    if (args == "left")       delta.x = CCanvas::PAN_STEP;
    else if (args == "right") delta.x = -CCanvas::PAN_STEP;
    else if (args == "up")    delta.y = CCanvas::PAN_STEP;
    else if (args == "down")  delta.y = -CCanvas::PAN_STEP;
    else
        return {};

    if (!g_pCanvas->active)
        g_pCanvas->enter();

    g_pCanvas->offset.x += delta.x / g_pCanvas->zoom;
    g_pCanvas->offset.y += delta.y / g_pCanvas->zoom;
    g_pCanvas->repositionWindows();
    logf("[hypr-canvas] pan %s → offset=(%.1f, %.1f)\n",
         args.c_str(), g_pCanvas->offset.x, g_pCanvas->offset.y);
    scheduleFrame();
    return {};
}

SDispatchResult dispatchZoom(std::string args) {
    if (!g_pCanvas)
        return {};

    if (g_pCanvas->workspaceChanged())
        g_pCanvas->resetForWorkspaceChange();

    auto mon = Desktop::focusState()->monitor();
    if (!mon) return {};

    const auto monSize = mon->m_transformedSize;
    const Vector2D center = {monSize.x / 2.0, monSize.y / 2.0};

    double newZoom = g_pCanvas->zoom;
    if (args == "in")
        newZoom *= CCanvas::ZOOM_STEP;
    else if (args == "out")
        newZoom /= CCanvas::ZOOM_STEP;
    else
        return {};

    if (!g_pCanvas->active)
        g_pCanvas->enter();

    g_pCanvas->applyZoom(newZoom, center);
    g_pCanvas->repositionWindows();
    logf("[hypr-canvas] zoom %s → %.3f\n", args.c_str(), g_pCanvas->zoom);
    scheduleFrame();
    return {};
}

SDispatchResult dispatchToggle(std::string args) {
    if (!g_pCanvas) return {};

    if (g_pCanvas->workspaceChanged())
        g_pCanvas->resetForWorkspaceChange();

    if (g_pCanvas->active) {
        g_pCanvas->exit();
        logf("[hypr-canvas] canvas OFF\n");
    } else {
        g_pCanvas->enter();
        logf("[hypr-canvas] canvas ON\n");
    }
    scheduleFrame();
    return {};
}

// --- Hook helper ---

static CFunctionHook* hookByName(const std::string& name, void* dest) {
    auto fns = HyprlandAPI::findFunctionsByName(PHANDLE, name);
    logf("[hypr-canvas] %s: %zu matches\n", name.c_str(), fns.size());
    if (fns.empty()) return nullptr;
    auto hook = HyprlandAPI::createFunctionHook(PHANDLE, fns[0].address, dest);
    if (hook && hook->hook())
        logf("[hypr-canvas] hooked %s\n", name.c_str());
    return hook;
}

// --- Constructor / Destructor ---

CCanvas::CCanvas() {
    m_mouseWheelHook  = hookByName("onMouseWheel", (void*)&hkOnMouseWheel);
    m_mouseButtonHook = hookByName("onMouseButton", (void*)&hkOnMouseButton);
    m_mouseMovedHook  = hookByName("onMouseMoved", (void*)&hkOnMouseMoved);
    logf("[hypr-canvas] initialized (VXWM mode — no render hooks)\n");
}

CCanvas::~CCanvas() {
    // Restore windows if still in canvas mode
    if (active)
        exit();

    if (m_mouseWheelHook)
        HyprlandAPI::removeFunctionHook(PHANDLE, m_mouseWheelHook);
    if (m_mouseButtonHook)
        HyprlandAPI::removeFunctionHook(PHANDLE, m_mouseButtonHook);
    if (m_mouseMovedHook)
        HyprlandAPI::removeFunctionHook(PHANDLE, m_mouseMovedHook);
}

// --- Canvas mode enter/exit ---

void CCanvas::enter() {
    auto mon = Desktop::focusState()->monitor();
    if (!mon)
        return;

    active = true;
    zoom = 1.0;
    offset = {0, 0};
    m_canvasWorkspace = mon->activeWorkspaceID();
    m_savedStates.clear();
    m_panning = false;
    m_movingWindow = false;
    m_resizingWindow = false;
    m_dragWindow = 0;

    // Save all window positions and float them
    for (auto& w : g_pCompositor->m_windows) {
        if (!w || w->isHidden() || !w->m_isMapped || !windowOnCanvasWorkspace(w))
            continue;

        uint64_t id = (uint64_t)w.get();
        const Vector2D currentPos  = w->m_realPosition->value();
        const Vector2D currentSize = w->m_realSize->value();

        SWindowState state;
        state.restorePos  = currentPos;
        state.restoreSize = currentSize;
        state.wasFloating = w->m_isFloating;

        if (w->m_isFloating) {
            state.canvasPos  = currentPos;
            state.canvasSize = currentSize;
        } else {
            // Normalize tiled windows into independent canvas cards while
            // preserving their visual center. This avoids the "everything is
            // still tiled together" feeling when we zoom the canvas.
            const Vector2D center = {
                currentPos.x + currentSize.x / 2.0,
                currentPos.y + currentSize.y / 2.0
            };
            state.canvasSize = {CANVAS_REF_W, CANVAS_REF_H};
            state.canvasPos = {
                center.x - state.canvasSize.x / 2.0,
                center.y - state.canvasSize.y / 2.0
            };
        }
        m_savedStates[id] = state;

        g_pHyprRenderer->damageWindow(w);

        // Float the window if it's tiled
        if (!w->m_isFloating) {
            w->m_isFloating = true;
        }

        w->m_realPosition->setValueAndWarp(state.canvasPos);
        w->m_realSize->setValueAndWarp(state.canvasSize);
        w->m_position = state.canvasPos;
        w->m_size = state.canvasSize;
        g_pHyprRenderer->damageWindow(w);
    }

    logf("[hypr-canvas] entered canvas mode on workspace %ld, saved %zu windows\n",
         (long)m_canvasWorkspace, m_savedStates.size());
}

void CCanvas::exit() {
    // Restore all saved window positions and float state
    for (auto& w : g_pCompositor->m_windows) {
        if (!w || w->isHidden() || !w->m_isMapped || !windowOnCanvasWorkspace(w))
            continue;

        uint64_t id = (uint64_t)w.get();
        auto it = m_savedStates.find(id);
        if (it == m_savedStates.end())
            continue;

        const auto& saved = it->second;
        g_pHyprRenderer->damageWindow(w);
        w->m_realPosition->setValueAndWarp(saved.restorePos);
        w->m_realSize->setValueAndWarp(saved.restoreSize);
        w->m_position = saved.restorePos;
        w->m_size = saved.restoreSize;

        if (!saved.wasFloating) {
            w->m_isFloating = false;
        }
        g_pHyprRenderer->damageWindow(w);
    }

    m_savedStates.clear();
    active = false;
    zoom = 1.0;
    offset = {0, 0};
    m_canvasWorkspace = WORKSPACE_INVALID;
    m_panning = false;
    m_movingWindow = false;
    m_resizingWindow = false;
    m_dragWindow = 0;

    // Force relayout to snap windows back to tiling
    auto mon = Desktop::focusState()->monitor();
    if (mon)
        g_layoutManager->recalculateMonitor(mon);

    logf("[hypr-canvas] exited canvas mode, restored windows\n");
}

// --- Reposition all windows based on zoom+offset ---

void CCanvas::repositionWindows() {
    for (auto& w : g_pCompositor->m_windows) {
        if (!w || w->isHidden() || !w->m_isMapped || !windowOnCanvasWorkspace(w))
            continue;

        uint64_t id = (uint64_t)w.get();
        auto it = m_savedStates.find(id);
        if (it == m_savedStates.end())
            continue;

        const auto& saved = it->second;

        // Canvas-to-screen: screenPos = (canvasPos - offset) * zoom
        Vector2D newPos = {
            (saved.canvasPos.x - offset.x) * zoom,
            (saved.canvasPos.y - offset.y) * zoom
        };
        Vector2D newSize = {
            saved.canvasSize.x * zoom,
            saved.canvasSize.y * zoom
        };

        // Damage both the old and new geometry to avoid stale-size ghosts.
        g_pHyprRenderer->damageWindow(w);
        w->m_realPosition->setValueAndWarp(newPos);
        w->m_realSize->setValueAndWarp(newSize);
        w->m_position = newPos;
        w->m_size = newSize;
        g_pHyprRenderer->damageWindow(w);
    }
}

bool CCanvas::workspaceChanged() const {
    if (!active)
        return false;

    auto mon = Desktop::focusState()->monitor();
    if (!mon)
        return false;

    return mon->activeWorkspaceID() != m_canvasWorkspace;
}

void CCanvas::resetForWorkspaceChange() {
    if (!active)
        return;

    auto mon = Desktop::focusState()->monitor();
    const auto currentWorkspace = mon ? mon->activeWorkspaceID() : WORKSPACE_INVALID;
    logf("[hypr-canvas] workspace change detected (%ld -> %ld), resetting canvas session\n",
         (long)m_canvasWorkspace, (long)currentWorkspace);
    exit();
}

bool CCanvas::windowOnCanvasWorkspace(const SP<Desktop::View::CWindow>& window) const {
    if (!window || !window->m_workspace)
        return false;

    return window->workspaceID() == m_canvasWorkspace;
}

// --- Zoom with cursor anchoring ---

void CCanvas::applyZoom(double newZoom, const Vector2D& anchorScreen) {
    // anchorScreen = point under cursor in screen coords
    // Find what canvas point is under cursor: canvasPoint = offset + anchorScreen / zoom
    const Vector2D anchorCanvas = {
        offset.x + anchorScreen.x / zoom,
        offset.y + anchorScreen.y / zoom
    };

    zoom = std::clamp(newZoom, ZOOM_MIN, ZOOM_MAX);

    // Adjust offset so anchorCanvas stays under cursor:
    // anchorScreen = (anchorCanvas - offset) * zoom
    // offset = anchorCanvas - anchorScreen / zoom
    offset = {
        anchorCanvas.x - anchorScreen.x / zoom,
        anchorCanvas.y - anchorScreen.y / zoom
    };
}

void CCanvas::pan(const Vector2D& delta) {
    offset.x += delta.x / zoom;
    offset.y += delta.y / zoom;
}

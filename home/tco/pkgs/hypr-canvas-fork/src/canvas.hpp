#pragma once

#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/plugins/HookSystem.hpp>
#include <hyprland/src/helpers/math/Math.hpp>
#include <hyprland/src/devices/IPointer.hpp>
#include <hyprutils/memory/SharedPtr.hpp>

#include <map>

// Saved window state for canvas mode
struct SWindowState {
    Vector2D restorePos;
    Vector2D restoreSize;
    Vector2D canvasPos;
    Vector2D canvasSize;
    bool     wasFloating;
};

class CCanvas {
  public:
    CCanvas();
    ~CCanvas();

    // Canvas state
    double   zoom   = 1.0;
    Vector2D offset = {0, 0};   // canvas-space offset of viewport origin
    bool     active = false;     // canvas mode on/off

    // Saved window states (keyed by window address)
    std::map<uint64_t, SWindowState> m_savedStates;

    // Enter/exit canvas mode
    void enter();
    void exit();

    // Apply zoom (cursor-anchored)
    void applyZoom(double newZoom, const Vector2D& anchorScreen);

    // Pan by delta in screen pixels
    void pan(const Vector2D& delta);

    // Reposition all windows based on current zoom+offset
    void repositionWindows();

    // Constants
    static constexpr double ZOOM_MIN  = 0.1;
    static constexpr double ZOOM_MAX  = 2.0;
    static constexpr double ZOOM_STEP = 1.03;
    static constexpr double PAN_STEP  = 120.0;
    static constexpr double CANVAS_REF_W = 939.0;
    static constexpr double CANVAS_REF_H = 1136.0;
    static constexpr double MIN_WINDOW_W = 160.0;
    static constexpr double MIN_WINDOW_H = 120.0;

    // Panning state
    bool m_panning = false;
    bool m_movingWindow = false;
    bool m_resizingWindow = false;
    uint64_t m_dragWindow = 0;

    // Hooks — only mouse input hooks needed (no render hooks!)
    CFunctionHook* m_mouseWheelHook  = nullptr;
    CFunctionHook* m_mouseButtonHook = nullptr;
    CFunctionHook* m_mouseMovedHook  = nullptr;
};

inline std::unique_ptr<CCanvas> g_pCanvas;
inline HANDLE                   PHANDLE = nullptr;

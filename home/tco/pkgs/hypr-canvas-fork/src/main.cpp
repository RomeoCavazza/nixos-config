#include "canvas.hpp"

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

// Dispatcher declarations (defined in canvas.cpp)
extern SDispatchResult dispatchToggle(std::string args);
extern SDispatchResult dispatchReset(std::string args);
extern SDispatchResult dispatchPan(std::string args);
extern SDispatchResult dispatchZoom(std::string args);

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    HyprlandAPI::addDispatcherV2(PHANDLE, "canvas:toggle", dispatchToggle);
    HyprlandAPI::addDispatcherV2(PHANDLE, "canvas:reset",  dispatchReset);
    HyprlandAPI::addDispatcherV2(PHANDLE, "canvas:pan",    dispatchPan);
    HyprlandAPI::addDispatcherV2(PHANDLE, "canvas:zoom",   dispatchZoom);

    g_pCanvas = std::make_unique<CCanvas>();

    return {"hypr-canvas", "VXWM-style infinite canvas — physically moves windows", "Aaron+tco", "0.3"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    g_pCanvas.reset();
}

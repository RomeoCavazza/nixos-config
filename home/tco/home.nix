{ config, pkgs, lib, inputs, ... }:
let
  mkOut = config.lib.file.mkOutOfStoreSymlink;

  hyprland-pkg = inputs.hyprland.packages.${pkgs.system}.hyprland;
  # Deterministic patched Render.cpp for v0.54.2
  patchedRenderCpp = pkgs.writeText "Render.cpp" (builtins.readFile ./pkgs/hyprspace/Render.cpp);

  # Hyprspace Patched Build (v0.54.2 Deterministic Edition)
  patchedHyprspace = inputs.hyprspace.packages.${pkgs.system}.Hyprspace.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.perl ];
    postPatch = (old.postPatch or "") + ''
      # 1. Update Globals.hpp with Edition v33 shim
      sed -i '/typedef void (\*tRenderWindow)/d' src/Globals.hpp
      sed -i '/typedef void (\*tRenderLayer)/d' src/Globals.hpp
      sed -i '/void\* pRenderWindow/d' src/Globals.hpp
      sed -i '/void\* pRenderLayer/d' src/Globals.hpp
      sed -i '/plugins\/PluginAPI.hpp/a #include <hyprland/src/event/EventBus.hpp>\n#include <hyprland/src/layout/LayoutManager.hpp>\n#include <hyprland/src/managers/input/InputManager.hpp>\n#include <hyprland/src/helpers/time/Time.hpp>\n#include <hyprland/src/render/Renderer.hpp>\ntypedef void (*tRenderWindow)(void*, PHLWINDOW, PHLMONITOR, const Time::steady_tp&, bool, eRenderPassMode, bool, bool);\ntypedef void (*tRenderLayer)(void*, PHLLS, PHLMONITOR, const Time::steady_tp&, bool, bool);\ntypedef void (*tRenderWorkspace)(void*, PHLMONITOR, PHLWORKSPACE, const Time::steady_tp&, const Hyprutils::Math::CBox&);\ninline void* pRenderWindow = nullptr;\ninline void* pRenderLayer = nullptr;\ninline void* pRenderWorkspace = nullptr;\ninline PHLWINDOWREF g_ovCurrentlyDraggedWindow;\ninline eMouseBindMode g_ovDragMode;\n#define MOUSE_BIND_DRAG MBIND_MOVE\n#define RENDER_STAGE_POST_WINDOW RENDER_POST_WINDOWS' src/Globals.hpp
      sed -i 's/managers\/LayoutManager.hpp/layout\/LayoutManager.hpp/' src/Globals.hpp

      # 2. Deterministic replacement of Render.cpp
      cp ${patchedRenderCpp} src/Render.cpp

      # 3. Update Function Signatures in main.cpp
      sed -i 's/void onRender(void\* thisptr, SCallbackInfo\& info, std::any args)/void onRender(eRenderStage renderStage)/' src/main.cpp
      sed -i 's/void onWorkspaceChange(void\* thisptr, SCallbackInfo\& info, std::any args)/void onWorkspaceChange(PHLWORKSPACE pWorkspace)/' src/main.cpp
      sed -i 's/void onMouseButton(void\* thisptr, SCallbackInfo\& info, std::any args)/void onMouseButton(IPointer::SButtonEvent e, Event::SCallbackInfo\& info)/' src/main.cpp
      sed -i 's/void onMouseAxis(void\* thisptr, SCallbackInfo\& info, std::any args)/void onMouseAxis(IPointer::SAxisEvent e, Event::SCallbackInfo\& info)/' src/main.cpp
      sed -i 's/void onSwipeBegin(void\* thisptr, SCallbackInfo\& info, std::any args)/void onSwipeBegin(IPointer::SSwipeBeginEvent e, Event::SCallbackInfo\& info)/' src/main.cpp
      sed -i 's/void onSwipeUpdate(void\* thisptr, SCallbackInfo\& info, std::any args)/void onSwipeUpdate(IPointer::SSwipeUpdateEvent e, Event::SCallbackInfo\& info)/' src/main.cpp
      sed -i 's/void onSwipeEnd(void\* thisptr, SCallbackInfo\& info, std::any args)/void onSwipeEnd(IPointer::SSwipeEndEvent e, Event::SCallbackInfo\& info)/' src/main.cpp
      sed -i 's/void onKeyPress(void\* thisptr, SCallbackInfo\& info, std::any args)/void onKeyPress(IKeyboard::SKeyEvent e, Event::SCallbackInfo\& info)/' src/main.cpp
      sed -i 's/void onTouchDown(void\* thisptr, SCallbackInfo\& info, std::any args)/void onTouchDown(ITouch::SDownEvent e, Event::SCallbackInfo\& info)/' src/main.cpp
      sed -i 's/void onTouchMove(void\* thisptr, SCallbackInfo\& info, std::any args)/void onTouchMove(ITouch::SMotionEvent e, Event::SCallbackInfo\& info)/' src/main.cpp
      sed -i 's/void onTouchUp(void\* thisptr, SCallbackInfo\& info, std::any args)/void onTouchUp(ITouch::SUpEvent e, Event::SCallbackInfo\& info)/' src/main.cpp

      # 4. Clean up any_casts and Fix onRender Logic
      sed -i '/void\* pRenderWindow/d' src/main.cpp
      sed -i '/void\* pRenderLayer/d' src/main.cpp
      
      # Correct the stage check in onRender (v0.54.2)
      # RENDER_POST_WINDOWS (value 4) = once per frame after all windows, pre-overlay
      # RENDER_POST_WINDOW  (value 9) = fires for EVERY individual window render (WRONG)
      sed -i '/void onRender(eRenderStage renderStage) {/a \    if (renderStage != RENDER_POST_WINDOWS \&\& g_ovDragMode != MOUSE_BIND_DRAG) return;' src/main.cpp
      # Delete the old broken any_cast checks
      sed -i '/std::any_cast<eRenderStage>(args)/d' src/main.cpp
      sed -i '/std::any_cast<PHLWORKSPACE>(args)/d' src/main.cpp
      sed -i '/std::any_cast<IPointer::SButtonEvent>(args)/d' src/main.cpp
      sed -i '/std::any_cast<IPointer::SSwipeBeginEvent>(args)/d' src/main.cpp
      sed -i '/std::any_cast<IPointer::SSwipeUpdateEvent>(args)/d' src/main.cpp
      sed -i '/std::any_cast<IPointer::SSwipeEndEvent>(args)/d' src/main.cpp
      sed -i '/std::any_cast<ITouch::SDownEvent>(args)/d' src/main.cpp
      sed -i '/std::any_cast<ITouch::SMotionEvent>(args)/d' src/main.cpp
      sed -i '/std::any_cast<ITouch::SUpEvent>(args)/d' src/main.cpp

      # Fix onRender call with steady_tp
      sed -i '/pRenderWindow/s/&time/std::chrono::steady_clock::now()/' src/main.cpp
      sed -i 's/getWidgetForMonitor(g_pHyprOpenGL->m_renderData.pMonitor)/getWidgetForMonitor(g_pHyprOpenGL->m_renderData.pMonitor.lock())/' src/main.cpp
      
      # Input Event Argument Mapping
      sed -i '/std::any_cast<IPointer::SAxisEvent>/c\    const auto e = e_arg;' src/main.cpp
      sed -i 's/void onMouseAxis(IPointer::SAxisEvent e, Event::SCallbackInfo\& info)/void onMouseAxis(IPointer::SAxisEvent e_arg, Event::SCallbackInfo\& info)/' src/main.cpp
      sed -i '/std::any_cast<IKeyboard::SKeyEvent>/c\    const auto e = e_arg;' src/main.cpp
      sed -i '/std::any_cast<SP<IKeyboard>>/c\    const auto k = g_pSeatManager->m_keyboard.lock();' src/main.cpp
      sed -i 's/void onKeyPress(IKeyboard::SKeyEvent e, Event::SCallbackInfo\& info)/void onKeyPress(IKeyboard::SKeyEvent e_arg, Event::SCallbackInfo\& info)/' src/main.cpp

      # Replace g_pInputManager trickery with our ov shim (Global across all src)
      sed -i 's/g_pInputManager->m_currentlyDraggedWindow/g_ovCurrentlyDraggedWindow/g' src/*.cpp
      sed -i 's/g_pInputManager->m_dragMode/g_ovDragMode/g' src/*.cpp
      
      # Fix Input.cpp drag state (PR 223)
      sed -i 's/g_ovCurrentlyDraggedWindow = g_layoutManager->dragController()->target()->window()/g_ovCurrentlyDraggedWindow = g_layoutManager->dragController()->target() ? g_layoutManager->dragController()->target()->window() : PHLWINDOWREF{}/g' src/Input.cpp
      
      # Fix g_pLayoutManager and recalculateMonitor (v0.54.2 API)
      sed -i 's/g_pLayoutManager->getCurrentLayout()->recalculateMonitor(ownerID)/g_layoutManager->recalculateMonitor(g_pCompositor->getMonitorFromID(ownerID))/g' src/Layout.cpp
      sed -i 's/g_pLayoutManager->getCurrentLayout()->onEndDragWindow()/g_layoutManager->endDragTarget()/g' src/Input.cpp
      # Catch any remaining g_pLayoutManager
      sed -i 's/g_pLayoutManager/g_layoutManager/g' src/*.cpp

      # [NEW FIXES]
      # 5. Reset reservedArea manually before arrangeLayersForMonitor
      sed -i '/g_pHyprRenderer->arrangeLayersForMonitor(ownerID);/i \    pMonitor->m_reservedArea = Desktop::CReservedArea();' src/Layout.cpp
      
      # 5. Fix Globals naming (v0.54.2 convention)
      # 6. Migrate Registration to Event::bus()
      sed -i 's/g_pConfigReloadHook = HyprlandAPI::registerCallbackDynamic(pHandle, "configReloaded", \[&\] (void\* thisptr, SCallbackInfo\& info, std::any data) { reloadConfig(); });/static auto p1 = Event::bus()->m_events.config.reloaded.listen([]() { reloadConfig(); });/' src/main.cpp
      sed -i 's/g_pRenderHook = HyprlandAPI::registerCallbackDynamic(pHandle, "render", onRender);/static auto p2 = Event::bus()->m_events.render.stage.listen(onRender);/' src/main.cpp
      sed -i 's/g_pOpenLayerHook = HyprlandAPI::registerCallbackDynamic(pHandle, "openLayer", \[&\] (void\* thisptr, SCallbackInfo\& info, std::any data) { g_layoutNeedsRefresh = true; });/static auto p3 = Event::bus()->m_events.layer.opened.listen([](PHLLS ls) { g_layoutNeedsRefresh = true; });/' src/main.cpp
      sed -i 's/g_pCloseLayerHook = HyprlandAPI::registerCallbackDynamic(pHandle, "closeLayer", \[&\] (void\* thisptr, SCallbackInfo\& info, std::any data) { g_layoutNeedsRefresh = true; });/static auto p4 = Event::bus()->m_events.layer.closed.listen([](PHLLS ls) { g_layoutNeedsRefresh = true; });/' src/main.cpp
      sed -i 's/g_pMouseButtonHook = HyprlandAPI::registerCallbackDynamic(pHandle, "mouseButton", onMouseButton);/static auto p5 = Event::bus()->m_events.input.mouse.button.listen(onMouseButton);/' src/main.cpp
      sed -i 's/g_pMouseAxisHook = HyprlandAPI::registerCallbackDynamic(pHandle, "mouseAxis", onMouseAxis);/static auto p6 = Event::bus()->m_events.input.mouse.axis.listen(onMouseAxis);/' src/main.cpp
      sed -i 's/g_pTouchDownHook = HyprlandAPI::registerCallbackDynamic(pHandle, "touchDown", onTouchDown);/static auto p7 = Event::bus()->m_events.input.touch.down.listen(onTouchDown);/' src/main.cpp
      sed -i 's/g_pTouchMoveHook = HyprlandAPI::registerCallbackDynamic(pHandle, "touchMove", onTouchMove);/static auto p8 = Event::bus()->m_events.input.touch.motion.listen(onTouchMove);/' src/main.cpp
      sed -i 's/g_pTouchUpHook = HyprlandAPI::registerCallbackDynamic(pHandle, "touchUp", onTouchUp);/static auto p9 = Event::bus()->m_events.input.touch.up.listen(onTouchUp);/' src/main.cpp
      sed -i 's/g_pSwipeBeginHook = HyprlandAPI::registerCallbackDynamic(pHandle, "swipeBegin", onSwipeBegin);/static auto p10 = Event::bus()->m_events.gesture.swipe.begin.listen(onSwipeBegin);/' src/main.cpp
      sed -i 's/g_pSwipeUpdateHook = HyprlandAPI::registerCallbackDynamic(pHandle, "swipeUpdate", onSwipeUpdate);/static auto p11 = Event::bus()->m_events.gesture.swipe.update.listen(onSwipeUpdate);/' src/main.cpp
      sed -i 's/g_pSwipeEndHook = HyprlandAPI::registerCallbackDynamic(pHandle, "swipeEnd", onSwipeEnd);/static auto p12 = Event::bus()->m_events.gesture.swipe.end.listen(onSwipeEnd);/' src/main.cpp
      sed -i 's/g_pKeyPressHook = HyprlandAPI::registerCallbackDynamic(pHandle, "keyPress", onKeyPress);/static auto p13 = Event::bus()->m_events.input.keyboard.key.listen(onKeyPress);/' src/main.cpp
      sed -i 's/g_pSwitchWorkspaceHook = HyprlandAPI::registerCallbackDynamic(pHandle, "workspace", onWorkspaceChange);/static auto p14 = Event::bus()->m_events.workspace.active.listen(onWorkspaceChange);/' src/main.cpp
      sed -i 's/g_pAddMonitorHook = HyprlandAPI::registerCallbackDynamic(pHandle, "monitorAdded", \[&\] (void\* thisptr, SCallbackInfo\& info, std::any data) { registerMonitors(); });/static auto p15 = Event::bus()->m_events.monitor.added.listen([](PHLMONITOR m) { registerMonitors(); });/' src/main.cpp
      
      # 7. Granular Renderer Discovery (renderWindow) - v0.54.2 Final Sync
      sed -i '/void\* hyprspaceFindFunc/d' src/main.cpp
      sed -i '/tRenderWindow/d' src/main.cpp
      cat >> src/main.cpp <<EOF
#include <dlfcn.h>
#include <hyprland/src/render/Renderer.hpp>
void* hyprspaceFindFunc(HANDLE inHandle, const std::string func, const std::string sym, const std::string mangled) {
    // 1. Try finding by name using the plugin's handle (as in PR 223)
    auto funcSearch = HyprlandAPI::findFunctionsByName(inHandle, func);
    for (auto& f : funcSearch) {
        if (f.demangled.find(sym) != std::string::npos) {
            HyprlandAPI::addNotification(inHandle, "[API] Found: " + func, CHyprColor(0, 1, 0, 1), 2000);
            return f.address;
        }
    }

    // 2. Try dlsym on the process itself
    void* handle = dlopen(NULL, RTLD_LAZY);
    void* addr = dlsym(handle, mangled.c_str());
    if (addr) {
        HyprlandAPI::addNotification(inHandle, "[DLSYM] Found: " + func, CHyprColor(0, 1, 0, 1), 2000);
        dlclose(handle);
        return addr;
    }
    if (handle) dlclose(handle);

    // 3. Exhaustive search in ALL functions
    auto allFuncs = HyprlandAPI::findFunctionsByName(inHandle, "");
    for (auto& f : allFuncs) {
        if (f.demangled.find(sym) != std::string::npos) {
            HyprlandAPI::addNotification(inHandle, "[ALL] Found: " + func, CHyprColor(0.5, 1, 0.5, 1), 2000);
            return f.address;
        }
    }

    HyprlandAPI::addNotification(inHandle, "FATAL: " + func + " NOT FOUND", CHyprColor(1, 0, 0, 1), 10000);
    return nullptr;
}
EOF
      sed -i '/plugins\/PluginAPI.hpp/a #include <hyprutils/utils/ScopeGuard.hpp>\n#include <hyprland/src/render/Renderer.hpp>\nvoid* hyprspaceFindFunc(HANDLE inHandle, const std::string func, const std::string sym, const std::string mangled);' src/main.cpp
      sed -i '/PLUGIN_INIT(HANDLE inHandle) {/a \    pHandle = inHandle;\n    pRenderWindow = hyprspaceFindFunc(inHandle, "renderWindow", "CHyprRenderer::renderWindow", "_ZN13CHyprRenderer12renderWindowEN9Hyprutils6Memory14CSharedPointerIN7Desktop4View7CWindowEEENS2_I8CMonitorEERKNSt6chrono10time_pointINS9_3_V212steady_clockENS9_8durationIlSt5ratioILl1ELl1000000000EEEEEEb15eRenderPassModebb");\n    pRenderLayer = hyprspaceFindFunc(inHandle, "renderLayer", "CHyprRenderer::renderLayer", "_ZN13CHyprRenderer11renderLayerEN9Hyprutils6Memory14CSharedPointerIN7Desktop4View13CLayerSurfaceEEENS2_I8CMonitorEERKNSt6chrono10time_pointINS7_3_V212steady_clockENS7_8durationIlSt5ratioILl1ELl1000000000EEEEEEbb");\n    pRenderWorkspace = hyprspaceFindFunc(inHandle, "renderWorkspace", "CHyprRenderer::renderWorkspace", "_ZN13CHyprRenderer15renderWorkspaceEN9Hyprutils6Memory14CSharedPointerI8CMonitorEENS2_I10CWorkspaceEERKNSt6chrono10time_pointINS8_3_V212steady_clockENS8_8durationIlSt5ratioILl1ELl1000000000EEEEEERKN9Hyprutils4Math4CBoxE");\n    if (pRenderWindow && pRenderWorkspace) { HyprlandAPI::addNotification(inHandle, "[Hyprspace] Desktop Context Active (0.54.2)", CHyprColor(0, 1.0, 0, 1.0), 10000); }\n    else { HyprlandAPI::addNotification(inHandle, "[Hyprspace] ENGINE PARTIAL (FAILSAFE)", CHyprColor(1.0, 0, 0, 1.0), 30000); }' src/main.cpp
      
      # 8. Recursion Guard for onRender (Stable)
      sed -i '/void onRender(eRenderStage renderStage) {/a \    static bool inRender = false;\n    if (inRender) return;\n    inRender = true;\n    Hyprutils::Utils::CScopeGuard x([\&] { inRender = false; });' src/main.cpp

      # 5. Fix Globals naming (v0.54.2 convention)
      sed -i 's/g_pLayoutManager/g_layoutManager/g' src/*.cpp src/*.hpp
      
      # 5.1 Project Exact Reservation Logic (PR 223)
      sed -i '/g_pHyprRenderer->arrangeLayersForMonitor(ownerID);/i \    if (active) { if (!Config::onBottom) pMonitor->m_reservedArea = Desktop::CReservedArea(currentHeight, 0, 0, 0); else pMonitor->m_reservedArea = Desktop::CReservedArea(0, 0, currentHeight, 0); } else { pMonitor->m_reservedArea = Desktop::CReservedArea(); }' src/Layout.cpp

      # 5.2 Fix Config names (KZDKM alignment)
      sed -i 's/panelBaseColor/panelColor/g' src/main.cpp src/*.cpp
      sed -i 's/panelBaseColor/panelColor/g' src/*.hpp

      # 8. Update Overview.hpp with interaction members (PR 223)
      sed -i '/std::vector<std::tuple<int, CBox>> workspaceBoxes;/a \    std::vector<std::tuple<PHLWINDOWREF, Hyprutils::Math::CBox>> windowBoxes;\n    PHLWINDOWREF draggedWindowRef;' src/Overview.hpp

      # 9. Damage individual windows on hide (PR 223 / Commit a88dbaf)
      sed -i '/void CHyprspaceWidget::hide() {/a \    for (auto\& ws : g_pCompositor->getWorkspaces()) { if (!ws || ws->m_monitor->m_id != ownerID) continue; for (auto\& w : g_pCompositor->m_windows) { if (!w || w->m_workspace != ws || !w->m_isMapped) continue; g_pHyprRenderer->damageWindow(w); } }' src/Overview.cpp

      # 10. Fix "coupé en deux" animation bug: hide() set curYOffset in physical px
      #     but draw() uses it as logical px → panel invisible for half the animation.
      #     Remove the incorrect * owner->m_scale multiplier.
      sed -i 's/\*curYOffset = (Config::panelHeight + Config::reservedArea) \* owner->m_scale;/*curYOffset = Config::panelHeight + Config::reservedArea;/' src/Overview.cpp

      # 11. Add damageMonitor callback at animation end (PR #223 commit 586b095)
      #     Without this, windows stay glitched/shrunken after the panel closes.
      sed -i 's/curYOffset->setValueAndWarp(Config::panelHeight);/curYOffset->setValueAndWarp(Config::panelHeight + Config::reservedArea);\n    curYOffset->setCallbackOnEnd([this](Hyprutils::Memory::CWeakPointer<Hyprutils::Animation::CBaseAnimatedVariable>) {\n        if (!active) {\n            auto owner = getOwner();\n            if (owner) {\n                g_pHyprRenderer->damageMonitor(owner);\n                g_pCompositor->scheduleFrameForMonitor(owner);\n            }\n        }\n    }, false);/' src/Overview.cpp

      # 12. Fix existing setCallbackOnEnd lambda signatures (v0.11.0+)
      sed -i 's/setCallbackOnEnd(\[this\]()/setCallbackOnEnd([this](Hyprutils::Memory::CWeakPointer<Hyprutils::Animation::CBaseAnimatedVariable>)/g' src/*.cpp src/*.hpp
    '';
  });

  hypr-canvas = pkgs.stdenv.mkDerivation {
    pname = "hypr-canvas";
    version = "0.2.0-patched";

    srcs = [];
    dontUnpack = true;

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ hyprland-pkg ] ++ hyprland-pkg.buildInputs;

    buildPhase =
      let srcDir = lib.cleanSource /home/tco/Projects/hypr-canvas;
      in ''
        g++ -shared -fPIC -std=c++2b -O2 \
          $(pkg-config --cflags hyprland pixman-1 libdrm) \
          ${srcDir}/src/main.cpp ${srcDir}/src/canvas.cpp \
          -o hypr-canvas.so
      '';

    installPhase = ''
      mkdir -p $out/lib
      cp hypr-canvas.so $out/lib/
    '';

    meta.description = "Infinite canvas plugin for Hyprland";
  };

  terminal-rain-lightning = pkgs.python3Packages.buildPythonApplication rec {
    pname = "terminal-rain-lightning";
    version = "master";

    src = pkgs.fetchFromGitHub {
      owner = "rmaake1";
      repo = "terminal-rain-lightning";
      rev = "master";
      hash = "sha256-ghMqdEff2VLisCBG+GMZBxw7Ka7Y6KjLsDxwnm1njOQ=";
    };

    format = "pyproject";

    nativeBuildInputs = with pkgs.python3Packages; [
      setuptools
      wheel
    ];

    doCheck = false;
  };

  hyprland-logo-cursor = pkgs.stdenv.mkDerivation {
    pname = "hyprland-logo-cursor";
    version = "master";
    src = pkgs.fetchFromGitHub {
      owner = "hyprcow";
      repo = "hyprland_theme";
      rev = "main";
      sha256 = "0ff8n019n7gapj3yy0rk5f8jg4l3vqjwb72wyikiwsqgcvzi38v6";
    };
    installPhase = ''
      mkdir -p $out/share/icons/Hyprland-Logo
      cp -r * $out/share/icons/Hyprland-Logo/
    '';
  };
in
{
  imports = [
    ./modules/apps/cad.nix
    ./modules/apps/embedded.nix
    ./modules/apps/data.nix
  ];

  home.username = "tco";
  home.homeDirectory = "/home/tco";
  home.stateVersion = "25.05";

  home.sessionPath = [
    "${config.home.homeDirectory}/.lmstudio/bin"
    "${config.home.homeDirectory}/.npm-global/bin"
    "${config.home.homeDirectory}/.local/bin"
  ];

  home.sessionVariables = {
    QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = "kvantum";
    XDG_DATA_DIRS = "$HOME/.local/share:$XDG_DATA_DIRS";
    ELECTRON_OZONE_PLATFORM_HINT = "x11";
  };

  xdg.configFile."fastfetch/config.jsonc".text = ''
    {
        "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
        "logo": {
            "source": "nixos",
            "padding": {
                "top": 1
            },
            "color": {
                "1": "38;2;148;226;213",
                "2": "38;2;148;226;213"
            }
        },
        "display": {
            "separator": " ❯ ",
            "color": {
                "keys": "cyan",
                "title": "cyan"
            }
        },
        "modules": [
            "title",
            "separator",
            "os",
            "host",
            "kernel",
            "uptime",
            "packages",
            "shell",
            "display",
            "de",
            "wm",
            "terminal",
            "cpu",
            "gpu",
            "memory",
            "break",
            "colors"
        ]
    }
  '';

  xdg.enable = true;
  xdg.configFile."hypr/theme/seaglass.conf".source = ../../config/hypr/theme/seaglass.conf;
  xdg.configFile."hypr/theme/hyprchroma.conf".source = ../../config/hypr/theme/hyprchroma.conf;
  xdg.configFile."hypr/theme/rules.conf".source = ../../config/hypr/theme/rules.conf;

  home.file.".config/hypr".source = ../../config/hypr;
  home.file.".config/waybar".source = ../../config/hypr/waybar;
  home.file.".config/rofi".source = ../../config/rofi;
  home.file.".config/foot".source = ../../config/foot;
  home.file.".config/swappy/config".source = ../../config/swappy/config;

  home.file.".local/bin/cursor".source = mkOut "/etc/nixos/config/bin/cursor";

  home.file.".local/bin/antigravity" = {
    force = true;
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      exec /etc/nixos/config/bin/antigravity "$@"
    '';
  };

  home.file.".local/bin/dw-apply" = {
    source = ../../config/bin/dw-apply;
    executable = true;
  };

  home.file.".local/bin/dw-toggle-global" = {
    source = ../../config/bin/dw-toggle-global;
    executable = true;
  };

  home.file.".local/bin/dw-toggle" = {
    source = ../../config/bin/dw-toggle;
    executable = true;
  };

  home.file.".local/bin/dw-daemon" = {
    source = ../../config/bin/dw-daemon;
    executable = true;
  };

  home.file.".local/bin/hypr-plugins-init" = {
    source = ../../config/bin/hypr-plugins-init;
    executable = true;
  };

  home.file.".local/bin/hypr-layout-toggle" = {
    source = ../../config/bin/hypr-layout-toggle;
    executable = true;
  };

  home.file.".local/bin/hypr-close-all" = {
    source = ../../config/bin/hypr-close-all;
    executable = true;
  };

  # FIXME: hyprchroma incompatible with Hyprland v0.54.2 — re-enable when updated
  # home.file.".local/lib/libhypr-darkwindow.so".source =
  #   "${inputs.hyprchroma.packages.${pkgs.system}.default}/lib/libHypr-DarkWindow.so";

  # plugin = $HOME/.local/lib/hypr-canvas.so
  # home.file.".local/lib/hypr-canvas.so".source =
  #   "${hypr-canvas}/lib/hypr-canvas.so";

  home.file.".local/lib/hyprspace.so" = {
    source = "${patchedHyprspace}/lib/libHyprspace.so";
    executable = true;
  };

  # home.file.".local/lib/hyprexpo.so".source =
  #   "${inputs.hyprland-plugins.packages.${pkgs.system}.hyprexpo}/lib/libhyprexpo.so";

  # home.file.".local/lib/hyprtasking.so".source =
  #   "${inputs.hyprtasking.packages.${pkgs.system}.default}/lib/libhyprtasking.so";

  home.packages = with pkgs; [
    bat
    eza
    fd
    fzf
    jq
    ripgrep
    yazi
    home-manager
    superfile
    grim
    slurp
    wf-recorder
    sway-contrib.grimshot
    libnotify
    dockfmt
    nixfmt
    shellcheck
    shfmt
    obs-studio
    zed-editor
    neovim
    git
    lua
    lua-language-server
    luaPackages.lgi
    lazygit
    aider-chat
    desktop-file-utils
    cargo
    openssl
    pkg-config
    rust-analyzer
    rustc
    rustfmt
    black
    isort
    (python3.withPackages (ps: with ps; [ pip pyglet ]))
    typescript-language-server
    vscode-langservers-extracted
    tailwindcss-language-server
    nodejs_22
    pnpm
    yarn
    aspell
    aspellDicts.en
    aspellDicts.en-computers
    aspellDicts.fr
    papirus-icon-theme
    swaynotificationcenter
    cava
    cool-retro-term
    nerd-fonts.symbols-only
    hyprcursor
    rose-pine-hyprcursor
    nerd-fonts.jetbrains-mono
    bibata-cursors
    conky
    adw-gtk3
    gnome-themes-extra
    pywal
    wpgtk
    qt6Packages.qtbase
    qt6Packages.qt6ct
    qt6Packages.qttools
    kdePackages.qtstyleplugin-kvantum
    libsForQt5.qtstyleplugin-kvantum
    socat
    atop
    bottom
    btop
    glances
    htop
    nvitop
    appimage-run
    discord
    spotify
    cbonsai
    cmatrix
    hollywood
    pipes
    sl
    terminal-rain-lightning
  ];

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
    };
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      format = "[░▒▓](#94e2d5)[  ](bg:#94e2d5 fg:#090c0c)[](fg:#94e2d5 bg:#1d2230)$directory[](fg:#1d2230 bg:none)$character";
      directory = {
        style = "fg:#94e2d5 bg:#1d2230";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
      };
      character = {
        success_symbol = "[ ❯](bold #94e2d5)";
        error_symbol = "[ ❯](bold #ff0055)";
      };
    };
  };

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        ms-python.python
        ms-toolsai.jupyter
        ms-vscode.cpptools
        rust-lang.rust-analyzer
        esbenp.prettier-vscode
        jnoortheen.nix-ide
        mkhl.direnv
      ];
      userSettings = {
        "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'Droid Sans Mono', 'monospace'";
        "editor.fontLigatures" = true;
        "nix.enableLanguageServer" = true;
        "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font'";
        "window.titleBarStyle" = "custom";
      };
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "RomeoCavazza";
        email = "romeo.cavazza@gmail.com";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    initExtra = ''
      if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi
      export PATH="$HOME/.lmstudio/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
    '';
    shellAliases = {
      g = "git";
      ll = "eza -l --icons";
      ls = "eza --icons";
      devai = "nix develop /etc/nixos#ai";
      devemb = "nix develop /etc/nixos#embedded";
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
    };
  };

  home.activation.ensureWalFiles =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.cache/wal"
      mkdir -p "$HOME/.config/wal/templates"
      : > "$HOME/.cache/wal/colors-foot.ini"
      : > "$HOME/.cache/wal/colors-hyprland.conf"
      if [ ! -f "$HOME/.config/wal/templates/colors-foot.ini" ]; then
        cat > "$HOME/.config/wal/templates/colors-foot.ini" <<'EOF'
[colors]
background={background.strip}
foreground={foreground.strip}
regular0={color0.strip}
regular1={color1.strip}
regular2={color2.strip}
regular3={color3.strip}
regular4={color4.strip}
regular5={color5.strip}
regular6={color6.strip}
regular7={color7.strip}
bright0={color8.strip}
bright1={color9.strip}
bright2={color10.strip}
bright3={color11.strip}
bright4={color12.strip}
bright5={color13.strip}
bright6={color14.strip}
bright7={color15.strip}
EOF
      fi
      if [ ! -f "$HOME/.config/wal/templates/colors-hyprland.conf" ]; then
        cat > "$HOME/.config/wal/templates/colors-hyprland.conf" <<'EOF'

general {
  col.active_border = rgba({color6.strip}ff)
  col.inactive_border = rgba({color0.strip}aa)
}
EOF
      fi
    '';

  xdg.desktopEntries.cursor = {
    name = "Cursor";
    genericName = "AI Code Editor";
    comment = "Built for AI coding";
    exec = "cursor";
    terminal = false;
    categories = [ "Development" "TextEditor" "IDE" ];
    icon = "/home/tco/.local/share/icons/cursor-icon.png";
  };

  xdg.desktopEntries.antigravity = {
    name = "Antigravity";
    genericName = "IDE";
    comment = "Antigravity IDE";
    exec = "antigravity";
    terminal = false;
    categories = [ "Development" "IDE" ];
  };

  systemd.user.services.dw-daemon = {
    Unit = {
      Description = "Hypr DarkWindow auto-shade daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "%h/.local/bin/dw-daemon";
      Restart = "on-failure";
      RestartSec = 1;
      Environment = [
        "PATH=/run/wrappers/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin:%h/.local/bin:%h/.npm-global/bin:%h/.lmstudio/bin"
        "XDG_CACHE_HOME=%h/.cache"
      ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}

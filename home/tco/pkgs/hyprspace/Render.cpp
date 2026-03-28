#include "Globals.hpp"
#include "Overview.hpp"
#include <algorithm>
#include <any>
#include <chrono>
#include <hyprland/src/helpers/Color.hpp>
#include <hyprland/src/helpers/memory/Memory.hpp>
#include <hyprland/src/helpers/time/Time.hpp>
#include <hyprland/src/render/OpenGL.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/pass/BorderPassElement.hpp>
#include <hyprland/src/render/pass/RectPassElement.hpp>
#include <hyprland/src/render/pass/RendererHintsPassElement.hpp>
#include <hyprutils/math/Box.hpp>
#include <hyprutils/math/Vector2D.hpp>
#include <hyprutils/utils/ScopeGuard.hpp>
#include <vector>

typedef void (*tRenderWorkspace)(void *, PHLMONITOR, PHLWORKSPACE,
                                 const Time::steady_tp &,
                                 const Hyprutils::Math::CBox &);

void renderRect(Hyprutils::Math::CBox box, CHyprColor color) {
  CRectPassElement::SRectData rectdata;
  rectdata.color = color;
  rectdata.box = box;
  g_pHyprRenderer->m_renderPass.add(makeUnique<CRectPassElement>(rectdata));
}

void renderRectWithBlur(Hyprutils::Math::CBox box, CHyprColor color) {
  CRectPassElement::SRectData rectdata;
  rectdata.color = color;
  rectdata.box = box;
  rectdata.blur = true;
  g_pHyprRenderer->m_renderPass.add(makeUnique<CRectPassElement>(rectdata));
}

void renderBorder(Hyprutils::Math::CBox box, CGradientValueData gradient,
                  int size) {
  CBorderPassElement::SBorderData data;
  data.box = box;
  data.grad1 = gradient;
  data.round = 0;
  data.a = 1.f;
  data.borderSize = size;
  g_pHyprRenderer->m_renderPass.add(makeUnique<CBorderPassElement>(data));
}

void CHyprspaceWidget::draw() {
  workspaceBoxes.clear();
  windowBoxes.clear();

  if (!active && !curYOffset->isBeingAnimated())
    return;

  auto owner = getOwner();
  if (!owner)
    return;

  const auto renderTime = std::chrono::steady_clock::now();

  int panelHeight = Config::panelHeight > 0 ? Config::panelHeight : 240;
  int workspaceMargin =
      Config::workspaceMargin >= 0 ? Config::workspaceMargin : 30;
  int reservedArea = Config::reservedArea;

  int bottomInvert = Config::onBottom ? -1 : 1;

  Hyprutils::Math::CBox widgetBox = {
      0,
      (double)(Config::onBottom *
               (owner->m_transformedSize.y -
                (panelHeight + reservedArea) * owner->m_scale)) -
          (bottomInvert * curYOffset->value() * owner->m_scale),
      (double)owner->m_transformedSize.x,
      (double)(panelHeight + reservedArea) * owner->m_scale};

  g_pHyprOpenGL->m_renderData.clipBox =
      Hyprutils::Math::CBox({0, 0}, owner->m_transformedSize);

  if (Config::panelColor.a > 0) {
    if (!Config::disableBlur)
      renderRectWithBlur(widgetBox, Config::panelColor);
    else
      renderRect(widgetBox, Config::panelColor);
  }

  if (Config::panelBorderWidth > 0) {
    Hyprutils::Math::CBox borderBox = {
        widgetBox.x,
        (double)(Config::onBottom ? (owner->m_transformedSize.y) : (0)) +
            (panelHeight + reservedArea - curYOffset->value()) *
                owner->m_scale * bottomInvert,
        (double)owner->m_transformedSize.x,
        (double)Config::panelBorderWidth * owner->m_scale};
    renderRect(borderBox, Config::panelBorderColor);
  }

  g_pHyprRenderer->damageMonitor(owner);
  g_pHyprRenderer->damageMonitor(owner);

  // Collect workspace IDs
  std::vector<int> workspaces;
  int highestID = 5;
  for (auto &ws : g_pCompositor->getWorkspaces()) {
    if (!ws || ws->m_id < 1)
      continue;
    if (ws->monitorID() == owner->m_id || ws->m_monitor.lock() == owner) {
      if (highestID < ws->m_id)
        highestID = ws->m_id;
    }
  }

  for (int i = 1; i <= highestID; i++) {
    workspaces.push_back(i);
  }

  std::sort(workspaces.begin(), workspaces.end());
  workspaces.erase(std::unique(workspaces.begin(), workspaces.end()),
                   workspaces.end());

  int wsCount = workspaces.size();
  if (wsCount == 0)
    return;

  double monitorLogicalW = owner->m_transformedSize.x / owner->m_scale;
  double monitorLogicalH = owner->m_transformedSize.y / owner->m_scale;

  double monitorSizeScaleFactor =
      ((panelHeight - 2 * workspaceMargin) / monitorLogicalH);
  double workspaceBoxW =
      monitorLogicalW * monitorSizeScaleFactor * owner->m_scale;
  double workspaceBoxH =
      monitorLogicalH * monitorSizeScaleFactor * owner->m_scale;
  double workspaceMarginPhys = workspaceMargin * owner->m_scale;
  double workspaceGroupWidth =
      workspaceBoxW * wsCount + workspaceMarginPhys * (wsCount - 1);

  double curWorkspaceRectOffsetX =
      Config::centerAligned ? (widgetBox.w / 2.) - (workspaceGroupWidth / 2.)
                            : workspaceMarginPhys;

  double curWorkspaceRectOffsetY = widgetBox.y + workspaceMarginPhys;

  for (auto wsID : workspaces) {
    auto ws = g_pCompositor->getWorkspaceByID(wsID);
    Hyprutils::Math::CBox physWorkspaceBox = {curWorkspaceRectOffsetX,
                                              curWorkspaceRectOffsetY,
                                              workspaceBoxW, workspaceBoxH};

    // Workspace background + border
    if (ws == owner->m_activeWorkspace) {
      if (Config::workspaceBorderSize >= 1 &&
          Config::workspaceActiveBorder.a > 0)
        renderBorder(physWorkspaceBox,
                     CGradientValueData(Config::workspaceActiveBorder),
                     Config::workspaceBorderSize * owner->m_scale);
      if (!Config::disableBlur)
        renderRectWithBlur(physWorkspaceBox, Config::workspaceActiveBackground);
      else
        renderRect(physWorkspaceBox, Config::workspaceActiveBackground);
    } else {
      if (Config::workspaceBorderSize >= 1 &&
          Config::workspaceInactiveBorder.a > 0)
        renderBorder(physWorkspaceBox,
                     CGradientValueData(Config::workspaceInactiveBorder),
                     Config::workspaceBorderSize * owner->m_scale);
      if (!Config::disableBlur)
        renderRectWithBlur(physWorkspaceBox,
                           Config::workspaceInactiveBackground);
      else
        renderRect(physWorkspaceBox, Config::workspaceInactiveBackground);
    }

    // THE MAGIC: renderWorkspace (RETOUR BUREAU)
    // This function handles background, layers, and windows in a single call.
    if (pRenderWorkspace) {
      if (!ws) {
        // If workspace doesn't exist, we create a temporary pointer to track
        // it? Actually, renderWorkspace needs a PHLWORKSPACE. If it's null, it
        // might just draw the background.
      }

      // We set clipbox for the thumbnail
      g_pHyprOpenGL->m_renderData.clipBox = physWorkspaceBox;

      // renderWorkspace expects physical pixel coordinates relative to monitor.
      (*(tRenderWorkspace)pRenderWorkspace)(g_pHyprRenderer.get(), owner, ws,
                                            renderTime, physWorkspaceBox);

      g_pHyprOpenGL->m_renderData.clipBox =
          Hyprutils::Math::CBox({0, 0}, owner->m_transformedSize);
    }

    // Track windows for interaction (approximate hitboxes)
    if (ws != nullptr) {
      for (auto &w : g_pCompositor->m_windows) {
        if (!w || w->m_workspace != ws)
          continue;
        double wX = curWorkspaceRectOffsetX +
                    ((w->m_realPosition->value().x - owner->m_position.x) *
                     monitorSizeScaleFactor * owner->m_scale);
        double wY = curWorkspaceRectOffsetY +
                    ((w->m_realPosition->value().y - owner->m_position.y) *
                     monitorSizeScaleFactor * owner->m_scale);
        double wW =
            w->m_realSize->value().x * monitorSizeScaleFactor * owner->m_scale;
        double wH =
            w->m_realSize->value().y * monitorSizeScaleFactor * owner->m_scale;
        if (wW > 0 && wH > 0) {
          Hyprutils::Math::CBox inputBox = {wX, wY, wW, wH};
          inputBox.scale(1.0 / owner->m_scale);
          inputBox.x += owner->m_position.x;
          inputBox.y += owner->m_position.y;
          windowBoxes.emplace_back(PHLWINDOWREF(w), inputBox);
        }
      }
    }

    workspaceBoxes.emplace_back(
        std::make_tuple(wsID, physWorkspaceBox.copy()
                                  .scale(1.0 / owner->m_scale)
                                  .translate(owner->m_position)));
    curWorkspaceRectOffsetX += workspaceBoxW + workspaceMarginPhys;
  }

  g_pHyprOpenGL->m_renderData.clipBox = Hyprutils::Math::CBox();
}

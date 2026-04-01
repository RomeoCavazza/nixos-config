#include "Overview.hpp"
#include "Globals.hpp"
#include <hyprland/src/render/pass/RectPassElement.hpp>
#include <hyprland/src/render/pass/RendererHintsPassElement.hpp>
#include <hyprlang.hpp>
#include <hyprutils/utils/ScopeGuard.hpp>


void renderRect(CBox box, CHyprColor color) {
    CRectPassElement::SRectData rectdata;
    rectdata.color = color;
    rectdata.box = box;
    g_pHyprRenderer->m_renderPass.add(makeUnique<CRectPassElement>(rectdata));
}

void renderRectWithBlur(CBox box, CHyprColor color) {
    CRectPassElement::SRectData rectdata;
    rectdata.color = color;
    rectdata.box = box;
    rectdata.blur = true;
    g_pHyprRenderer->m_renderPass.add(makeUnique<CRectPassElement>(rectdata));
}

static CBox insetBox(CBox box, int inset) {
    if (inset <= 0)
        return box;

    box.x += inset;
    box.y += inset;
    box.w -= inset * 2;
    box.h -= inset * 2;
    return box;
}

static CBox pixelSnapBox(CBox box) {
    const double right  = std::round(box.x + box.w);
    const double bottom = std::round(box.y + box.h);

    box.x = std::round(box.x);
    box.y = std::round(box.y);
    box.w = std::max(0.0, right - box.x);
    box.h = std::max(0.0, bottom - box.y);
    return box;
}

void renderBorder(CBox box, CHyprColor color, int size) {
    if (size <= 0 || color.a <= 0.F || box.w <= 0 || box.h <= 0)
        return;

    const double horizontalHeight = std::min<double>(size, box.h);
    const double verticalWidth    = std::min<double>(size, box.w);
    const double verticalHeight   = std::max<double>(box.h - horizontalHeight * 2, 0);

    renderRect({box.x, box.y, box.w, horizontalHeight}, color);
    renderRect({box.x, box.y + box.h - horizontalHeight, box.w, horizontalHeight}, color);

    if (verticalHeight > 0) {
        renderRect({box.x, box.y + horizontalHeight, verticalWidth, verticalHeight}, color);
        renderRect({box.x + box.w - verticalWidth, box.y + horizontalHeight, verticalWidth, verticalHeight}, color);
    }
}

void renderWindowStub(PHLWINDOW pWindow, PHLMONITOR pMonitor, PHLWORKSPACE pWorkspaceOverride, CBox rectOverride, const Time::steady_tp& time) {
    if (!g_renderHooksReady || !pRenderWindow || !pWindow || !pMonitor || !pWorkspaceOverride)
        return;

    SRenderModifData renderModif;

    const auto oWorkspace = pWindow->m_workspace;
    const auto oWorkspaceVisible = pWorkspaceOverride->m_visible;
    const auto oWorkspaceForceRendering = pWorkspaceOverride->m_forceRendering;
    const auto oFullscreen = pWindow->m_fullscreenState;
    const auto oRealPosition = pWindow->m_realPosition->value();
    const auto oSize = pWindow->m_realSize->value();
    const auto oUseNearestNeighbor = pWindow->m_ruleApplicator->nearestNeighbor();
    const auto oPinned = pWindow->m_pinned;
    const auto oFloating = pWindow->m_isFloating;

    if (!(oSize.x > 0) || !(pMonitor->m_scale > 0))
        return;

    const float curScaling = rectOverride.w / (oSize.x * pMonitor->m_scale);
    if (!(curScaling > 0))
        return;

    // using renderModif struct to override the position and scale of windows
    // this will be replaced by matrix transformations in hyprland
    renderModif.modifs.push_back(std::make_pair(SRenderModifData::eRenderModifType::RMOD_TYPE_TRANSLATE, std::any((pMonitor->m_position * pMonitor->m_scale) + (rectOverride.pos() / curScaling) - (oRealPosition * pMonitor->m_scale))));
    renderModif.modifs.push_back(std::make_pair(SRenderModifData::eRenderModifType::RMOD_TYPE_SCALE, std::any(curScaling)));
    renderModif.enabled = true;
    pWindow->m_workspace = pWorkspaceOverride;
    pWorkspaceOverride->m_visible = true;
    pWorkspaceOverride->m_forceRendering = true;
    pWindow->m_fullscreenState = Desktop::View::SFullscreenState{FSMODE_NONE};
    pWindow->m_ruleApplicator->nearestNeighbor().set(false, Desktop::Types::PRIORITY_SET_PROP);
    pWindow->m_isFloating = false;
    pWindow->m_pinned = true;
    pWindow->m_ruleApplicator->rounding().set(pWindow->rounding() * curScaling * pMonitor->m_scale, Desktop::Types::PRIORITY_SET_PROP);

    g_pHyprRenderer->m_renderPass.add(makeUnique<CRendererHintsPassElement>(CRendererHintsPassElement::SData{renderModif}));
    // remove modif as it goes out of scope (wtf is this blackmagic i need to relearn c++)
    Hyprutils::Utils::CScopeGuard x([] {
        g_pHyprRenderer->m_renderPass.add(makeUnique<CRendererHintsPassElement>(CRendererHintsPassElement::SData{SRenderModifData{}}));
        });

    g_pHyprRenderer->damageWindow(pWindow);

    (*(tRenderWindow)pRenderWindow)(g_pHyprRenderer.get(), pWindow, pMonitor, time, true, RENDER_PASS_ALL, false, false);

    // restore values for normal window render
    pWindow->m_workspace = oWorkspace;
    pWorkspaceOverride->m_visible = oWorkspaceVisible;
    pWorkspaceOverride->m_forceRendering = oWorkspaceForceRendering;
    pWindow->m_fullscreenState = oFullscreen;
    pWindow->m_ruleApplicator->rounding().unset(Desktop::Types::PRIORITY_SET_PROP);
    pWindow->m_ruleApplicator->nearestNeighbor().unset(Desktop::Types::PRIORITY_SET_PROP);
    pWindow->m_isFloating = oFloating;
    pWindow->m_pinned = oPinned;
}

void renderLayerStub(PHLLS pLayer, PHLMONITOR pMonitor, CBox rectOverride, const Time::steady_tp& time) {
    if (!g_renderHooksReady || !pRenderLayer || !pLayer || !pMonitor)
        return;

    if (!pLayer->m_mapped || pLayer->m_readyToDelete || !pLayer->m_layerSurface) return;

    Vector2D oRealPosition = pLayer->m_realPosition->value();
    Vector2D oSize = pLayer->m_realSize->value();
    float oAlpha = pLayer->m_alpha->value(); // set to 1 to show hidden top layer
    const auto oFadingOut = pLayer->m_fadingOut;

    if (!(oSize.x > 0))
        return;

    const float curScaling = rectOverride.w / (oSize.x);
    if (!(curScaling > 0))
        return;

    SRenderModifData renderModif;

    renderModif.modifs.push_back(std::make_pair(SRenderModifData::eRenderModifType::RMOD_TYPE_TRANSLATE, std::any(pMonitor->m_position + (rectOverride.pos() / curScaling) - oRealPosition)));
    renderModif.modifs.push_back(std::make_pair(SRenderModifData::eRenderModifType::RMOD_TYPE_SCALE, std::any(curScaling)));
    renderModif.enabled = true;
    pLayer->m_alpha->setValue(1);
    pLayer->m_fadingOut = false;

    g_pHyprRenderer->m_renderPass.add(makeUnique<CRendererHintsPassElement>(CRendererHintsPassElement::SData{renderModif}));
    // remove modif as it goes out of scope (wtf is this blackmagic i need to relearn c++)
    Hyprutils::Utils::CScopeGuard x([] {
        g_pHyprRenderer->m_renderPass.add(makeUnique<CRendererHintsPassElement>(CRendererHintsPassElement::SData{SRenderModifData{}}));
        });

    (*(tRenderLayer)pRenderLayer)(g_pHyprRenderer.get(), pLayer, pMonitor, time, false, false);

    pLayer->m_fadingOut = oFadingOut;
    pLayer->m_alpha->setValue(oAlpha);
}

void renderBackgroundStub(PHLMONITOR pMonitor, CBox rectOverride) {
    if (!g_renderHooksReady || !pRenderBackground || !pMonitor)
        return;

    if (!(pMonitor->m_scale > 0) || !(pMonitor->m_transformedSize.x > 0))
        return;

    const float curScaling = rectOverride.w / pMonitor->m_transformedSize.x;
    if (!(curScaling > 0))
        return;

    SRenderModifData renderModif;
    renderModif.modifs.push_back(std::make_pair(SRenderModifData::eRenderModifType::RMOD_TYPE_TRANSLATE,
        std::any((pMonitor->m_position * pMonitor->m_scale) + (rectOverride.pos() / curScaling) - (pMonitor->m_position * pMonitor->m_scale))));
    renderModif.modifs.push_back(std::make_pair(SRenderModifData::eRenderModifType::RMOD_TYPE_SCALE, std::any(curScaling)));
    renderModif.enabled = true;

    g_pHyprRenderer->m_renderPass.add(makeUnique<CRendererHintsPassElement>(CRendererHintsPassElement::SData{renderModif}));
    Hyprutils::Utils::CScopeGuard x([] {
        g_pHyprRenderer->m_renderPass.add(makeUnique<CRendererHintsPassElement>(CRendererHintsPassElement::SData{SRenderModifData{}}));
    });

    (*(tRenderBackground)pRenderBackground)(g_pHyprRenderer.get(), pMonitor);
}

// NOTE: rects and clipbox positions are relative to the monitor, while damagebox and layers are not, what the fuck? xd
void CHyprspaceWidget::draw() {

    workspaceBoxes.clear();
    windowBoxes.clear();

    PHLWINDOW draggedWindow = draggedWindowRef.lock();

    if (!active && !curYOffset->isBeingAnimated()) return;

    auto owner = getOwner();

    if (!owner) return;

    if (!g_pHyprOpenGL || !g_pHyprRenderer)
        return;
    if (!g_pHyprOpenGL->m_renderData.pCurrentMonData)
        return;

    const auto time = Time::steadyNow();

    g_pHyprOpenGL->m_renderData.pCurrentMonData->blurFBShouldRender = true;

    int bottomInvert = 1;
    if (Config::onBottom) bottomInvert = -1;

    // Background box
    CBox widgetBox = {owner->m_position.x, owner->m_position.y + (Config::onBottom * (owner->m_transformedSize.y - ((Config::panelHeight + Config::reservedArea) * owner->m_scale))) - (bottomInvert * curYOffset->value()), owner->m_transformedSize.x, (Config::panelHeight + Config::reservedArea) * owner->m_scale}; //TODO: update size on monitor change

    // set widgetBox relative to current monitor for rendering panel
    widgetBox.x -= owner->m_position.x;
    widgetBox.y -= owner->m_position.y;

    g_pHyprOpenGL->m_renderData.clipBox = CBox({0, 0}, owner->m_transformedSize);

    // unscaled and relative to owner
    //CBox damageBox = {0, (Config::onBottom * (owner->m_transformedSize.y - ((Config::panelHeight + Config::reservedArea)))) - (bottomInvert * curYOffset->value()), owner->m_transformedSize.x, (Config::panelHeight + Config::reservedArea) * owner->m_scale};

    //owner->addDamage(damageBox);
    g_pHyprRenderer->damageMonitor(owner);
    g_pHyprRenderer->damageMonitor(owner);

    // Always render exactly five workspaces in the overview.
    std::vector<int> workspaces = {1, 2, 3, 4, 5};

    // render workspace boxes
    int wsCount = workspaces.size();
    double monitorSizeScaleFactor = ((Config::panelHeight - 2 * Config::workspaceMargin) / (owner->m_transformedSize.y)) * owner->m_scale; // scale box with panel height
    double workspaceBoxW = owner->m_transformedSize.x * monitorSizeScaleFactor;
    double workspaceBoxH = owner->m_transformedSize.y * monitorSizeScaleFactor;
    double workspaceGroupWidth = workspaceBoxW * wsCount + (Config::workspaceMargin * owner->m_scale) * (wsCount - 1);
    double curWorkspaceRectOffsetX = Config::centerAligned ? workspaceScrollOffset->value() + (widgetBox.w / 2.) - (workspaceGroupWidth / 2.) : workspaceScrollOffset->value() + Config::workspaceMargin;
    double curWorkspaceRectOffsetY = !Config::onBottom ? (((Config::reservedArea + Config::workspaceMargin) * owner->m_scale) - curYOffset->value()) : (owner->m_transformedSize.y - ((Config::reservedArea + Config::workspaceMargin) * owner->m_scale) - workspaceBoxH + curYOffset->value());
    double workspaceOverflowSize = std::max<double>(((workspaceGroupWidth - widgetBox.w) / 2) + (Config::workspaceMargin * owner->m_scale), 0);

    *workspaceScrollOffset = std::clamp<double>(workspaceScrollOffset->goal(), -workspaceOverflowSize, workspaceOverflowSize);

    if (!(workspaceBoxW > 0 && workspaceBoxH > 0)) return;
    for (auto wsID : workspaces) {
        const auto ws = g_pCompositor->getWorkspaceByID(wsID);
        CBox curWorkspaceBox = pixelSnapBox({curWorkspaceRectOffsetX, curWorkspaceRectOffsetY, workspaceBoxW, workspaceBoxH});
        const auto borderSize = std::max(Config::workspaceBorderSize, 0);
        const auto contentBox = pixelSnapBox(insetBox(curWorkspaceBox, borderSize));

        // workspace background rect (NOT background layer)
        bool renderedWallpaper = false;
        if (contentBox.w > 0 && contentBox.h > 0 && pRenderBackground) {
            g_pHyprOpenGL->m_renderData.clipBox = contentBox;
            renderBackgroundStub(owner, contentBox);
            g_pHyprOpenGL->m_renderData.clipBox = CBox();
            renderedWallpaper = true;
        }

        if (ws == owner->m_activeWorkspace) {
            if (!renderedWallpaper && contentBox.w > 0 && contentBox.h > 0 && Config::workspaceActiveBackground.a > 0)
                renderRect(contentBox, Config::workspaceActiveBackground);
            if (!Config::drawActiveWorkspace) {
                curWorkspaceRectOffsetX += workspaceBoxW + (Config::workspaceMargin * owner->m_scale);
                continue;
            }
        }
        else {
            if (!renderedWallpaper && contentBox.w > 0 && contentBox.h > 0 && Config::workspaceInactiveBackground.a > 0)
                renderRect(contentBox, Config::workspaceInactiveBackground);
        }

        // background and bottom layers
        if (!Config::hideBackgroundLayers) {
            for (auto& ls : owner->m_layerSurfaceLayers[0]) {
                CBox layerBox = pixelSnapBox({contentBox.pos() + (ls->m_realPosition->value() - owner->m_position) * monitorSizeScaleFactor, ls->m_realSize->value() * monitorSizeScaleFactor});
                g_pHyprOpenGL->m_renderData.clipBox = contentBox;
                renderLayerStub(ls.lock(), owner, layerBox, time);
                g_pHyprOpenGL->m_renderData.clipBox = CBox();
            }
            for (auto& ls : owner->m_layerSurfaceLayers[1]) {
                CBox layerBox = pixelSnapBox({contentBox.pos() + (ls->m_realPosition->value() - owner->m_position) * monitorSizeScaleFactor, ls->m_realSize->value() * monitorSizeScaleFactor});
                g_pHyprOpenGL->m_renderData.clipBox = contentBox;
                renderLayerStub(ls.lock(), owner, layerBox, time);
                g_pHyprOpenGL->m_renderData.clipBox = CBox();
            }
        }

        if (ws != nullptr) {
            auto renderAndTrackWindow = [&](PHLWINDOW w) {
                if (w == draggedWindow) return; // hide thumbnail while dragging
                double wX = curWorkspaceRectOffsetX + ((w->m_realPosition->value().x - owner->m_position.x) * monitorSizeScaleFactor * owner->m_scale);
                double wY = curWorkspaceRectOffsetY + ((w->m_realPosition->value().y - owner->m_position.y) * monitorSizeScaleFactor * owner->m_scale);
                double wW = w->m_realSize->value().x * monitorSizeScaleFactor * owner->m_scale;
                double wH = w->m_realSize->value().y * monitorSizeScaleFactor * owner->m_scale;
                if (!(wW > 0 && wH > 0)) return;
                CBox curWindowBox = pixelSnapBox({wX, wY, wW, wH});
                g_pHyprOpenGL->m_renderData.clipBox = contentBox;
                renderWindowStub(w, owner, ws, curWindowBox, time);
                g_pHyprOpenGL->m_renderData.clipBox = CBox();
                // record input-coordinate box for drag hit-testing
                CBox inputBox = curWindowBox;
                inputBox.scale(1.0 / owner->m_scale);
                inputBox.x += owner->m_position.x;
                inputBox.y += owner->m_position.y;
                windowBoxes.emplace_back(PHLWINDOWREF(w), inputBox);
            };

            // draw tiled windows
            for (auto& w : g_pCompositor->m_windows) {
                if (!w) continue;
                if (w->m_workspace == ws && !w->m_isFloating)
                    renderAndTrackWindow(w);
            }
            // draw floating windows
            for (auto& w : g_pCompositor->m_windows) {
                if (!w) continue;
                if (w->m_workspace == ws && w->m_isFloating && ws->getLastFocusedWindow() != w)
                    renderAndTrackWindow(w);
            }
            // draw last focused floating window on top
            if (ws->getLastFocusedWindow())
                if (ws->getLastFocusedWindow()->m_isFloating)
                    renderAndTrackWindow(ws->getLastFocusedWindow());
        }

        if (owner->m_activeWorkspace != ws || !Config::hideRealLayers) {
            // this layer is hidden for real workspace when panel is displayed
            if (!Config::hideTopLayers)
                for (auto& ls : owner->m_layerSurfaceLayers[2]) {
                    CBox layerBox = pixelSnapBox({contentBox.pos() + (ls->m_realPosition->value() - owner->m_position) * monitorSizeScaleFactor, ls->m_realSize->value() * monitorSizeScaleFactor});
                    g_pHyprOpenGL->m_renderData.clipBox = contentBox;
                    renderLayerStub(ls.lock(), owner, layerBox, time);
                    g_pHyprOpenGL->m_renderData.clipBox = CBox();
                }

            if (!Config::hideOverlayLayers)
                for (auto& ls : owner->m_layerSurfaceLayers[3]) {
                    CBox layerBox = pixelSnapBox({contentBox.pos() + (ls->m_realPosition->value() - owner->m_position) * monitorSizeScaleFactor, ls->m_realSize->value() * monitorSizeScaleFactor});
                    g_pHyprOpenGL->m_renderData.clipBox = contentBox;
                    renderLayerStub(ls.lock(), owner, layerBox, time);
                    g_pHyprOpenGL->m_renderData.clipBox = CBox();
                }
        }

        // Render borders last so layers and windows cannot eat the right / bottom edge.
        if (ws == owner->m_activeWorkspace) {
            renderBorder(curWorkspaceBox, Config::workspaceActiveBorder, borderSize);
        } else {
            renderBorder(curWorkspaceBox, Config::workspaceInactiveBorder, borderSize);
        }


        // Resets workspaceBox to scaled absolute coordinates for input detection.
        // While rendering is done in pixel coordinates, input detection is done in
        // scaled coordinates, taking into account monitor scaling.
        // Since the monitor position is already given in scaled coordinates,
        // we only have to scale all relative coordinates, then add them to the
        // monitor position to get a scaled absolute position.
        curWorkspaceBox.scale(1 / owner->m_scale);

        curWorkspaceBox.x += owner->m_position.x;
        curWorkspaceBox.y += owner->m_position.y;
        workspaceBoxes.emplace_back(std::make_tuple(wsID, curWorkspaceBox));

        // set the current position to the next workspace box
        curWorkspaceRectOffsetX += workspaceBoxW + Config::workspaceMargin * owner->m_scale;
    }
}

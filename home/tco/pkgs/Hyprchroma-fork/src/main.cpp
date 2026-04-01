// libhypr-darkwindow.so — Hyprchroma v3.3.1 for Hyprland v0.54.2
//
// Per-pixel luminance-based chromakey tint overlay.
// Samples window surface texture to vary tint alpha: strong on dark pixels,
// near-zero on bright pixels. Falls back to uniform CRectPassElement when
// surface texture is unavailable.

#include <algorithm>
#include <any>
#include <chrono>
#include <format>
#include <set>
#include <sstream>
#include <string>
#include <vector>

#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/SharedDefs.hpp>
#include <hyprland/src/debug/log/Logger.hpp>
#include <hyprland/src/defines.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/helpers/Color.hpp>
#include <hyprland/src/helpers/memory/Memory.hpp>
#include <hyprland/src/helpers/signal/Signal.hpp>
#include <hyprland/src/managers/SeatManager.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/protocols/core/Compositor.hpp>
#include <hyprland/src/render/OpenGL.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/pass/BorderPassElement.hpp>
#include <hyprland/src/render/pass/PassElement.hpp>
#include <hyprland/src/render/pass/RectPassElement.hpp>
#include <hyprlang.hpp>
#include <hyprutils/math/Box.hpp>
#include <hyprutils/math/Vector2D.hpp>

using namespace Desktop::View;

static HANDLE pHandle = nullptr;
static CHyprSignalListener g_renderListener;
static CHyprSignalListener g_configListener;
static CHyprSignalListener g_destroyWindowListener;
static CHyprSignalListener g_workspaceListener;

// Glass state
static bool g_globalShaded = true;
static std::set<void *> g_perWindowShaded;

// Render-local guard (reset every frame)
static std::set<void *> g_renderedThisFrame;

struct SConfig {
  float r, g, b, a;
  float protect_brights;
  float bright_threshold;
  float bright_knee;
  float protect_saturated;
  float saturation_threshold;
  float saturation_knee;
  int debug_visualize;
  bool enable_on_fullscreen;
  bool tint_all_surfaces;
  int suspend_on_workspace_switch_ms;
} g_config;

static std::chrono::steady_clock::time_point g_suspendUntil =
    std::chrono::steady_clock::time_point::min();
static bool g_wasSuspendedLastFrame = false;

static void redrawAll();

// ── v3 shader state ──

static GLuint g_chromaProgram = 0;
static GLuint g_chromaProgram_ext = 0;
static GLuint g_chromaVAO = 0;
static GLuint g_chromaVBO = 0;
static bool g_shadersCompiled = false;
static bool g_loggedShaderInit = false;
static bool g_loggedShaderPath = false;
static bool g_loggedFallbackNoSurface = false;
static bool g_loggedFallbackNoTexture = false;
static bool g_loggedFallbackNoExternalProgram = false;
static bool g_notifiedShaderDebugPath = false;
static bool g_notifiedFallbackDebugPath = false;
static bool g_notifiedSurfaceDebugCount = false;

// Uniform locations — sampler2D variant
static GLint g_loc_proj = -1;
static GLint g_loc_windowTex = -1;
static GLint g_loc_tintColor = -1;
static GLint g_loc_tintStrength = -1;
static GLint g_loc_windowAlpha = -1;
static GLint g_loc_topLeft = -1;
static GLint g_loc_fullSize = -1;
static GLint g_loc_radius = -1;
static GLint g_loc_roundingPower = -1;
static GLint g_loc_uvTopLeft = -1;
static GLint g_loc_uvBottomRight = -1;
static GLint g_loc_protectBrights = -1;
static GLint g_loc_brightThreshold = -1;
static GLint g_loc_brightKnee = -1;
static GLint g_loc_protectSaturated = -1;
static GLint g_loc_saturationThreshold = -1;
static GLint g_loc_saturationKnee = -1;
static GLint g_loc_debugVisualize = -1;

// Uniform locations — samplerExternalOES variant
static GLint g_loc_ext_proj = -1;
static GLint g_loc_ext_windowTex = -1;
static GLint g_loc_ext_tintColor = -1;
static GLint g_loc_ext_tintStrength = -1;
static GLint g_loc_ext_windowAlpha = -1;
static GLint g_loc_ext_topLeft = -1;
static GLint g_loc_ext_fullSize = -1;
static GLint g_loc_ext_radius = -1;
static GLint g_loc_ext_roundingPower = -1;
static GLint g_loc_ext_uvTopLeft = -1;
static GLint g_loc_ext_uvBottomRight = -1;
static GLint g_loc_ext_protectBrights = -1;
static GLint g_loc_ext_brightThreshold = -1;
static GLint g_loc_ext_brightKnee = -1;
static GLint g_loc_ext_protectSaturated = -1;
static GLint g_loc_ext_saturationThreshold = -1;
static GLint g_loc_ext_saturationKnee = -1;
static GLint g_loc_ext_debugVisualize = -1;

// ── GLSL shaders ──

static const char *CHROMA_VERT_SRC = R"(
#version 300 es
precision highp float;

uniform mat3 proj;

in vec2 pos;
in vec2 texcoord;

out vec2 v_texcoord;

void main() {
    gl_Position = vec4(proj * vec3(pos, 1.0), 1.0);
    v_texcoord = texcoord;
}
)";

static const char *CHROMA_FRAG_SRC = R"(
#version 300 es
precision highp float;

in vec2 v_texcoord;

uniform sampler2D windowTex;
uniform vec3 tintColor;
uniform float tintStrength;
uniform float windowAlpha;

uniform float radius;
uniform float roundingPower;
uniform vec2 topLeft;
uniform vec2 fullSize;
uniform vec2 uvTopLeft;
uniform vec2 uvBottomRight;
uniform float protectBrights;
uniform float brightThreshold;
uniform float brightKnee;
uniform float protectSaturated;
uniform float saturationThreshold;
uniform float saturationKnee;
uniform int debugVisualize;

layout(location = 0) out vec4 fragColor;

void main() {
    vec2 sampleUV = mix(uvTopLeft, uvBottomRight, v_texcoord);
    vec4 windowPixel = texture(windowTex, sampleUV);
    float contentAlpha = windowPixel.a;
    if (contentAlpha <= 0.001)
        discard;
    float luminance = dot(windowPixel.rgb, vec3(0.2126, 0.7152, 0.0722));
    float maxChannel = max(windowPixel.r, max(windowPixel.g, windowPixel.b));
    float minChannel = min(windowPixel.r, min(windowPixel.g, windowPixel.b));
    float saturation = maxChannel - minChannel;

    float brightProtect = protectBrights * smoothstep(
        brightThreshold - brightKnee,
        brightThreshold + brightKnee,
        luminance
    );
    float saturatedProtect = protectSaturated * smoothstep(
        saturationThreshold - saturationKnee,
        saturationThreshold + saturationKnee,
        saturation
    );
    float preserve = clamp(max(brightProtect, saturatedProtect), 0.0, 1.0);
    float alpha = tintStrength * (1.0 - preserve) * (1.0 - luminance) * windowAlpha * contentAlpha;
    alpha = clamp(alpha, 0.0, 1.0);

    if (debugVisualize == 1) {
        fragColor = vec4(vec3(luminance), 1.0);
        return;
    }
    if (debugVisualize == 2) {
        fragColor = vec4(vec3(saturation), 1.0);
        return;
    }
    if (debugVisualize == 3) {
        fragColor = vec4(vec3(preserve), 1.0);
        return;
    }
    if (debugVisualize == 4) {
        fragColor = vec4(vec3(alpha), 1.0);
        return;
    }
    if (debugVisualize == 5) {
        fragColor = vec4(windowPixel.rgb, 1.0);
        return;
    }

    // Rounding (superellipse distance, matches Hyprland's rounding.glsl)
    if (radius > 0.0) {
        vec2 pixCoord = vec2(gl_FragCoord);
        pixCoord -= topLeft + fullSize * 0.5;
        pixCoord *= vec2(lessThan(pixCoord, vec2(0.0))) * -2.0 + 1.0;
        pixCoord -= fullSize * 0.5 - radius;
        pixCoord += vec2(1.0, 1.0) / fullSize;

        if (pixCoord.x + pixCoord.y > radius) {
            float dist = pow(
                pow(pixCoord.x, roundingPower) + pow(pixCoord.y, roundingPower),
                1.0 / roundingPower
            );
            float smoothingConstant = 3.14159265 / 5.34665792551;
            if (dist > radius + smoothingConstant)
                discard;
            float normalized = 1.0 - smoothstep(
                0.0, 1.0,
                (dist - radius + smoothingConstant) / (smoothingConstant * 2.0)
            );
            alpha *= normalized;
        }
    }

    // Premultiplied alpha (Hyprland blend: GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
    fragColor = vec4(tintColor * alpha, alpha);
}
)";

static const char *CHROMA_FRAG_EXT_SRC = R"(
#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
precision highp float;

in vec2 v_texcoord;

uniform samplerExternalOES windowTex;
uniform vec3 tintColor;
uniform float tintStrength;
uniform float windowAlpha;

uniform float radius;
uniform float roundingPower;
uniform vec2 topLeft;
uniform vec2 fullSize;
uniform vec2 uvTopLeft;
uniform vec2 uvBottomRight;
uniform float protectBrights;
uniform float brightThreshold;
uniform float brightKnee;
uniform float protectSaturated;
uniform float saturationThreshold;
uniform float saturationKnee;
uniform int debugVisualize;

layout(location = 0) out vec4 fragColor;

void main() {
    vec2 sampleUV = mix(uvTopLeft, uvBottomRight, v_texcoord);
    vec4 windowPixel = texture(windowTex, sampleUV);
    float contentAlpha = windowPixel.a;
    if (contentAlpha <= 0.001)
        discard;
    float luminance = dot(windowPixel.rgb, vec3(0.2126, 0.7152, 0.0722));
    float maxChannel = max(windowPixel.r, max(windowPixel.g, windowPixel.b));
    float minChannel = min(windowPixel.r, min(windowPixel.g, windowPixel.b));
    float saturation = maxChannel - minChannel;

    float brightProtect = protectBrights * smoothstep(
        brightThreshold - brightKnee,
        brightThreshold + brightKnee,
        luminance
    );
    float saturatedProtect = protectSaturated * smoothstep(
        saturationThreshold - saturationKnee,
        saturationThreshold + saturationKnee,
        saturation
    );
    float preserve = clamp(max(brightProtect, saturatedProtect), 0.0, 1.0);
    float alpha = tintStrength * (1.0 - preserve) * (1.0 - luminance) * windowAlpha * contentAlpha;
    alpha = clamp(alpha, 0.0, 1.0);

    if (debugVisualize == 1) {
        fragColor = vec4(vec3(luminance), 1.0);
        return;
    }
    if (debugVisualize == 2) {
        fragColor = vec4(vec3(saturation), 1.0);
        return;
    }
    if (debugVisualize == 3) {
        fragColor = vec4(vec3(preserve), 1.0);
        return;
    }
    if (debugVisualize == 4) {
        fragColor = vec4(vec3(alpha), 1.0);
        return;
    }
    if (debugVisualize == 5) {
        fragColor = vec4(windowPixel.rgb, 1.0);
        return;
    }

    if (radius > 0.0) {
        vec2 pixCoord = vec2(gl_FragCoord);
        pixCoord -= topLeft + fullSize * 0.5;
        pixCoord *= vec2(lessThan(pixCoord, vec2(0.0))) * -2.0 + 1.0;
        pixCoord -= fullSize * 0.5 - radius;
        pixCoord += vec2(1.0, 1.0) / fullSize;

        if (pixCoord.x + pixCoord.y > radius) {
            float dist = pow(
                pow(pixCoord.x, roundingPower) + pow(pixCoord.y, roundingPower),
                1.0 / roundingPower
            );
            float smoothingConstant = 3.14159265 / 5.34665792551;
            if (dist > radius + smoothingConstant)
                discard;
            float normalized = 1.0 - smoothstep(
                0.0, 1.0,
                (dist - radius + smoothingConstant) / (smoothingConstant * 2.0)
            );
            alpha *= normalized;
        }
    }

    fragColor = vec4(tintColor * alpha, alpha);
}
)";

// ── Shader compilation helpers ──

static GLuint compileShaderRaw(GLenum type, const char *source) {
  GLuint shader = glCreateShader(type);
  glShaderSource(shader, 1, &source, nullptr);
  glCompileShader(shader);

  GLint ok = 0;
  glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
  if (!ok) {
    char log[512];
    glGetShaderInfoLog(shader, sizeof(log), nullptr, log);
    Log::logger->log(Log::ERR, "[Hyprchroma] Shader compile error: {}", log);
    glDeleteShader(shader);
    return 0;
  }
  return shader;
}

static GLuint linkProgramRaw(GLuint vert, GLuint frag) {
  GLuint prog = glCreateProgram();
  glAttachShader(prog, vert);
  glAttachShader(prog, frag);

  // Force attribute locations so both programs share one VAO
  glBindAttribLocation(prog, 0, "pos");
  glBindAttribLocation(prog, 1, "texcoord");

  glLinkProgram(prog);

  GLint ok = 0;
  glGetProgramiv(prog, GL_LINK_STATUS, &ok);
  if (!ok) {
    char log[512];
    glGetProgramInfoLog(prog, sizeof(log), nullptr, log);
    Log::logger->log(Log::ERR, "[Hyprchroma] Program link error: {}", log);
    glDeleteProgram(prog);
    return 0;
  }
  return prog;
}

static void queryUniformLocations(
    GLuint prog, GLint &proj, GLint &windowTex, GLint &tintColor,
    GLint &tintStrength, GLint &windowAlpha, GLint &topLeft, GLint &fullSize,
    GLint &radius, GLint &roundingPower, GLint &uvTopLeft, GLint &uvBottomRight,
    GLint &protectBrights, GLint &brightThreshold, GLint &brightKnee,
    GLint &protectSaturated, GLint &saturationThreshold, GLint &saturationKnee,
    GLint &debugVisualize) {
  proj = glGetUniformLocation(prog, "proj");
  windowTex = glGetUniformLocation(prog, "windowTex");
  tintColor = glGetUniformLocation(prog, "tintColor");
  tintStrength = glGetUniformLocation(prog, "tintStrength");
  windowAlpha = glGetUniformLocation(prog, "windowAlpha");
  topLeft = glGetUniformLocation(prog, "topLeft");
  fullSize = glGetUniformLocation(prog, "fullSize");
  radius = glGetUniformLocation(prog, "radius");
  roundingPower = glGetUniformLocation(prog, "roundingPower");
  uvTopLeft = glGetUniformLocation(prog, "uvTopLeft");
  uvBottomRight = glGetUniformLocation(prog, "uvBottomRight");
  protectBrights = glGetUniformLocation(prog, "protectBrights");
  brightThreshold = glGetUniformLocation(prog, "brightThreshold");
  brightKnee = glGetUniformLocation(prog, "brightKnee");
  protectSaturated = glGetUniformLocation(prog, "protectSaturated");
  saturationThreshold = glGetUniformLocation(prog, "saturationThreshold");
  saturationKnee = glGetUniformLocation(prog, "saturationKnee");
  debugVisualize = glGetUniformLocation(prog, "debugVisualize");
}

static bool compileChromaShaders() {
  GLuint vert = compileShaderRaw(GL_VERTEX_SHADER, CHROMA_VERT_SRC);
  if (!vert)
    return false;

  // sampler2D variant
  GLuint frag = compileShaderRaw(GL_FRAGMENT_SHADER, CHROMA_FRAG_SRC);
  if (!frag) {
    glDeleteShader(vert);
    return false;
  }

  g_chromaProgram = linkProgramRaw(vert, frag);
  glDeleteShader(frag);

  if (g_chromaProgram) {
    queryUniformLocations(
        g_chromaProgram, g_loc_proj, g_loc_windowTex, g_loc_tintColor,
        g_loc_tintStrength, g_loc_windowAlpha, g_loc_topLeft, g_loc_fullSize,
        g_loc_radius, g_loc_roundingPower, g_loc_uvTopLeft, g_loc_uvBottomRight,
        g_loc_protectBrights, g_loc_brightThreshold, g_loc_brightKnee,
        g_loc_protectSaturated, g_loc_saturationThreshold, g_loc_saturationKnee,
        g_loc_debugVisualize);
  }

  // samplerExternalOES variant
  GLuint fragExt = compileShaderRaw(GL_FRAGMENT_SHADER, CHROMA_FRAG_EXT_SRC);
  if (fragExt) {
    g_chromaProgram_ext = linkProgramRaw(vert, fragExt);
    glDeleteShader(fragExt);
    if (g_chromaProgram_ext) {
      queryUniformLocations(
          g_chromaProgram_ext, g_loc_ext_proj, g_loc_ext_windowTex,
          g_loc_ext_tintColor, g_loc_ext_tintStrength, g_loc_ext_windowAlpha,
          g_loc_ext_topLeft, g_loc_ext_fullSize, g_loc_ext_radius,
          g_loc_ext_roundingPower, g_loc_ext_uvTopLeft, g_loc_ext_uvBottomRight,
          g_loc_ext_protectBrights, g_loc_ext_brightThreshold,
          g_loc_ext_brightKnee, g_loc_ext_protectSaturated,
          g_loc_ext_saturationThreshold, g_loc_ext_saturationKnee,
          g_loc_ext_debugVisualize);
    }
  } else {
    Log::logger->log(Log::WARN,
                     "[Hyprchroma] OES_EGL_image_external_essl3 not available, "
                     "DMA-BUF windows will use uniform tint fallback");
  }

  glDeleteShader(vert);

  // Create shared VAO/VBO
  glGenVertexArrays(1, &g_chromaVAO);
  glGenBuffers(1, &g_chromaVBO);

  glBindVertexArray(g_chromaVAO);
  glBindBuffer(GL_ARRAY_BUFFER, g_chromaVBO);
  glBufferData(GL_ARRAY_BUFFER, sizeof(fullVerts), fullVerts.data(),
               GL_STATIC_DRAW);

  // pos at location 0: offset 0
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(SVertex),
                        (const void *)offsetof(SVertex, x));
  // texcoord at location 1: offset 8
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(SVertex),
                        (const void *)offsetof(SVertex, u));

  glBindVertexArray(0);
  glBindBuffer(GL_ARRAY_BUFFER, 0);

  return g_chromaProgram != 0;
}

// ── CChromaPassElement ──

class CChromaPassElement : public IPassElement {
public:
  struct SSurfaceData {
    SP<CTexture> windowTex;
    CBox box;
    Vector2D uvTopLeft = Vector2D(0.F, 0.F);
    Vector2D uvBottomRight = Vector2D(1.F, 1.F);
    float alpha = 1.0f;
    bool isRootSurface = false;
  };

  struct SChromaData {
    CBox box;
    CBox clipBox;
    float tintR, tintG, tintB;
    float tintStrength;
    float windowAlpha;
    int round = 0;
    float roundingPower = 2.0f;
    bool useNearestNeighbor = false;
    Vector2D uvTopLeft = Vector2D(0.F, 0.F);
    Vector2D uvBottomRight = Vector2D(1.F, 1.F);
    float protectBrights = 1.0f;
    float brightThreshold = 0.82f;
    float brightKnee = 0.12f;
    float protectSaturated = 0.85f;
    float saturationThreshold = 0.20f;
    float saturationKnee = 0.16f;
    int debugVisualize = 0;
    std::vector<SSurfaceData> surfaces;
  };

  CChromaPassElement(const SChromaData &data) : m_data(data) {}
  virtual ~CChromaPassElement() = default;

  virtual void draw(const CRegion &damage) override;
  virtual bool needsLiveBlur() override { return false; }
  virtual bool needsPrecomputeBlur() override { return false; }
  virtual const char *passName() override { return "CChromaPassElement"; }
  virtual std::optional<CBox> boundingBox() override { return m_data.box; }

private:
  SChromaData m_data;
};

void CChromaPassElement::draw(const CRegion &damage) {
  if (m_data.surfaces.empty())
    return;

  static constexpr double DAMAGE_PAD = 1.0;

  auto pMonitor = g_pHyprOpenGL->m_renderData.pMonitor.lock();
  if (!pMonitor)
    return;
  // Save GL state
  GLint prevProgram = 0;
  glGetIntegerv(GL_CURRENT_PROGRAM, &prevProgram);
  GLint prevActiveTexture = 0;
  glGetIntegerv(GL_ACTIVE_TEXTURE, &prevActiveTexture);
  GLint prevTex2D = 0;
  GLint prevTexExternal = 0;
  glGetIntegerv(GL_TEXTURE_BINDING_2D, &prevTex2D);
  glGetIntegerv(GL_TEXTURE_BINDING_EXTERNAL_OES, &prevTexExternal);
  GLint prevVAO = 0;
  glGetIntegerv(GL_VERTEX_ARRAY_BINDING, &prevVAO);
  GLboolean prevStencilEnabled = glIsEnabled(GL_STENCIL_TEST);
  GLint prevStencilFunc = 0;
  GLint prevStencilRef = 0;
  GLint prevStencilValueMask = 0;
  GLint prevStencilWriteMask = 0;
  GLint prevStencilFail = 0;
  GLint prevStencilPassDepthFail = 0;
  GLint prevStencilPassDepthPass = 0;
  GLint prevStencilClearValue = 0;
  glGetIntegerv(GL_STENCIL_FUNC, &prevStencilFunc);
  glGetIntegerv(GL_STENCIL_REF, &prevStencilRef);
  glGetIntegerv(GL_STENCIL_VALUE_MASK, &prevStencilValueMask);
  glGetIntegerv(GL_STENCIL_WRITEMASK, &prevStencilWriteMask);
  glGetIntegerv(GL_STENCIL_FAIL, &prevStencilFail);
  glGetIntegerv(GL_STENCIL_PASS_DEPTH_FAIL, &prevStencilPassDepthFail);
  glGetIntegerv(GL_STENCIL_PASS_DEPTH_PASS, &prevStencilPassDepthPass);
  glGetIntegerv(GL_STENCIL_CLEAR_VALUE, &prevStencilClearValue);

  glBindVertexArray(g_chromaVAO);
  glEnable(GL_STENCIL_TEST);
  glStencilMask(0x80);
  glStencilFunc(GL_NOTEQUAL, 0x80, 0x80);
  glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);

  CRegion clearRegion = damage.copy().expand(DAMAGE_PAD);
  clearRegion.intersect(m_data.box.copy().round().expand(DAMAGE_PAD));
  if (m_data.clipBox.w != 0 && m_data.clipBox.h != 0)
    clearRegion.intersect(m_data.clipBox.copy().round().expand(DAMAGE_PAD));

  // Clear our stencil bit before drawing so stale claims from previous frames
  // cannot punch holes in the current frame.
  glStencilMask(0x80);
  glClearStencil(0);
  for (auto &rect : clearRegion.getRects()) {
    g_pHyprOpenGL->scissor(&rect);
    glClear(GL_STENCIL_BUFFER_BIT);
  }

  for (const auto &surf : m_data.surfaces) {
    const bool isExternal =
        (surf.windowTex->m_target == GL_TEXTURE_EXTERNAL_OES);
    const GLuint prog = isExternal ? g_chromaProgram_ext : g_chromaProgram;
    if (prog == 0)
      continue;

    const GLint locProj = isExternal ? g_loc_ext_proj : g_loc_proj;
    const GLint locWindowTex =
        isExternal ? g_loc_ext_windowTex : g_loc_windowTex;
    const GLint locTintColor =
        isExternal ? g_loc_ext_tintColor : g_loc_tintColor;
    const GLint locTintStrength =
        isExternal ? g_loc_ext_tintStrength : g_loc_tintStrength;
    const GLint locWindowAlpha =
        isExternal ? g_loc_ext_windowAlpha : g_loc_windowAlpha;
    const GLint locTopLeft = isExternal ? g_loc_ext_topLeft : g_loc_topLeft;
    const GLint locFullSize = isExternal ? g_loc_ext_fullSize : g_loc_fullSize;
    const GLint locRadius = isExternal ? g_loc_ext_radius : g_loc_radius;
    const GLint locRoundingPower =
        isExternal ? g_loc_ext_roundingPower : g_loc_roundingPower;
    const GLint locUvTopLeft =
        isExternal ? g_loc_ext_uvTopLeft : g_loc_uvTopLeft;
    const GLint locUvBottomRight =
        isExternal ? g_loc_ext_uvBottomRight : g_loc_uvBottomRight;
    const GLint locProtectBrights =
        isExternal ? g_loc_ext_protectBrights : g_loc_protectBrights;
    const GLint locBrightThreshold =
        isExternal ? g_loc_ext_brightThreshold : g_loc_brightThreshold;
    const GLint locBrightKnee =
        isExternal ? g_loc_ext_brightKnee : g_loc_brightKnee;
    const GLint locProtectSaturated =
        isExternal ? g_loc_ext_protectSaturated : g_loc_protectSaturated;
    const GLint locSaturationThreshold =
        isExternal ? g_loc_ext_saturationThreshold : g_loc_saturationThreshold;
    const GLint locSaturationKnee =
        isExternal ? g_loc_ext_saturationKnee : g_loc_saturationKnee;
    const GLint locDebugVisualize =
        isExternal ? g_loc_ext_debugVisualize : g_loc_debugVisualize;

    const auto matrix =
        g_pHyprOpenGL->m_renderData.monitorProjection.projectBox(
            surf.box, HYPRUTILS_TRANSFORM_NORMAL);
    const auto glMatrix =
        g_pHyprOpenGL->m_renderData.projection.copy().multiply(matrix);
    const auto matData = glMatrix.getMatrix();

    glUseProgram(prog);
    glUniformMatrix3fv(locProj, 1, GL_TRUE, matData.data());
    glUniform3f(locTintColor, m_data.tintR, m_data.tintG, m_data.tintB);
    glUniform1f(locTintStrength, m_data.tintStrength);
    glUniform1f(locWindowAlpha, m_data.windowAlpha * surf.alpha);

    CBox transformedBox = surf.box;
    transformedBox.transform(Math::wlTransformToHyprutils(
                                 Math::invertTransform(pMonitor->m_transform)),
                             pMonitor->m_transformedSize.x,
                             pMonitor->m_transformedSize.y);

    glUniform1f(locRadius, surf.isRootSurface ? (float)m_data.round : 0.0f);
    glUniform1f(locRoundingPower, m_data.roundingPower);
    glUniform2f(locTopLeft, transformedBox.x, transformedBox.y);
    glUniform2f(locFullSize, transformedBox.w, transformedBox.h);
    glUniform2f(locUvTopLeft, surf.uvTopLeft.x, surf.uvTopLeft.y);
    glUniform2f(locUvBottomRight, surf.uvBottomRight.x, surf.uvBottomRight.y);
    glUniform1f(locProtectBrights, m_data.protectBrights);
    glUniform1f(locBrightThreshold, m_data.brightThreshold);
    glUniform1f(locBrightKnee, m_data.brightKnee);
    glUniform1f(locProtectSaturated, m_data.protectSaturated);
    glUniform1f(locSaturationThreshold, m_data.saturationThreshold);
    glUniform1f(locSaturationKnee, m_data.saturationKnee);
    glUniform1i(locDebugVisualize, m_data.debugVisualize);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(surf.windowTex->m_target, surf.windowTex->m_texID);
    glTexParameteri(surf.windowTex->m_target, GL_TEXTURE_WRAP_S,
                    GL_CLAMP_TO_EDGE);
    glTexParameteri(surf.windowTex->m_target, GL_TEXTURE_WRAP_T,
                    GL_CLAMP_TO_EDGE);
    glTexParameteri(surf.windowTex->m_target, GL_TEXTURE_MIN_FILTER,
                    m_data.useNearestNeighbor ? GL_NEAREST : GL_LINEAR);
    glTexParameteri(surf.windowTex->m_target, GL_TEXTURE_MAG_FILTER,
                    m_data.useNearestNeighbor ? GL_NEAREST : GL_LINEAR);
    glUniform1i(locWindowTex, 0);

    CRegion surfDamage = damage.copy().expand(DAMAGE_PAD);
    surfDamage.intersect(surf.box.copy().round().expand(DAMAGE_PAD));
    if (m_data.clipBox.w != 0 && m_data.clipBox.h != 0)
      surfDamage.intersect(m_data.clipBox.copy().round().expand(DAMAGE_PAD));

    for (auto &rect : surfDamage.getRects()) {
      g_pHyprOpenGL->scissor(&rect);
      glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
  }

  // Clear again after drawing so later passes start from a clean stencil state.
  glStencilMask(0x80);
  glClearStencil(0);
  for (auto &rect : clearRegion.getRects()) {
    g_pHyprOpenGL->scissor(&rect);
    glClear(GL_STENCIL_BUFFER_BIT);
  }

  // Restore GL state
  g_pHyprOpenGL->scissor((const pixman_box32 *)nullptr);
  glBindVertexArray(prevVAO);
  glActiveTexture(prevActiveTexture);
  glBindTexture(GL_TEXTURE_2D, prevTex2D);
  glBindTexture(GL_TEXTURE_EXTERNAL_OES, prevTexExternal);
  glUseProgram(prevProgram);
  if (prevStencilEnabled)
    glEnable(GL_STENCIL_TEST);
  else
    glDisable(GL_STENCIL_TEST);
  glStencilFunc(prevStencilFunc, prevStencilRef, prevStencilValueMask);
  glStencilOp(prevStencilFail, prevStencilPassDepthFail,
              prevStencilPassDepthPass);
  glStencilMask(prevStencilWriteMask);
  glClearStencil(prevStencilClearValue);
}

// ── Config helpers ──

static float getCfgFloat(const std::string &key, float fallback) {
  auto *cv = HyprlandAPI::getConfigValue(pHandle, key);
  if (!cv)
    return fallback;
  return std::any_cast<Hyprlang::FLOAT>(cv->getValue());
}

static int getCfgInt(const std::string &key, int fallback) {
  auto *cv = HyprlandAPI::getConfigValue(pHandle, key);
  if (!cv)
    return fallback;
  return std::any_cast<Hyprlang::INT>(cv->getValue());
}

static void updateConfig() {
  g_config.r = getCfgFloat("plugin:darkwindow:tint_r", 0.20f);
  g_config.g = getCfgFloat("plugin:darkwindow:tint_g", 0.70f);
  g_config.b = getCfgFloat("plugin:darkwindow:tint_b", 1.00f);
  g_config.a = getCfgFloat("plugin:darkwindow:tint_strength", 0.040f);
  g_config.protect_brights =
      getCfgFloat("plugin:darkwindow:protect_brights", 1.00f);
  g_config.bright_threshold =
      getCfgFloat("plugin:darkwindow:bright_threshold", 0.82f);
  g_config.bright_knee = getCfgFloat("plugin:darkwindow:bright_knee", 0.12f);
  g_config.protect_saturated =
      getCfgFloat("plugin:darkwindow:protect_saturated", 0.85f);
  g_config.saturation_threshold =
      getCfgFloat("plugin:darkwindow:saturation_threshold", 0.20f);
  g_config.saturation_knee =
      getCfgFloat("plugin:darkwindow:saturation_knee", 0.16f);
  g_config.debug_visualize = getCfgInt("plugin:darkwindow:debug_visualize", 0);
  g_config.enable_on_fullscreen =
      getCfgInt("plugin:darkwindow:enable_on_fullscreen", 1);
  g_config.tint_all_surfaces =
      getCfgInt("plugin:darkwindow:tint_all_surfaces", 1);
  g_config.suspend_on_workspace_switch_ms =
      std::max(0, getCfgInt("plugin:darkwindow:suspend_on_workspace_switch_ms",
                            150));
}

static bool isShaded(PHLWINDOW pWindow) {
  if (!pWindow)
    return false;
  if (g_perWindowShaded.contains((void *)pWindow.get()))
    return true;
  return g_globalShaded;
}

// ── Render hook ──

static void onRenderStage(eRenderStage stage) {
  if (stage == RENDER_BEGIN) {
    g_renderedThisFrame.clear();

    const bool suspendedNow =
        std::chrono::steady_clock::now() < g_suspendUntil;
    if (g_wasSuspendedLastFrame && !suspendedNow)
      redrawAll();
    g_wasSuspendedLastFrame = suspendedNow;

    // Lazy shader compilation (GL context guaranteed active here)
    if (!g_shadersCompiled) {
      g_shadersCompiled = compileChromaShaders();
      if (g_shadersCompiled && !g_loggedShaderInit) {
        Log::logger->log(Log::INFO,
                         "[Hyprchroma] Shader path initialized successfully");
        g_loggedShaderInit = true;
      } else if (!g_shadersCompiled)
        Log::logger->log(Log::ERR, "[Hyprchroma] Shader compilation failed, "
                                   "falling back to uniform tint");
    }
    return;
  }

  if (stage != RENDER_POST_WINDOW)
    return;

  if (g_config.a <= 0.0f)
    return;

  if (std::chrono::steady_clock::now() < g_suspendUntil)
    return;

  auto window = g_pHyprOpenGL->m_renderData.currentWindow.lock();
  if (!window || !isShaded(window))
    return;

  if (!g_config.enable_on_fullscreen && window->isFullscreen())
    return;

  auto monitor = g_pHyprOpenGL->m_renderData.pMonitor.lock();
  if (!monitor)
    return;

  if (window->isHidden())
    return;

  auto wksp = window->m_workspace;
  if (!wksp || !wksp->m_visible)
    return;

  if (g_renderedThisFrame.contains((void *)window.get()))
    return;
  g_renderedThisFrame.insert((void *)window.get());

  const float scale = monitor->m_scale;
  const auto logBox = window->getWindowMainSurfaceBox();
  auto renderOffset = wksp->m_renderOffset->value();

  float windowAlpha =
      window->m_alpha->value() * window->m_activeInactiveAlpha->value();

  CBox overlayBox((logBox.x + renderOffset.x - monitor->m_position.x) * scale,
                  (logBox.y + renderOffset.y - monitor->m_position.y) * scale,
                  logBox.w * scale, logBox.h * scale);

  int round = static_cast<int>(window->rounding() * scale);
  float rPower = window->roundingPower();

  // Try v4 path: per-surface luminance tint
  auto clipBox = g_pHyprOpenGL->m_renderData.clipBox;
  bool useNearestNeighbor = g_pHyprOpenGL->m_renderData.useNearestNeighbor;
  CChromaPassElement::SChromaData chromaData;
  chromaData.box = overlayBox;
  chromaData.clipBox = clipBox;
  chromaData.tintR = g_config.r;
  chromaData.tintG = g_config.g;
  chromaData.tintB = g_config.b;
  chromaData.tintStrength = g_config.a;
  chromaData.windowAlpha = windowAlpha;
  chromaData.round = round;
  chromaData.roundingPower = rPower;
  chromaData.useNearestNeighbor = useNearestNeighbor;
  chromaData.protectBrights = g_config.protect_brights;
  chromaData.brightThreshold = g_config.bright_threshold;
  chromaData.brightKnee = g_config.bright_knee;
  chromaData.protectSaturated = g_config.protect_saturated;
  chromaData.saturationThreshold = g_config.saturation_threshold;
  chromaData.saturationKnee = g_config.saturation_knee;
  chromaData.debugVisualize = g_config.debug_visualize;
  if (g_shadersCompiled) {
    auto rootSurface = window->resource();
    if (!rootSurface) {
      if (!g_loggedFallbackNoSurface) {
        Log::logger->log(Log::WARN,
                         "[Hyprchroma] Window has no root surface at "
                         "RENDER_POST_WINDOW, using uniform fallback");
        g_loggedFallbackNoSurface = true;
      }
    } else {
      rootSurface->breadthfirst(
          [&](SP<CWLSurfaceResource> surface, const Vector2D &offset, void *) {
            if (!surface || !surface->m_current.texture)
              return;

            auto tex = surface->m_current.texture;
            if (tex->m_texID == 0)
              return;

            if (tex->m_target == GL_TEXTURE_EXTERNAL_OES &&
                g_chromaProgram_ext == 0) {
              if (!g_loggedFallbackNoExternalProgram) {
                Log::logger->log(
                    Log::WARN,
                    "[Hyprchroma] External texture encountered without "
                    "external shader support, skipping that surface");
                g_loggedFallbackNoExternalProgram = true;
              }
              return;
            }

            auto logicalSize = surface->m_current.size;
            const bool hasLogicalSize =
                (logicalSize.x > 1.1f && logicalSize.y > 1.1f);
            const bool isRootSurface = surface == rootSurface;
            if (!g_config.tint_all_surfaces && !isRootSurface)
              return;

            Vector2D projectedSize;
            if (surface->m_current.viewport.hasDestination)
              projectedSize =
                  (surface->m_current.viewport.destination * scale).round();
            else if (surface->m_current.viewport.hasSource)
              projectedSize =
                  (surface->m_current.viewport.source.size() * scale).round();
            else if (hasLogicalSize)
              projectedSize = (logicalSize * scale).round();
            else
              projectedSize = surface->m_current.bufferSize;

            CChromaPassElement::SSurfaceData sdata;
            sdata.windowTex = tex;
            sdata.box = CBox(
                (logBox.x + offset.x + renderOffset.x - monitor->m_position.x) *
                    scale,
                (logBox.y + offset.y + renderOffset.y - monitor->m_position.y) *
                    scale,
                projectedSize.x, projectedSize.y);
            sdata.isRootSurface = isRootSurface;

            if (isRootSurface &&
                g_pHyprOpenGL->m_renderData.primarySurfaceUVTopLeft !=
                    Vector2D(-1, -1) &&
                g_pHyprOpenGL->m_renderData.primarySurfaceUVBottomRight !=
                    Vector2D(-1, -1)) {
              sdata.uvTopLeft =
                  g_pHyprOpenGL->m_renderData.primarySurfaceUVTopLeft;
              sdata.uvBottomRight =
                  g_pHyprOpenGL->m_renderData.primarySurfaceUVBottomRight;
            } else if (surface->m_current.viewport.hasSource &&
                       surface->m_current.bufferSize.x > 0.F &&
                       surface->m_current.bufferSize.y > 0.F) {
              const auto &bufferSize = surface->m_current.bufferSize;
              const auto &bufferSource = surface->m_current.viewport.source;
              sdata.uvTopLeft = Vector2D(bufferSource.x / bufferSize.x,
                                         bufferSource.y / bufferSize.y);
              sdata.uvBottomRight =
                  Vector2D((bufferSource.x + bufferSource.width) /
                               bufferSize.x,
                           (bufferSource.y + bufferSource.height) /
                               bufferSize.y);

              if (sdata.uvBottomRight.x < 0.01f ||
                  sdata.uvBottomRight.y < 0.01f) {
                sdata.uvTopLeft = Vector2D(0.F, 0.F);
                sdata.uvBottomRight = Vector2D(1.F, 1.F);
              }
            }

            chromaData.surfaces.push_back(std::move(sdata));
          },
          nullptr);

      if (chromaData.surfaces.empty() && !g_loggedFallbackNoTexture) {
        Log::logger->log(Log::WARN,
                         "[Hyprchroma] No usable surface textures collected "
                         "for window, using uniform fallback");
        g_loggedFallbackNoTexture = true;
      } else if (chromaData.surfaces.size() > 1) {
        // Hyprland queues surfaces in breadthfirst compositor order and later
        // surfaces visually appear on top. Our stencil path is "first claim
        // wins", so we must tint in reverse render order to let the topmost
        // surface own the pixel before background/root surfaces can claim it.
        std::reverse(chromaData.surfaces.begin(), chromaData.surfaces.end());
      }
    }
  }

  if (!chromaData.surfaces.empty()) {
    if (g_config.debug_visualize > 0 && !g_notifiedShaderDebugPath) {
      HyprlandAPI::addNotification(pHandle,
                                   "[DarkWindow] Debug: shader path active",
                                   CHyprColor(0.2f, 1.0f, 0.2f, 1.0f), 2500);
      g_notifiedShaderDebugPath = true;
    }
    if (g_config.debug_visualize == 6 && !g_notifiedSurfaceDebugCount) {
      HyprlandAPI::addNotification(
          pHandle,
          std::format("[DarkWindow] Debug: {} surface(s) traced",
                      chromaData.surfaces.size()),
          CHyprColor(0.9f, 0.9f, 0.2f, 1.0f), 3500);
      g_notifiedSurfaceDebugCount = true;
    }
    if (!g_loggedShaderPath) {
      Log::logger->log(Log::INFO,
                       "[Hyprchroma] Using grouped shader tint path "
                       "(surfaces={}, clip={}x{})",
                       chromaData.surfaces.size(), clipBox.w, clipBox.h);
      g_loggedShaderPath = true;
    }
    g_pHyprRenderer->m_renderPass.add(
        makeUnique<CChromaPassElement>(chromaData));
    if (g_config.debug_visualize == 6) {
      for (const auto &surf : chromaData.surfaces) {
        CRectPassElement::SRectData debugRect;
        debugRect.box = surf.box;
        debugRect.color = surf.isRootSurface
                              ? CHyprColor(0.15f, 1.0f, 0.2f, 0.12f)
                              : CHyprColor(1.0f, 0.55f, 0.05f, 0.12f);
        debugRect.round = surf.isRootSurface ? round : 0;
        debugRect.roundingPower = rPower;
        g_pHyprRenderer->m_renderPass.add(
            makeUnique<CRectPassElement>(debugRect));

        CBorderPassElement::SBorderData border;
        border.box = surf.box;
        border.grad1 = CGradientValueData(
            surf.isRootSurface ? CHyprColor(0.2f, 1.0f, 0.25f, 1.0f)
                               : CHyprColor(1.0f, 0.65f, 0.15f, 1.0f));
        border.a = 1.0f;
        border.round = surf.isRootSurface ? round : 0;
        border.borderSize = std::max(4, (int)std::round(6.F * scale));
        border.roundingPower = rPower;
        g_pHyprRenderer->m_renderPass.add(
            makeUnique<CBorderPassElement>(border));
      }
    }
  } else {
    if (g_config.debug_visualize > 0 && !g_notifiedFallbackDebugPath) {
      HyprlandAPI::addNotification(
          pHandle, "[DarkWindow] Debug: uniform fallback path active",
          CHyprColor(1.0f, 0.2f, 0.5f, 1.0f), 3500);
      g_notifiedFallbackDebugPath = true;
    }
    // v2 fallback: uniform color rect overlay
    CRectPassElement::SRectData data;
    data.box = overlayBox;
    data.color = (g_config.debug_visualize > 0 && g_config.debug_visualize != 6)
                     ? CHyprColor(1.0f, 0.0f, 0.5f, 0.35f * windowAlpha)
                     : CHyprColor(g_config.r, g_config.g, g_config.b,
                                  g_config.a * windowAlpha);
    data.round = round;
    data.roundingPower = rPower;
    g_pHyprRenderer->m_renderPass.add(makeUnique<CRectPassElement>(data));
    if (g_config.debug_visualize == 6) {
      CRectPassElement::SRectData debugRect;
      debugRect.box = overlayBox;
      debugRect.color = CHyprColor(1.0f, 0.0f, 0.5f, 0.10f);
      debugRect.round = round;
      debugRect.roundingPower = rPower;
      g_pHyprRenderer->m_renderPass.add(
          makeUnique<CRectPassElement>(debugRect));

      CBorderPassElement::SBorderData border;
      border.box = overlayBox;
      border.grad1 = CGradientValueData(CHyprColor(1.0f, 0.0f, 0.5f, 1.0f));
      border.a = 1.0f;
      border.round = round;
      border.borderSize = std::max(4, (int)std::round(6.F * scale));
      border.roundingPower = rPower;
      g_pHyprRenderer->m_renderPass.add(makeUnique<CBorderPassElement>(border));
    }
  }
}

static void redrawAll() {
  for (auto &m : g_pCompositor->m_monitors) {
    g_pHyprRenderer->damageMonitor(m);
    g_pCompositor->scheduleFrameForMonitor(m);
  }
}

// ── Dispatchers ──

static SDispatchResult shadeDispatcher(std::string args) {
  if (args.find("address:") != std::string::npos) {
    PHLWINDOW target = nullptr;
    size_t space = args.find(' ');
    std::string addrStr = args.substr(
        8, (space == std::string::npos ? args.length() : space) - 8);

    addrStr.erase(0, addrStr.find_first_not_of(" \t\n\r"));
    addrStr.erase(addrStr.find_last_not_of(" \t\n\r") + 1);

    for (auto &w : g_pCompositor->m_windows) {
      std::ostringstream ss;
      ss << "0x" << std::hex << (uintptr_t)w.get();
      std::string currentHex = ss.str();
      std::ostringstream ss2;
      ss2 << std::hex << (uintptr_t)w.get();
      std::string currentHexShort = ss2.str();

      if (currentHex == addrStr || currentHexShort == addrStr) {
        target = w;
        break;
      }
    }

    if (!target) {
      HyprlandAPI::addNotification(pHandle,
                                   "[DarkWindow] Error: Window not found",
                                   CHyprColor(1.f, 0.f, 0.f, 1.f), 3000);
      return {false, false, "Window not found"};
    }

    if (g_perWindowShaded.contains((void *)target.get()))
      g_perWindowShaded.erase((void *)target.get());
    else
      g_perWindowShaded.insert((void *)target.get());

    HyprlandAPI::addNotification(pHandle,
                                 "[DarkWindow] Per-window shade toggled",
                                 CHyprColor(0.f, 1.f, 1.f, 1.f), 1000);
  } else {
    const auto clearedOverrides = g_perWindowShaded.size();
    g_perWindowShaded.clear();

    if (args.find("on") != std::string::npos)
      g_globalShaded = true;
    else if (args.find("off") != std::string::npos)
      g_globalShaded = false;
    else
      g_globalShaded = !g_globalShaded;

    HyprlandAPI::addNotification(
        pHandle,
        std::format("[DarkWindow] Global shade {}{}",
                    g_globalShaded ? "ON" : "OFF",
                    clearedOverrides
                        ? std::format(" (cleared {} window override(s))",
                                      clearedOverrides)
                        : ""),
        CHyprColor(0.f, 1.f, 1.f, 1.f), 1500);
  }

  redrawAll();
  return {};
}

// ── Plugin entry points ──

APICALL EXPORT std::string pluginAPIVersion() { return HYPRLAND_API_VERSION; }

APICALL EXPORT PLUGIN_DESCRIPTION_INFO pluginInit(HANDLE handle) {
  pHandle = handle;

  HyprlandAPI::addConfigValue(handle, "plugin:darkwindow:tint_r",
                              Hyprlang::FLOAT{0.20f});
  HyprlandAPI::addConfigValue(handle, "plugin:darkwindow:tint_g",
                              Hyprlang::FLOAT{0.70f});
  HyprlandAPI::addConfigValue(handle, "plugin:darkwindow:tint_b",
                              Hyprlang::FLOAT{1.00f});
  HyprlandAPI::addConfigValue(handle, "plugin:darkwindow:tint_strength",
                              Hyprlang::FLOAT{0.040f});
  HyprlandAPI::addConfigValue(handle, "plugin:darkwindow:protect_brights",
                              Hyprlang::FLOAT{1.00f});
  HyprlandAPI::addConfigValue(handle, "plugin:darkwindow:bright_threshold",
                              Hyprlang::FLOAT{0.82f});
  HyprlandAPI::addConfigValue(handle, "plugin:darkwindow:bright_knee",
                              Hyprlang::FLOAT{0.12f});
  HyprlandAPI::addConfigValue(handle, "plugin:darkwindow:protect_saturated",
                              Hyprlang::FLOAT{0.85f});
  HyprlandAPI::addConfigValue(handle, "plugin:darkwindow:saturation_threshold",
                              Hyprlang::FLOAT{0.20f});
  HyprlandAPI::addConfigValue(handle, "plugin:darkwindow:saturation_knee",
                              Hyprlang::FLOAT{0.16f});
  HyprlandAPI::addConfigValue(handle, "plugin:darkwindow:debug_visualize",
                              Hyprlang::INT{0});
  HyprlandAPI::addConfigValue(handle, "plugin:darkwindow:enable_on_fullscreen",
                              Hyprlang::INT{1});
  HyprlandAPI::addConfigValue(handle, "plugin:darkwindow:tint_all_surfaces",
                              Hyprlang::INT{1});
  HyprlandAPI::addConfigValue(
      handle, "plugin:darkwindow:suspend_on_workspace_switch_ms",
      Hyprlang::INT{150});

  updateConfig();

  g_renderListener = Event::bus()->m_events.render.stage.listen(
      [](eRenderStage stage) { onRenderStage(stage); });

  g_configListener =
      Event::bus()->m_events.config.reloaded.listen([]() { updateConfig(); });

  g_destroyWindowListener = Event::bus()->m_events.window.destroy.listen(
      [](PHLWINDOW w) { g_perWindowShaded.erase((void *)w.get()); });

  g_workspaceListener = Event::bus()->m_events.workspace.active.listen(
      [](const PHLWORKSPACE &) {
        if (g_config.suspend_on_workspace_switch_ms <= 0)
          return;
        g_suspendUntil = std::chrono::steady_clock::now() +
                         std::chrono::milliseconds(
                             g_config.suspend_on_workspace_switch_ms);
        redrawAll();
      });

  HyprlandAPI::addDispatcherV2(handle, "togglechromakey",
                               [](std::string args) -> SDispatchResult {
                                 return shadeDispatcher(args);
                               });

  HyprlandAPI::addDispatcherV2(handle, "darkwindow:shade",
                               [](std::string args) -> SDispatchResult {
                                 return shadeDispatcher(args);
                               });

  HyprlandAPI::addNotification(handle,
                               "[DarkWindow] Registered v3.3.1 "
                               "(Grouped adaptive chromakey tint)",
                               CHyprColor(0.f, 1.f, 0.f, 1.f), 3000);

  return {"DarkWindow", "Grouped adaptive per-pixel chromakey tint", "tco",
          "3.3.1"};
}

APICALL EXPORT void pluginExit() {
  g_renderListener.reset();
  g_configListener.reset();
  g_destroyWindowListener.reset();
  g_workspaceListener.reset();
  g_perWindowShaded.clear();

  if (g_chromaProgram) {
    glDeleteProgram(g_chromaProgram);
    g_chromaProgram = 0;
  }
  if (g_chromaProgram_ext) {
    glDeleteProgram(g_chromaProgram_ext);
    g_chromaProgram_ext = 0;
  }
  if (g_chromaVBO) {
    glDeleteBuffers(1, &g_chromaVBO);
    g_chromaVBO = 0;
  }
  if (g_chromaVAO) {
    glDeleteVertexArrays(1, &g_chromaVAO);
    g_chromaVAO = 0;
  }
  g_shadersCompiled = false;
  g_notifiedShaderDebugPath = false;
  g_notifiedFallbackDebugPath = false;
  g_notifiedSurfaceDebugCount = false;

  redrawAll();
}

#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, "../..");
const assetsDir = path.join(repoRoot, "docs", "assets");

const ignoreDirs = new Set([".git", ".venv", "result", "node_modules", "target", "__pycache__"]);

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function isVisibleName(name) {
  return !name.startsWith(".") && !ignoreDirs.has(name);
}

function entryKind(relPath) {
  const fullPath = path.join(repoRoot, relPath);
  if (!existsSync(fullPath)) return "missing";
  return statSync(fullPath).isDirectory() ? "folder" : "file";
}

function listEntries(relPath) {
  const fullPath = path.join(repoRoot, relPath);
  if (!existsSync(fullPath) || !statSync(fullPath).isDirectory()) return [];

  return readdirSync(fullPath, { withFileTypes: true })
    .filter((entry) => isVisibleName(entry.name))
    .sort((a, b) => {
      if (a.isDirectory() !== b.isDirectory()) return a.isDirectory() ? -1 : 1;
      return a.name.localeCompare(b.name);
    });
}

function walk(relPath = ".") {
  const fullPath = path.join(repoRoot, relPath);
  if (!existsSync(fullPath)) return [];

  const stat = statSync(fullPath);
  if (stat.isFile()) return [relPath];
  if (!stat.isDirectory()) return [];

  let files = [];
  for (const entry of listEntries(relPath)) {
    files = files.concat(walk(path.join(relPath, entry.name)));
  }
  return files;
}

function countDirs(relPath = ".") {
  const fullPath = path.join(repoRoot, relPath);
  if (!existsSync(fullPath) || !statSync(fullPath).isDirectory()) return 0;

  let count = 1;
  for (const entry of listEntries(relPath)) {
    if (entry.isDirectory()) count += countDirs(path.join(relPath, entry.name));
  }
  return count;
}

function countFiles(relPath = ".") {
  return walk(relPath).length;
}

function sizeOf(relPath) {
  const fullPath = path.join(repoRoot, relPath);
  if (!existsSync(fullPath)) return "missing";
  return `${Math.max(1, Math.round(statSync(fullPath).size / 1024))} KiB`;
}

function labelFor(relPath) {
  if (relPath === "." || relPath === "") return "/etc/nixos";
  return relPath.split(path.sep).filter(Boolean).at(-1);
}

function readTree(relPath, options = {}, depth = 0) {
  const kind = entryKind(relPath);
  const node = {
    relPath,
    label: labelFor(relPath),
    kind,
    depth,
    children: [],
    hiddenChildren: 0,
  };

  if (kind !== "folder") return node;
  if (depth >= (options.maxDepth ?? 3)) return node;

  const entries = listEntries(relPath);
  const limit = options.maxChildren ?? 12;
  const visible = entries.slice(0, limit);
  node.hiddenChildren = Math.max(0, entries.length - visible.length);
  node.children = visible.map((entry) => readTree(path.join(relPath, entry.name), options, depth + 1));

  if (node.hiddenChildren > 0) {
    node.children.push({
      relPath: path.join(relPath, `__more_${depth}`),
      label: `... ${node.hiddenChildren} more`,
      kind: "more",
      depth: depth + 1,
      children: [],
      hiddenChildren: 0,
    });
  }

  return node;
}

function flattenTree(node, selectedRelPath, rows = []) {
  rows.push({
    depth: node.depth,
    label: node.relPath === "." ? "/etc/nixos" : node.label,
    relPath: node.relPath,
    kind: node.kind === "more" ? "more" : node.kind,
    expanded: node.children.length > 0,
    selected: node.relPath === selectedRelPath,
    meta: metaForNode(node),
  });

  for (const child of node.children) flattenTree(child, selectedRelPath, rows);
  return rows;
}

function metaForNode(node) {
  if (node.kind === "more") return "collapsed";
  if (node.kind === "folder") return `${countFiles(node.relPath)} files`;
  if (node.relPath.endsWith(".nix")) return "nix";
  if (node.relPath.endsWith(".json") || node.relPath.endsWith(".jsonc")) return "json";
  if (node.relPath.endsWith(".mjs") || node.relPath.endsWith(".js")) return "script";
  if (node.relPath.endsWith(".png") || node.relPath.endsWith(".svg") || node.relPath.endsWith(".webp")) return "asset";
  if (node.relPath.endsWith(".md")) return "doc";
  return sizeOf(node.relPath);
}

function snippet(relPath, patterns = [], limit = 12) {
  const fullPath = path.join(repoRoot, relPath);
  if (!existsSync(fullPath) || !statSync(fullPath).isFile()) return "";
  if (relPath.startsWith("secrets/")) return "SOPS-encrypted file. Values intentionally not rendered in documentation screenshots.";
  if (/\.(png|jpg|jpeg|gif|webp|svg)$/.test(relPath)) return "Binary or image asset. Preview omitted from source inspector.";

  const lines = readFileSync(fullPath, "utf8").split("\n");
  const selected = [];

  if (patterns.length === 0) {
    return lines.slice(0, limit).join("\n");
  }

  for (const line of lines) {
    if (patterns.some((pattern) => pattern.test(line))) selected.push(line);
    if (selected.length >= limit) break;
  }

  return selected.join("\n") || lines.slice(0, limit).join("\n");
}

function makeNodeId(index) {
  return `node_${index}`;
}

function graphFromTree(tree, options = {}) {
  const nodes = [];
  const edges = [];
  let leafIndex = 0;

  function place(node, depth = 0, parentId = null) {
    const id = makeNodeId(nodes.length);
    const visibleChildren = node.children ?? [];
    let childIds = [];

    if (visibleChildren.length > 0) {
      childIds = visibleChildren.map((child) => place(child, depth + 1, id));
    }

    let y;
    if (childIds.length === 0) {
      y = 95 + leafIndex * (options.yGap ?? 58);
      leafIndex += 1;
    } else {
      const childYs = childIds.map((childId) => nodes.find((item) => item.id === childId).y);
      y = Math.round((Math.min(...childYs) + Math.max(...childYs)) / 2);
    }

    const label = node.relPath === "." ? "/etc/nixos" : node.label;
    const width = Math.min(250, Math.max(150, label.length * 7 + 78));
    const graphNode = {
      id,
      label,
      meta: metaForNode(node),
      kind: node.kind === "more" ? "more" : node.kind,
      status: statusFor(node),
      x: 55 + depth * (options.xGap ?? 230),
      y,
      w: width,
      h: node.kind === "folder" ? 58 : 52,
    };

    nodes.push(graphNode);
    if (parentId) edges.push([parentId, id]);
    return id;
  }

  place(tree);
  return { nodes, edges };
}

function statusFor(node) {
  if (node.kind === "more") return "more";
  if (node.kind === "folder") return "branch";
  if (node.relPath.endsWith(".nix")) return "nix";
  if (node.relPath.startsWith("secrets/")) return "SOPS";
  if (node.relPath.includes("grafana")) return "dash";
  if (node.relPath.includes("hypr")) return "wayland";
  if (node.relPath.includes("nvim")) return "editor";
  return "leaf";
}

function manualRootGraph() {
  const modules = listEntries("modules").filter((entry) => entry.name.endsWith(".nix"));
  const appModules = listEntries("home/tco/modules/apps").filter((entry) => entry.name.endsWith(".nix"));
  const counts = {
    repo: countFiles("."),
    modules: modules.length,
    appModules: appModules.length,
    config: countFiles("config"),
    docs: countFiles("docs"),
    secrets: countFiles("secrets"),
  };

  const nodes = [
    { id: "flake", label: "flake.nix", meta: "single source of truth", x: 70, y: 345, w: 210, h: 70, kind: "root", status: "root" },
    { id: "lock", label: "flake.lock", meta: "resolved graph", x: 70, y: 150, w: 180, h: 58, kind: "file", status: "pinned" },
    { id: "inputs", label: "10 inputs", meta: "unstable + stable", x: 70, y: 245, w: 180, h: 58, kind: "input", status: "pinned" },
    { id: "nixos", label: "nixosConfigurations.nixos", meta: "atomic build", x: 300, y: 345, w: 250, h: 70, kind: "system", status: "output" },
    { id: "configuration", label: "configuration.nix", meta: "system entry point", x: 550, y: 205, w: 220, h: 64, kind: "system", status: "active" },
    { id: "backup", label: "backup.nix", meta: "SOPS + Restic", x: 550, y: 315, w: 190, h: 58, kind: "secret", status: "secure" },
    { id: "hm", label: "Home Manager", meta: "inline module", x: 550, y: 430, w: 190, h: 58, kind: "home", status: "inline" },
    { id: "hardware", label: "hardware-configuration.nix", meta: "host assumptions", x: 795, y: 115, w: 235, h: 58, kind: "system", status: "host" },
    { id: "modules", label: "modules/", meta: `${counts.modules} system modules`, x: 795, y: 205, w: 205, h: 58, kind: "system", status: "branch" },
    { id: "observability", label: "observability.nix", meta: "Prometheus/Loki/Grafana", x: 1035, y: 150, w: 230, h: 58, kind: "system", status: "service" },
    { id: "gpu", label: "nvidia-prime.nix", meta: "hybrid GPU", x: 1035, y: 225, w: 190, h: 58, kind: "system", status: "driver" },
    { id: "data", label: "databases.nix", meta: "Postgres/Redis/Qdrant", x: 1035, y: 300, w: 215, h: 58, kind: "system", status: "service" },
    { id: "home", label: "home/tco/home.nix", meta: "user profile", x: 795, y: 430, w: 220, h: 58, kind: "home", status: "user" },
    { id: "apps", label: "modules/apps/", meta: `${counts.appModules} app domains`, x: 1035, y: 405, w: 190, h: 58, kind: "home", status: "domain" },
    { id: "config", label: "config/", meta: `${counts.config} dotfiles/scripts`, x: 1035, y: 485, w: 215, h: 58, kind: "config", status: "linked" },
    { id: "docs", label: "docs/", meta: `${counts.docs} docs/assets`, x: 300, y: 555, w: 190, h: 58, kind: "docs", status: "wiki" },
    { id: "secrets", label: "secrets/", meta: `${counts.secrets} encrypted`, x: 550, y: 555, w: 190, h: 58, kind: "secret", status: "SOPS" },
  ];

  const edges = [
    ["lock", "flake"], ["inputs", "flake"], ["flake", "nixos"], ["nixos", "configuration"],
    ["nixos", "backup"], ["nixos", "hm"], ["configuration", "hardware"], ["configuration", "modules"],
    ["modules", "observability"], ["modules", "gpu"], ["modules", "data"], ["hm", "home"],
    ["home", "apps"], ["home", "config"], ["backup", "secrets"], ["flake", "docs"],
  ];

  return { nodes, edges };
}

const colors = {
  root: "#0f62fe",
  input: "#4589ff",
  file: "#525252",
  folder: "#0f62fe",
  more: "#8d8d8d",
  system: "#8a3ffc",
  home: "#24a148",
  config: "#ff832b",
  docs: "#0072c3",
  secret: "#da1e28",
};

function colorForNode(node, view) {
  if (node.kind === "folder" && view.color) return view.color;
  if (node.kind === "file" && view.color) return view.color;
  return colors[node.kind] ?? view.color ?? colors.file;
}

function nodeById(graph, id) {
  return graph.nodes.find((node) => node.id === id);
}

function orthogonalPath(graph, fromId, toId) {
  const from = nodeById(graph, fromId);
  const to = nodeById(graph, toId);
  const fromX = from.x + from.w;
  const fromY = from.y + from.h / 2;
  const toX = to.x;
  const toY = to.y + to.h / 2;
  const midX = Math.round((fromX + toX) / 2);
  return `M ${fromX} ${fromY} H ${midX} V ${toY} H ${toX}`;
}

function renderTreeRows(rows) {
  const maxRows = 34;
  const visibleRows = rows.slice(0, maxRows);
  const hidden = Math.max(0, rows.length - visibleRows.length);

  const htmlRows = visibleRows.map((row) => {
    const indent = row.depth * 18;
    const caret = row.kind === "folder" || row.kind === "root" ? (row.expanded ? "▾" : "▸") : "";
    const icon = row.kind === "folder" || row.kind === "root" ? "▣" : "□";
    const selected = row.selected ? " selected" : "";
    return `
      <div class="tree-row${selected}" style="--indent:${indent}px">
        <span class="tree-caret">${caret}</span>
        <span class="tree-icon ${row.kind}">${icon}</span>
        <span class="tree-label">${escapeHtml(row.label)}</span>
        <span class="tree-meta">${escapeHtml(row.meta)}</span>
      </div>
    `;
  });

  if (hidden > 0) {
    htmlRows.push(`
      <div class="tree-row muted" style="--indent:18px">
        <span class="tree-caret"></span>
        <span class="tree-icon more">□</span>
        <span class="tree-label">... ${hidden} more rows</span>
        <span class="tree-meta">scroll</span>
      </div>
    `);
  }

  return htmlRows.join("\n");
}

function graphViewBox(graph) {
  const maxX = Math.max(...graph.nodes.map((node) => node.x + node.w + 28), 1280);
  const maxY = Math.max(...graph.nodes.map((node) => node.y + node.h + 70), 700);
  return `0 0 ${maxX} ${maxY}`;
}

function renderCanvas(graph, view) {
  const edgeSvg = graph.edges.map(([from, to]) => `<path class="edge" d="${orthogonalPath(graph, from, to)}" />`).join("\n");
  const nodeSvg = graph.nodes.map((node) => {
    const accent = colorForNode(node, view);
    return `
      <g class="canvas-node ${node.kind}" transform="translate(${node.x}, ${node.y})">
        <rect class="node-card" width="${node.w}" height="${node.h}" rx="2" />
        <rect class="node-accent" width="4" height="${node.h}" fill="${accent}" />
        <rect class="node-check" x="12" y="16" width="13" height="13" rx="2" />
        <text class="node-title" x="34" y="26">${escapeHtml(node.label)}</text>
        <text class="node-meta" x="34" y="47">${escapeHtml(node.meta)}</text>
        <text class="node-status" x="${node.w - 12}" y="47" text-anchor="end" fill="${accent}">${escapeHtml(node.status)}</text>
        <path class="node-handle" d="M ${node.w} ${node.h / 2 - 8} l 16 8 l -16 8 z" fill="${accent}" />
      </g>
    `;
  }).join("\n");

  return `
    <svg class="canvas-svg" viewBox="${graphViewBox(graph)}" role="img" aria-label="${escapeHtml(view.title)} tree view">
      ${edgeSvg}
      ${nodeSvg}
    </svg>
  `;
}

const viewDefinitions = [
  {
    id: "root",
    title: "/etc/nixos",
    relPath: ".",
    selected: "flake.nix",
    description: "Repository root: flake, NixOS entry point, Home Manager, modules, documentation, and encrypted secrets.",
    color: colors.root,
    graph: manualRootGraph(),
    patterns: [/nixosConfigurations\.nixos/, /specialArgs/, /home-manager\.users/, /promtail-bin/, /guix =/],
    aliases: ["code-map"],
  },
  {
    id: "config",
    title: "config/",
    relPath: "config",
    selected: "config/hypr/hyprland.conf",
    description: "Dotfiles and user-facing runtime assets linked into the Home Manager profile.",
    color: colors.config,
    treeOptions: { maxDepth: 3, maxChildren: 12 },
    graphOptions: { maxDepth: 1, maxChildren: 30, xGap: 250, yGap: 50 },
    patterns: [/^\$mod/, /^bind/, /^exec-once/, /^monitor/, /^plugin/, /^source/],
  },
  {
    id: "docs",
    title: "docs/",
    relPath: "docs",
    selected: "docs/wiki/Architecture-&-Flake-Logic.md",
    description: "Wiki pages, generated visual assets, PlantUML sources, dashboard screenshots, and repository specification.",
    color: colors.docs,
    treeOptions: { maxDepth: 3, maxChildren: 12 },
    graphOptions: { maxDepth: 2, maxChildren: 8, xGap: 225, yGap: 50 },
    patterns: [/^# /, /^## /, /code-map/, /TreeView/, /Arborescence/],
  },
  {
    id: "home",
    title: "home/tco/",
    relPath: "home/tco",
    selected: "home/tco/home.nix",
    description: "Inline Home Manager layer: packages, shell, themes, desktop entries, dotfile links, and app modules.",
    color: colors.home,
    treeOptions: { maxDepth: 5, maxChildren: 12 },
    graphOptions: { maxDepth: 5, maxChildren: 10, xGap: 220, yGap: 56 },
    patterns: [/home\.packages/, /home\.file/, /xdg\.configFile/, /programs\.bash/, /programs\.vscode/, /programs\.starship/],
  },
  {
    id: "modules",
    title: "modules/",
    relPath: "modules",
    selected: "modules/observability.nix",
    description: "System modules: services, drivers, local data stack, virtualisation, backups, and observability.",
    color: colors.system,
    treeOptions: { maxDepth: 1, maxChildren: 30 },
    graphOptions: { maxDepth: 1, maxChildren: 30, xGap: 245, yGap: 50 },
    patterns: [/services\.prometheus/, /services\.loki/, /services\.grafana/, /promtail/, /textfileDir/, /nix-metrics/],
  },
  {
    id: "secrets",
    title: "secrets/",
    relPath: "secrets",
    selected: "secrets/backup.yaml",
    description: "Commit-safe encrypted material. Values are SOPS/Age encrypted and decrypted only at activation time.",
    color: colors.secret,
    treeOptions: { maxDepth: 1, maxChildren: 20 },
    graphOptions: { maxDepth: 1, maxChildren: 20, xGap: 250, yGap: 70 },
    patterns: [],
  },
];

function buildView(view) {
  const tree = readTree(view.relPath, view.treeOptions ?? { maxDepth: 3, maxChildren: 12 });
  const rows = flattenTree(tree, view.selected);
  const graph = view.graph ?? graphFromTree(readTree(view.relPath, view.graphOptions ?? view.treeOptions), view.graphOptions);
  return { tree, rows, graph };
}

function propertiesFor(view) {
  const selectedKind = entryKind(view.selected);
  const selectedFiles = selectedKind === "folder" ? countFiles(view.selected) : 1;
  const selectedDirs = selectedKind === "folder" ? countDirs(view.selected) : 0;
  return [
    ["Path", view.selected],
    ["Type", selectedKind],
    ["Files", `${selectedFiles}`],
    ["Dirs", `${selectedDirs}`],
    ["Size", selectedKind === "file" ? sizeOf(view.selected) : `${selectedFiles} files`],
    ["Source", view.relPath === "." ? "repository root" : view.relPath],
  ];
}

function renderHtml(view) {
  const { rows, graph } = buildView(view);
  const sourceSnippet = snippet(view.selected, view.patterns);
  const properties = propertiesFor(view);

  return `<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${escapeHtml(view.title)} Tree View</title>
  <style>
    :root {
      color-scheme: light;
      --blue: #0f62fe;
      --text: #161616;
      --muted: #6f6f6f;
      --border: #c6c6c6;
      --border-soft: #e0e0e0;
      --layer-01: #ffffff;
      --layer-02: #f4f4f4;
      --canvas: #b9b9b9;
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      height: 900px;
      overflow: hidden;
      background: var(--layer-02);
      color: var(--text);
      font-family: "IBM Plex Sans", Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      font-size: 14px;
    }

    .app {
      width: 1600px;
      height: 900px;
      background: var(--layer-02);
      border-top: 3px solid #004144;
    }

    .titlebar {
      height: 31px;
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 0 10px;
      background: #fefefe;
      border-bottom: 1px solid var(--border);
      font-size: 13px;
    }

    .title-icon {
      width: 15px;
      height: 15px;
      border: 1px solid ${view.color};
      background: linear-gradient(135deg, #e5f6ff, #ffffff);
    }

    .menubar {
      height: 25px;
      display: flex;
      align-items: center;
      gap: 18px;
      padding: 0 10px;
      background: #f4f4f4;
      border-bottom: 1px solid var(--border);
      font-size: 13px;
    }

    .toolbar {
      height: 45px;
      display: flex;
      align-items: center;
      gap: 14px;
      padding: 0 10px;
      background: linear-gradient(#eeeeee, #d7d7d7);
      border-bottom: 1px solid #8d8d8d;
    }

    .tool {
      width: 30px;
      height: 30px;
      border: 1px solid #bdbdbd;
      background: #f4f4f4;
      display: grid;
      place-items: center;
      color: #393939;
      font-size: 16px;
    }

    .tool.active {
      background: #d0e2ff;
      border-color: #78a9ff;
      color: var(--blue);
    }

    .tabs {
      height: 31px;
      display: flex;
      align-items: end;
      gap: 1px;
      padding-left: 188px;
      background: #eef2ef;
      border-bottom: 1px solid #a8a8a8;
      font-size: 13px;
      font-weight: 600;
    }

    .tab {
      padding: 8px 12px 7px;
      border: 1px solid transparent;
      border-bottom: none;
    }

    .tab.active {
      background: #ffffff;
      border-color: #a8a8a8;
      color: var(--blue);
    }

    .workspace {
      height: calc(900px - 135px);
      display: grid;
      grid-template-columns: 415px 1fr 310px;
      min-height: 0;
    }

    .sidebar {
      background: var(--layer-01);
      border-right: 2px solid #8d8d8d;
      display: grid;
      grid-template-rows: 34px 1fr;
      min-height: 0;
    }

    .search {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 0 9px;
      border-bottom: 1px solid var(--border-soft);
      color: var(--muted);
      font-size: 13px;
    }

    .tree {
      overflow: hidden;
      padding-top: 4px;
    }

    .tree-row {
      height: 28px;
      display: grid;
      grid-template-columns: 20px 18px minmax(0, 1fr) auto;
      align-items: center;
      gap: 6px;
      padding-left: calc(8px + var(--indent));
      padding-right: 8px;
      border-bottom: 1px solid #eeeeee;
      white-space: nowrap;
    }

    .tree-row.selected {
      background: #d0e2ff;
      outline: 2px solid var(--blue);
      outline-offset: -2px;
    }

    .tree-row.muted {
      color: var(--muted);
      background: #f8f8f8;
    }

    .tree-caret {
      color: #393939;
      font-size: 13px;
      text-align: center;
    }

    .tree-icon {
      width: 14px;
      height: 14px;
      display: inline-grid;
      place-items: center;
      color: #8d8d8d;
      font-size: 11px;
    }

    .tree-icon.folder,
    .tree-icon.root {
      color: ${view.color};
    }

    .tree-label {
      overflow: hidden;
      text-overflow: ellipsis;
      font-size: 14px;
    }

    .tree-meta {
      color: var(--blue);
      font-size: 12px;
      padding-left: 10px;
    }

    .canvas-wrap {
      position: relative;
      overflow: hidden;
      background:
        linear-gradient(rgba(255,255,255,0.16) 1px, transparent 1px),
        linear-gradient(90deg, rgba(255,255,255,0.16) 1px, transparent 1px),
        var(--canvas);
      background-size: 32px 32px;
      border-right: 1px solid #8d8d8d;
    }

    .canvas-header {
      position: absolute;
      left: 24px;
      top: 18px;
      z-index: 2;
      display: flex;
      align-items: center;
      gap: 12px;
      background: rgba(244, 244, 244, 0.88);
      border: 1px solid #8d8d8d;
      padding: 9px 12px;
    }

    .canvas-header strong {
      font-size: 14px;
    }

    .canvas-header span {
      color: var(--muted);
      font-size: 12px;
    }

    .canvas-svg {
      position: absolute;
      left: 34px;
      top: 46px;
      width: 100%;
      height: 710px;
    }

    .edge {
      fill: none;
      stroke: #525252;
      stroke-width: 1.4;
      shape-rendering: crispEdges;
    }

    .node-card {
      fill: #fefefa;
      stroke: #6f6f6f;
      stroke-width: 1;
    }

    .node-check {
      fill: #f4f4f4;
      stroke: #a8a8a8;
    }

    .node-title {
      fill: #161616;
      font-size: 13px;
      font-weight: 700;
    }

    .node-meta {
      fill: #525252;
      font-size: 12px;
    }

    .node-status {
      font-size: 12px;
      font-weight: 600;
    }

    .node-handle {
      opacity: 0.7;
    }

    .inspector {
      background: var(--layer-01);
      display: grid;
      grid-template-rows: auto 1fr auto;
      min-height: 0;
    }

    .inspector-title {
      padding: 18px 18px 12px;
      border-bottom: 1px solid var(--border-soft);
    }

    .inspector-title h1 {
      margin: 0 0 4px;
      font-size: 20px;
      font-weight: 600;
    }

    .inspector-title p {
      margin: 0;
      color: var(--muted);
      font-size: 13px;
      line-height: 1.35;
    }

    .properties {
      overflow: hidden;
      padding: 16px 18px;
    }

    .property {
      display: grid;
      grid-template-columns: 82px 1fr;
      border-bottom: 1px solid var(--border-soft);
      min-height: 34px;
      align-items: center;
      font-size: 13px;
    }

    .property span:first-child {
      color: var(--muted);
    }

    pre {
      margin: 16px 0 0;
      padding: 12px;
      height: 210px;
      overflow: hidden;
      border: 1px solid var(--border-soft);
      background: #f4f4f4;
      color: #262626;
      font-family: "IBM Plex Mono", "JetBrains Mono", ui-monospace, SFMono-Regular, monospace;
      font-size: 11px;
      line-height: 1.55;
    }

    .legend {
      padding: 14px 18px;
      border-top: 1px solid var(--border-soft);
      display: grid;
      gap: 8px;
      font-size: 12px;
      color: var(--muted);
    }

    .legend-row {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .swatch {
      width: 13px;
      height: 13px;
      border: 1px solid #8d8d8d;
    }
  </style>
</head>
<body>
  <div class="app">
    <div class="titlebar">
      <span class="title-icon"></span>
      <span>TreeView - [setup-os Repository] - [${escapeHtml(view.title)}]</span>
    </div>

    <div class="menubar">
      <span>File</span>
      <span>Edit</span>
      <span>View</span>
      <span>Repository</span>
      <span>Tools</span>
      <span>Help</span>
    </div>

    <div class="toolbar">
      <div class="tool">+</div>
      <div class="tool">□</div>
      <div class="tool active">▣</div>
      <div class="tool">☰</div>
      <div class="tool">▤</div>
      <div class="tool">?</div>
      <div style="margin-left:auto;color:#525252;font-size:13px;">Carbon-inspired TreeView screenshot · generated from repository data</div>
    </div>

    <div class="tabs">
      <div class="tab ${view.id === "root" ? "active" : ""}">Root</div>
      <div class="tab ${view.id === "config" ? "active" : ""}">config</div>
      <div class="tab ${view.id === "modules" ? "active" : ""}">modules</div>
      <div class="tab ${view.id === "home" ? "active" : ""}">home</div>
      <div class="tab ${view.id === "docs" ? "active" : ""}">docs</div>
      <div class="tab ${view.id === "secrets" ? "active" : ""}">secrets</div>
    </div>

    <div class="workspace">
      <aside class="sidebar">
        <div class="search">Search ${escapeHtml(view.title)} tree</div>
        <div class="tree">
          ${renderTreeRows(rows)}
        </div>
      </aside>

      <main class="canvas-wrap">
        <div class="canvas-header">
          <strong>${escapeHtml(view.title)} hierarchy</strong>
          <span>${countDirs(view.relPath)} dirs · ${countFiles(view.relPath)} files</span>
        </div>
        ${renderCanvas(graph, view)}
      </main>

      <section class="inspector">
        <div class="inspector-title">
          <h1>${escapeHtml(labelFor(view.selected))}</h1>
          <p>${escapeHtml(view.description)}</p>
        </div>

        <div class="properties">
          ${properties.map(([key, value]) => `<div class="property"><span>${escapeHtml(key)}</span><strong>${escapeHtml(value)}</strong></div>`).join("\n")}
          <pre>${escapeHtml(sourceSnippet)}</pre>
        </div>

        <div class="legend">
          <div class="legend-row"><span class="swatch" style="background:${view.color}"></span> Current subtree focus</div>
          <div class="legend-row"><span class="swatch" style="background:#0f62fe"></span> Branch nodes</div>
          <div class="legend-row"><span class="swatch" style="background:#525252"></span> Leaf nodes</div>
          <div class="legend-row"><span class="swatch" style="background:#da1e28"></span> Secret or protected material</div>
        </div>
      </section>
    </div>
  </div>
</body>
</html>`;
}

function outputBase(viewId) {
  return viewId === "root" ? "code-map" : `code-map-${viewId}`;
}

function renderView(view) {
  const base = outputBase(view.id);
  const htmlPath = path.join(assetsDir, `${base}.html`);
  const pngPath = path.join(assetsDir, `${base}.png`);

  const html = `${renderHtml(view).replace(/[ \t]+$/gm, "")}\n`;
  writeFileSync(htmlPath, html, "utf8");

  execFileSync(
    "google-chrome",
    [
      "--headless=new",
      "--disable-gpu",
      "--hide-scrollbars",
      "--no-first-run",
      "--no-default-browser-check",
      "--run-all-compositor-stages-before-draw",
      "--virtual-time-budget=1000",
      "--window-size=1600,900",
      `--screenshot=${pngPath}`,
      `file://${htmlPath}`,
    ],
    { stdio: "inherit" },
  );

  for (const alias of view.aliases ?? []) {
    copyFileSync(htmlPath, path.join(assetsDir, `${alias}.html`));
    copyFileSync(pngPath, path.join(assetsDir, `${alias}.png`));
  }

  console.log(`Wrote ${path.relative(repoRoot, htmlPath)}`);
  console.log(`Wrote ${path.relative(repoRoot, pngPath)}`);
}

mkdirSync(assetsDir, { recursive: true });
for (const view of viewDefinitions) renderView(view);

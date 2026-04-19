local g = import 'lib/dashboard.libsonnet';
local c = g.colors.mocha;

local window = '$window';
local storeGrowth = 'deriv(nix_store_bytes[' + window + '])';
local closureGrowth = 'deriv(nix_closure_bytes[' + window + '])';
local closureRatio = 'nix_closure_bytes / clamp_min(nix_store_bytes, 1)';
local topClosureExpr = 'nix_closure_top_bytes or on() (label_replace(label_replace(absent(nix_closure_top_bytes), "rank", "0", "", ".*"), "path", "nix-metrics pending", "", ".*") * 0)';

local hiddenTimeAxis = {
  matcher: { id: 'byType', options: 'time' },
  properties: [g.propAxisPlacement('hidden')],
};

local forgeStrip = {
  id: 30,
  gridPos: { x: 0, y: 14, w: 24, h: 2 },
  type: 'stat',
  title: '',
  datasource: g.prometheusDatasource,
  targets: [
    g.prometheusTarget('nix_rebuild_duration_ms / 1000', 'rebuild seconds', 'A', instant=true),
    g.prometheusTarget('nix_rebuild_success', 'last rebuild', 'B', instant=true),
    g.prometheusTarget('nix_flake_lock_age_seconds / 86400', 'flake age days', 'C', instant=true),
    g.prometheusTarget('nix_generations_count', 'retained generations', 'D', instant=true),
    g.prometheusTarget('nix_store_usage_ratio', 'store fill', 'E', instant=true),
  ],
  options: {
    colorMode: 'background',
    graphMode: 'none',
    justifyMode: 'center',
    orientation: 'horizontal',
    reduceOptions: { values: false, calcs: ['lastNotNull'], fields: '' },
    showPercentChange: false,
    textMode: 'value_and_name',
    wideLayout: true,
  },
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      thresholds: g.greenYellowRed(80, 90),
      mappings: [],
    },
    overrides: [
      {
        matcher: { id: 'byFrameRefID', options: 'A' },
        properties: [g.propUnit('s'), { id: 'decimals', value: 1 }, g.propColor(c.teal)],
      },
      {
        matcher: { id: 'byFrameRefID', options: 'B' },
        properties: [
          g.propUnit('none'),
          {
            id: 'mappings',
            value: [
              g.valueMapping(1, 'OK', c.green, 0),
              g.valueMapping(0, 'FAIL', c.red, 1),
              g.noDataMapping,
            ],
          },
          {
            id: 'thresholds',
            value: g.thresholds([{ color: c.red, value: null }, { color: c.green, value: 1 }]),
          },
        ],
      },
      {
        matcher: { id: 'byFrameRefID', options: 'C' },
        properties: [g.propUnit('d'), { id: 'decimals', value: 1 }, g.propColor(c.yellow)],
      },
      {
        matcher: { id: 'byFrameRefID', options: 'D' },
        properties: [g.propUnit('none'), { id: 'decimals', value: 0 }, g.propColor(c.peach)],
      },
      {
        matcher: { id: 'byFrameRefID', options: 'E' },
        properties: [g.propUnit('percentunit'), { id: 'decimals', value: 1 }, g.propColor(c.blue)],
      },
    ],
  },
};

g.dashboard(
  'NixOS Forge',
  'nixos-forge',
  '30s',
  'Build and store control plane: store growth, closure mass, generations, and rebuild outcome.',
  variables=[
    g.intervalVar('window', 'Growth window', ['15m', '1h', '6h', '24h', '7d'], '6h'),
  ]
) {
  time: { from: 'now-24h', to: 'now' },
  panels: [
    g.rowPanel(1, 'Store And Closure', 0),

    g.statPanel(2, 'Store Used', 'nix_store_bytes', 0, 1, 4, 4, unit='bytes', decimals=1, thresholds=g.thresholds([{ color: c.blue, value: null }])),
    g.statPanel(3, 'Store Free', 'nix_store_available_bytes', 4, 1, 4, 4, unit='bytes', decimals=1, thresholds=g.thresholds([{ color: c.green, value: null }])),
    g.statPanel(4, 'Store Fill', 'nix_store_usage_ratio', 8, 1, 4, 4, unit='percentunit', decimals=1, min=0, max=1, thresholds=g.greenYellowRed(0.75, 0.9)),
    g.statPanel(5, 'Closure Size', 'nix_closure_bytes', 12, 1, 4, 4, unit='bytes', decimals=1, thresholds=g.thresholds([{ color: c.teal, value: null }])),
    g.statPanel(6, 'Closure Paths', 'nix_closure_paths', 16, 1, 4, 4, unit='none', decimals=0, thresholds=g.thresholds([{ color: c.mauve, value: null }])),
    g.statPanel(7, 'Generations', 'nix_generations_count', 20, 1, 4, 4, unit='none', decimals=0, thresholds=g.greenYellowRed(6, 10)),

    g.rowPanel(10, 'Capacity', 5),

    g.barGaugePanel(
      11,
      'Capacity Ratios',
      [
        { expr: 'nix_store_usage_ratio', legend: 'store fill' },
        { expr: closureRatio, legend: 'closure/store' },
        { expr: 'clamp_max(nix_generations_count / 10, 1)', legend: 'generation debt' },
      ],
      0, 6, 5, 7,
      unit='percentunit',
      min=0,
      max=1,
      thresholds=g.greenYellowRed(0.75, 0.9),
      orientation='horizontal',
      displayMode='basic',
      overrides=[
        g.overrideByName('store fill', [g.propColor(c.blue)]),
        g.overrideByName('closure/store', [g.propColor(c.teal)]),
        g.overrideByName('generation debt', [g.propColor(c.peach)]),
      ]
    ),

    g.timeseriesPanel(
      12,
      'Store Footprint',
      [
        { expr: 'nix_store_capacity_bytes', legend: 'capacity' },
        { expr: 'nix_store_bytes', legend: 'used' },
        { expr: 'nix_store_available_bytes', legend: 'available' },
        { expr: 'nix_closure_bytes', legend: 'running closure' },
      ],
      5, 6, 10, 7,
      unit='bytes',
      fillOpacity=22,
      gradientMode='opacity',
      thresholdsStyle='off',
      overrides=[
        g.overrideByName('capacity', [g.propColor(c.red), g.propLineWidth(2), g.propFillOpacity(3)]),
        g.overrideByName('used', [g.propColor(c.blue), g.propFillOpacity(30)]),
        g.overrideByName('available', [g.propColor(c.green), g.propFillOpacity(10)]),
        g.overrideByName('running closure', [g.propColor(c.mauve), g.propLineWidth(2)]),
        hiddenTimeAxis,
      ],
      legendPlacement='right',
      legendCalcs=['lastNotNull']
    ),

    g.timeseriesPanel(
      13,
      'Growth Velocity',
      [
        { expr: storeGrowth, legend: 'store bytes/s' },
        { expr: closureGrowth, legend: 'closure bytes/s' },
        { expr: 'deriv(nix_store_paths[' + window + '])', legend: 'paths/s' },
      ],
      15, 6, 9, 7,
      unit='Bps',
      fillOpacity=16,
      gradientMode='opacity',
      axisLabel='growth',
      overrides=[
        g.overrideByName('store bytes/s', [g.propColor(c.teal), g.propLineWidth(2)]),
        g.overrideByName('closure bytes/s', [g.propColor(c.mauve), g.propLineWidth(2)]),
        g.overrideByName('paths/s', [g.propUnit('ops'), g.propAxisPlacement('right'), g.propColor(c.yellow)]),
        hiddenTimeAxis,
      ],
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max']
    ),

    g.rowPanel(20, 'Build State', 13),
    forgeStrip,

    g.timeseriesPanel(
      31,
      'Generation History',
      [
        { expr: 'nix_generation', legend: 'current generation' },
        { expr: 'nix_generations_count', legend: 'retained generations' },
      ],
      0, 16, 8, 7,
      unit='none',
      fillOpacity=10,
      gradientMode='none',
      overrides=[
        g.overrideByName('current generation', [g.propColor(c.blue), g.propLineWidth(2)]),
        g.overrideByName('retained generations', [g.propColor(c.peach), g.propLineWidth(2)]),
        hiddenTimeAxis,
      ],
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max']
    ),

    g.timeseriesPanel(
      32,
      'Rebuild Cost',
      [
        { expr: 'nix_rebuild_duration_ms / 1000', legend: 'duration' },
        { expr: 'nix_rebuild_success', legend: 'success' },
        { expr: 'nix_flake_lock_age_seconds / 86400', legend: 'flake age' },
      ],
      8, 16, 8, 7,
      unit='s',
      fillOpacity=16,
      gradientMode='opacity',
      thresholdsStyle='line',
      thresholds=g.greenYellowRed(60, 180),
      overrides=[
        g.overrideByName('duration', [g.propColor(c.teal), g.propLineWidth(2)]),
        g.overrideByName('success', [g.propUnit('none'), g.propAxisPlacement('right'), g.propColor(c.green), g.propDrawStyle('bars')]),
        g.overrideByName('flake age', [g.propUnit('d'), g.propAxisPlacement('right'), g.propColor(c.yellow)]),
        hiddenTimeAxis,
      ],
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max']
    ),

    g.barGaugePanel(
      33,
      'Top Closure Mass',
      [
        { expr: 'topk(10, ' + topClosureExpr + ')', legend: '#{{rank}} {{path}}' },
      ],
      16, 16, 8, 7,
      unit='bytes',
      min=0,
      max=null,
      thresholds=g.thresholds([
        { color: c.green, value: null },
        { color: c.yellow, value: 1073741824 },
        { color: c.red, value: 2147483648 },
      ]),
      orientation='horizontal',
      displayMode='gradient'
    ),

    g.rowPanel(40, 'Closure Inventory', 23),

    g.tablePanel(
      41,
      'Top 10 Closure Paths',
      [
        { expr: 'topk(10, ' + topClosureExpr + ')', legend: '{{path}}' },
      ],
      0, 24, 24, 8,
      transformations=[
        {
          id: 'organize',
          options: {
            excludeByName: { Time: true, '__name__': true, instance: true, job: true },
            includeByName: {},
            indexByName: { rank: 0, path: 1, Value: 2, 'Value #A': 2 },
            renameByName: { rank: 'Rank', path: 'Store Path', Value: 'Bytes', 'Value #A': 'Bytes' },
          },
        },
      ],
      overrides=[
        g.overrideByName('Rank', [{ id: 'custom.width', value: 70 }, { id: 'custom.align', value: 'center' }]),
        g.overrideByName('Store Path', [{ id: 'custom.align', value: 'left' }]),
        g.overrideByName('Bytes', [g.propUnit('bytes'), { id: 'custom.cellOptions', value: { type: 'color-background' } }]),
      ]
    ) {
      options+: { sortBy: [{ desc: true, displayName: 'Bytes' }] },
      fieldConfig+: {
        defaults+: {
          unit: 'bytes',
          color: { mode: 'thresholds' },
          thresholds: g.thresholds([
            { color: c.green, value: null },
            { color: c.yellow, value: 1073741824 },
            { color: c.red, value: 2147483648 },
          ]),
          custom+: { cellOptions: { type: 'color-text' } },
        },
      },
    },
  ],
}

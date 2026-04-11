local colors = {
  green: 'green',
  yellow: 'yellow',
  red: 'red',
  text: 'text',
};

{
  thresholds(steps):: {
    mode: 'absolute',
    steps: steps,
  },

  greenYellowRed(warn, crit):: $.thresholds([
    { color: colors.green, value: null },
    { color: colors.yellow, value: warn },
    { color: colors.red, value: crit },
  ]),

  noDataMapping:: {
    type: 'special',
    options: {
      match: 'null',
      result: { text: 'No data', color: colors.text, index: 0 },
    },
  },

  rangeMapping(from, to, text, color, index):: {
    type: 'range',
    options: {
      from: from,
      to: to,
      result: { text: text, color: color, index: index },
    },
  },

  prometheusTarget(expr, legendFormat, refId='A'):: {
    expr: expr,
    legendFormat: legendFormat,
    refId: refId,
  },

  lokiTarget(expr, refId='A'):: {
    expr: expr,
    refId: refId,
  },

  dashboard(title, uid, refresh, description):: {
    title: title,
    uid: uid,
    schemaVersion: 39,
    version: 1,
    editable: true,
    graphTooltip: 0,
    fiscalYearStartMonth: 0,
    liveNow: false,
    tags: ['nixos', 'local-observability'],
    timezone: 'browser',
    refresh: refresh,
    time: { from: 'now-6h', to: 'now' },
    timepicker: { refresh_intervals: ['30s', '1m', '5m', '15m'] },
    description: description,
    annotations: {
      list: [
        {
          builtIn: 1,
          datasource: { type: 'grafana', uid: '-- Grafana --' },
          enable: true,
          hide: true,
          iconColor: 'rgba(0, 211, 255, 1)',
          name: 'Annotations & Alerts',
          type: 'dashboard',
        },
      ],
    },
    panels: [],
  },

  textPanel(id, title, content, x, y, w, h=2):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'text',
    title: title,
    transparent: true,
    options: {
      mode: 'markdown',
      content: content,
      contentType: 'markdown',
    },
  },

  rowPanel(id, title, y):: {
    id: id,
    gridPos: { x: 0, y: y, w: 24, h: 1 },
    type: 'row',
    title: title,
    collapsed: false,
  },

  statPanel(
    id,
    title,
    expr,
    x,
    y,
    w,
    h=3,
    datasource='Prometheus',
    legend='value',
    unit=null,
    decimals=null,
    min=null,
    max=null,
    thresholds=null,
    mappings=null,
    colorMode='value',
    graphMode='area'
  ):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'stat',
    title: title,
    datasource: datasource,
    targets: if datasource == 'Loki' then [$.lokiTarget(expr)] else [$.prometheusTarget(expr, legend)],
    options: {
      reduceOptions: { values: false, calcs: ['lastNotNull'], fields: '' },
      orientation: 'auto',
      textMode: 'auto',
      colorMode: colorMode,
      graphMode: graphMode,
      justifyMode: 'auto',
    },
    fieldConfig: {
      defaults:
        { color: { mode: 'thresholds' } }
        + (if unit == null then {} else { unit: unit })
        + (if decimals == null then {} else { decimals: decimals })
        + (if min == null then {} else { min: min })
        + (if max == null then {} else { max: max })
        + (if thresholds == null then {} else { thresholds: thresholds })
        + (if mappings == null then {} else { mappings: mappings }),
      overrides: [],
    },
  },

  gaugePanel(
    id,
    title,
    expr,
    legend,
    x,
    y,
    w,
    h=5,
    unit='percent',
    min=0,
    max=100,
    thresholds=null,
    labels=true
  ):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'gauge',
    title: title,
    datasource: 'Prometheus',
    targets: [$.prometheusTarget(expr, legend)],
    options: {
      reduceOptions: { values: false, calcs: ['lastNotNull'], fields: '' },
      showThresholdLabels: labels,
      showThresholdMarkers: true,
    },
    fieldConfig: {
      defaults: {
        unit: unit,
        min: min,
        max: max,
        thresholds: if thresholds == null then $.greenYellowRed(10, 30) else thresholds,
        color: { mode: 'thresholds' },
      },
      overrides: [],
    },
  },

  timeseriesPanel(
    id,
    title,
    targets,
    x,
    y,
    w,
    h=8,
    unit=null,
    axisLabel='',
    overrides=[]
  ):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'timeseries',
    title: title,
    datasource: 'Prometheus',
    targets: std.mapWithIndex(
      function(i, t)
        $.prometheusTarget(t.expr, t.legend, std.get(t, 'refId', std.substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ', i, 1))),
      targets
    ),
    options: {
      legend: { calcs: ['lastNotNull'], displayMode: 'list', placement: 'bottom', showLegend: true },
      tooltip: { mode: 'single', sort: 'none' },
    },
    fieldConfig: {
      defaults:
        {
          color: { mode: 'palette-classic' },
          custom: {
            axisCenteredZero: false,
            axisColorMode: 'text',
            axisLabel: axisLabel,
            axisPlacement: 'auto',
            barAlignment: 0,
            drawStyle: 'line',
            fillOpacity: 8,
            gradientMode: 'none',
            hideFrom: { legend: false, tooltip: false, viz: false },
            lineInterpolation: 'smooth',
            lineWidth: 2,
            pointSize: 4,
            scaleDistribution: { type: 'linear' },
            showPoints: 'never',
            spanNulls: true,
            stacking: { group: 'A', mode: 'none' },
            thresholdsStyle: { mode: 'off' },
          },
        }
        + (if unit == null then {} else { unit: unit }),
      overrides: overrides,
    },
  },

  logsPanel(id, title, expr, x, y, w, h):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'logs',
    title: title,
    datasource: 'Loki',
    targets: [$.lokiTarget(expr)],
    options: {
      showTime: true,
      showLabels: false,
      showCommonLabels: false,
      wrapLogMessage: true,
      sortOrder: 'Descending',
      dedupStrategy: 'none',
    },
  },

  overrideUnitByName(name, unit, axisPlacement=null, axisLabel=null, color=null):: {
    matcher: { id: 'byName', options: name },
    properties:
      [{ id: 'unit', value: unit }]
      + (if axisPlacement == null then [] else [{ id: 'custom.axisPlacement', value: axisPlacement }])
      + (if axisLabel == null then [] else [{ id: 'custom.axisLabel', value: axisLabel }])
      + (if color == null then [] else [{ id: 'color', value: color }]),
  },
}

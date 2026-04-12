local colors = {
  aqua: '#36e7d6',
  cyan: '#27c6ff',
  blue: '#155ec9',
  sapphire: '#65b8ff',
  sky: '#8df4ec',
  ice: '#d3fbff',
  lavender: '#9cb7ff',
  mauve: '#b48efa',
  rose: '#a66d88',
  text: '#d8f7fb',
  ok: '#36e7d6',
  warn: '#65b8ff',
  crit: '#b48efa',
};

{
  colors:: colors,

  fixedColor(color):: {
    mode: 'fixed',
    fixedColor: color,
  },

  thresholds(steps):: {
    mode: 'absolute',
    steps: steps,
  },

  greenYellowRed(warn, crit):: $.thresholds([
    { color: colors.ok, value: null },
    { color: colors.warn, value: warn },
    { color: colors.crit, value: crit },
  ]),

  greenYellowRedHex(warn, crit):: $.thresholds([
    { color: colors.ok, value: null },
    { color: colors.warn, value: warn },
    { color: colors.crit, value: crit },
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

  prometheusTarget(expr, legendFormat, refId='A', instant=false, format=null):: {
    expr: expr,
    legendFormat: legendFormat,
    refId: refId,
  }
  + (if instant then { instant: true } else {})
  + (if format == null then {} else { format: format }),

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

  barGaugePanel(
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
    orientation='horizontal',
    displayMode='gradient',
    valueMode='color'
  ):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'bargauge',
    title: title,
    datasource: 'Prometheus',
    targets: [$.prometheusTarget(expr, legend)],
    options: {
      reduceOptions: { values: false, calcs: ['lastNotNull'], fields: '' },
      orientation: orientation,
      displayMode: displayMode,
      valueMode: valueMode,
      namePlacement: 'auto',
      showUnfilled: true,
      minVizWidth: 0,
      minVizHeight: 10,
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

  pieChartPanel(
    id,
    title,
    targets,
    x,
    y,
    w,
    h=6,
    unit=null,
    pieType='donut',
    legendPlacement='right',
    legendDisplayMode='table',
    legendValues=['value', 'percent']
  ):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'piechart',
    title: title,
    datasource: 'Prometheus',
    targets: std.mapWithIndex(
      function(i, t)
        $.prometheusTarget(t.expr, t.legend, std.get(t, 'refId', std.substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ', i, 1))),
      targets
    ),
    options: {
      pieType: pieType,
      displayLabels: [],
      reduceOptions: { values: false, calcs: ['lastNotNull'], fields: '' },
      legend: {
        displayMode: legendDisplayMode,
        placement: legendPlacement,
        showLegend: true,
        values: legendValues,
      },
      tooltip: { mode: 'multi', sort: 'desc' },
    },
    fieldConfig: {
      defaults:
        {
          color: { mode: 'palette-classic' },
          custom: {
            hideFrom: { legend: false, tooltip: false, viz: false },
          },
        }
        + (if unit == null then {} else { unit: unit }),
      overrides: [],
    },
  },

  stateTimelinePanel(
    id,
    title,
    targets,
    x,
    y,
    w,
    h=4,
    mappings=[],
    thresholds=null,
    unit='none',
    showLegend=false,
    showValue='never',
    rowHeight=0.84
  ):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'state-timeline',
    title: title,
    datasource: 'Prometheus',
    targets: std.mapWithIndex(
      function(i, t)
        $.prometheusTarget(t.expr, t.legend, std.get(t, 'refId', std.substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ', i, 1))),
      targets
    ),
    options: {
      alignValue: 'center',
      mergeValues: true,
      rowHeight: rowHeight,
      showValue: showValue,
      legend: { displayMode: 'list', placement: 'bottom', showLegend: showLegend },
      tooltip: { mode: 'multi', sort: 'desc' },
    },
    fieldConfig: {
      defaults: {
        unit: unit,
        color: { mode: 'thresholds' },
        thresholds: if thresholds == null then $.thresholds([
          { color: colors.ok, value: null },
          { color: colors.warn, value: 1 },
          { color: colors.crit, value: 2 },
        ]) else thresholds,
        mappings: mappings,
        custom: {
          fillOpacity: 82,
          lineWidth: 0,
          spanNulls: false,
          hideFrom: { legend: false, tooltip: false, viz: false },
        },
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
    overrides=[],
    fillOpacity=8,
    gradientMode='none',
    thresholdsStyle='off',
    stackingMode='none',
    tooltip='single',
    thresholds=null,
    drawStyle='line',
    lineInterpolation='smooth',
    lineWidth=2,
    pointSize=4,
    showPoints='never',
    barAlignment=0,
    legendDisplayMode='list',
    legendPlacement='bottom',
    legendCalcs=['lastNotNull'],
    tooltipSort='none',
    axisPlacement='auto',
    showLegend=true
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
      legend: { calcs: legendCalcs, displayMode: legendDisplayMode, placement: legendPlacement, showLegend: showLegend },
      tooltip: { mode: tooltip, sort: tooltipSort },
    },
    fieldConfig: {
      defaults:
        {
          color: { mode: 'palette-classic' },
          custom: {
            axisCenteredZero: false,
            axisColorMode: 'text',
            axisLabel: axisLabel,
            axisPlacement: axisPlacement,
            barAlignment: barAlignment,
            drawStyle: drawStyle,
            fillOpacity: fillOpacity,
            gradientMode: gradientMode,
            hideFrom: { legend: false, tooltip: false, viz: false },
            lineInterpolation: lineInterpolation,
            lineWidth: lineWidth,
            pointSize: pointSize,
            scaleDistribution: { type: 'linear' },
            showPoints: showPoints,
            spanNulls: true,
            stacking: { group: 'A', mode: stackingMode },
            thresholdsStyle: { mode: thresholdsStyle },
          },
        }
        + (if unit == null then {} else { unit: unit })
        + (if thresholds == null then {} else { thresholds: thresholds }),
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

  overrideUnitByName(name, unit, axisPlacement=null, axisLabel=null, color=null,
                     fillOpacity=null, gradientMode=null, drawStyle=null,
                     lineWidth=null):: {
    matcher: { id: 'byName', options: name },
    properties:
      [{ id: 'unit', value: unit }]
      + (if axisPlacement == null then [] else [{ id: 'custom.axisPlacement', value: axisPlacement }])
      + (if axisLabel == null then [] else [{ id: 'custom.axisLabel', value: axisLabel }])
      + (if color == null then [] else [{ id: 'color', value: color }])
      + (if fillOpacity == null then [] else [{ id: 'custom.fillOpacity', value: fillOpacity }])
      + (if gradientMode == null then [] else [{ id: 'custom.gradientMode', value: gradientMode }])
      + (if drawStyle == null then [] else [{ id: 'custom.drawStyle', value: drawStyle }])
      + (if lineWidth == null then [] else [{ id: 'custom.lineWidth', value: lineWidth }]),
  },
}

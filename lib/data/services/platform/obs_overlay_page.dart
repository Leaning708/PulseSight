/// OBS 浏览器源叠加页(自包含 HTML/CSS/JS,无外部资源)。
///
/// 视觉与动画逻辑从 Flutter 端精确移植,来源标注于各函数:
/// - 脉冲缩放序列:`lib/ui/core/widgets/heartbeat_pulse.dart`(pulseSequence)
/// - 心电图波形与绘制节奏:`lib/ui/core/widgets/heartbeat_heart.dart`
///   (`_ecgWave` / `ecgDrawInfo`),波形路径与心形同一 24 视窗坐标系
/// - 折线图:`lib/ui/core/widgets/heart_rate_chart.dart`(Y 轴动态范围等)
/// - 未连接灰心:`lib/ui/core/theme/app_theme.dart`(heartIdle)
///
/// 页面完全由 WebSocket 推送的数据驱动:`{status, bpm, style, history}`,
/// 其中 style 为 `OverlayStyle.toJson()`。断线每 2 秒自动重连。
const String obsOverlayHtml = r'''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>PulseSight Overlay</title>
<style>
  html, body {
    margin: 0; padding: 0;
    width: 100%; height: 100%;
    background: transparent;
    overflow: hidden;
  }
  #viewport {
    width: 100%; height: 100%;
    display: flex; align-items: center; justify-content: center;
  }
  #panel {
    display: flex; flex-direction: column;
    border-radius: 16px;
  }
  #contentArea {
    flex: 1; display: flex; overflow: hidden;
    flex-direction: column;
    align-items: center; justify-content: center;
  }
  #contentArea.with-chart { justify-content: flex-end; }
  #content { display: flex; align-items: center; justify-content: center; }
  #content.col { flex-direction: column; }
  #content.row { flex-direction: row; }
  #heartBox { display: flex; align-items: center; justify-content: center; }
  #heartSvg { overflow: visible; will-change: transform; }
  #bpmWrap { display: flex; }
  #bpmWrap.h { flex-direction: row; align-items: baseline; }
  #bpmWrap.v { flex-direction: column; align-items: center; }
  #bpmNumber { font-variant-numeric: tabular-nums; line-height: 1.1; }
  #ecgDigits { font-variant-numeric: tabular-nums; }
</style>
</head>
<body>
<div id="viewport">
  <div id="panel">
    <div id="contentArea">
      <div id="content">
        <div id="heartBox">
          <svg id="heartSvg" viewBox="2 3 20 18.35" width="64" height="64">
            <defs>
              <linearGradient id="heartGrad" x1="0" y1="0" x2="1" y2="1">
                <stop id="gradTop" offset="0" stop-color="#fff"/>
                <stop id="gradBottom" offset="1" stop-color="#fff"/>
              </linearGradient>
              <clipPath id="heartClip">
                <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>
              </clipPath>
            </defs>
            <path id="heartBody"
              d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"
              fill="url(#heartGrad)"/>
            <ellipse id="heartHighlight" cx="7.2" cy="7.0" rx="2.3" ry="1.1"
              transform="rotate(-0.5 7.2 7.0)" fill="#FFFFFF" opacity="0.35"/>
            <g id="ecgLayer" clip-path="url(#heartClip)">
              <path id="ecgGlow" fill="none" stroke-width="2.4"
                style="filter: blur(1.2px);"/>
              <path id="ecgLine" fill="none" stroke-width="1"
                stroke-linecap="round" stroke-linejoin="round" pathLength="1"/>
              <text id="ecgDigits" x="12" y="12.175" text-anchor="middle"
                dominant-baseline="central" font-size="7.5" font-weight="700"></text>
            </g>
          </svg>
        </div>
        <div id="bpmWrap">
          <span id="bpmNumber">--</span>
          <span id="bpmLabel">bpm</span>
        </div>
      </div>
    </div>
    <canvas id="chart" hidden></canvas>
  </div>
</div>
<script>
(() => {
  'use strict';

  const HEART_IDLE = '#9E9E9E'; // 移植自 AppTheme.heartIdle

  const $ = (id) => document.getElementById(id);
  const els = {
    viewport: $('viewport'), panel: $('panel'), contentArea: $('contentArea'),
    content: $('content'), heartBox: $('heartBox'), heartSvg: $('heartSvg'),
    heartBody: $('heartBody'), heartHighlight: $('heartHighlight'),
    gradTop: $('gradTop'), gradBottom: $('gradBottom'),
    ecgLayer: $('ecgLayer'), ecgGlow: $('ecgGlow'), ecgLine: $('ecgLine'),
    ecgDigits: $('ecgDigits'), bpmWrap: $('bpmWrap'),
    bpmNumber: $('bpmNumber'), bpmLabel: $('bpmLabel'), chart: $('chart'),
  };

  const state = {
    status: 'disconnected',
    bpm: null,
    style: {},
    history: [],
    chartDirty: false,
    lastStyleJson: null,
  };

  // ---- 颜色工具(ARGB 整数 → CSS) ----
  function argbToCss(v, alphaScale) {
    const n = Number(v) >>> 0;
    const a = ((n >>> 24) & 0xff) / 255 * (alphaScale == null ? 1 : alphaScale);
    const r = (n >>> 16) & 0xff, g = (n >>> 8) & 0xff, b = n & 0xff;
    return 'rgba(' + r + ',' + g + ',' + b + ',' + a.toFixed(4) + ')';
  }
  function argbToRgb(v) {
    const n = Number(v) >>> 0;
    return [(n >>> 16) & 0xff, (n >>> 8) & 0xff, n & 0xff];
  }
  // 心形渐变亮部:主色向白插值 0.28(移植 _HeartPainter._topColor)。
  function lerpWhite(v, t) {
    const [r, g, b] = argbToRgb(v);
    const mix = (c) => Math.round(c + (255 - c) * t);
    return 'rgb(' + mix(r) + ',' + mix(g) + ',' + mix(b) + ')';
  }

  // ---- 脉冲缩放序列(移植 HeartbeatPulse.pulseSequence) ----
  const easeOutCubic = (t) => 1 - Math.pow(1 - t, 3);
  const easeInOutCubic = (t) =>
    t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
  function pulseScale(phase) {
    if (phase < 0.18) return 1.0 + 0.22 * easeOutCubic(phase / 0.18);
    if (phase < 0.50) return 1.22 - 0.22 * easeInOutCubic((phase - 0.18) / 0.32);
    return 1.0;
  }

  // ---- ECG 波形(移植 _ecgWave 的 cos 圆顶波,R 峰居中) ----
  function bump(u, center, halfWidth, amplitude) {
    const d = Math.abs(u - center);
    if (d >= halfWidth) return 0;
    return amplitude * 0.5 * (1 + Math.cos(Math.PI * d / halfWidth));
  }
  function ecgWave(style, u) {
    switch (style) {
      case 'single':
        return bump(u, 0.5, 0.05, -5.2) + bump(u, 0.565, 0.04, 1.8);
      case 'classic':
        return bump(u, 0.30, 0.09, -1.1) + bump(u, 0.475, 0.028, 0.9) +
               bump(u, 0.5, 0.045, -5.2) + bump(u, 0.555, 0.045, 2.6) +
               bump(u, 0.75, 0.13, -2.0);
      default: // none / flat / digits:平线或非波形
        return 0;
    }
  }

  // ---- ECG 绘制节奏(移植 ecgDrawInfo;null = 本拍不绘制) ----
  function ecgDrawInfo(phase) {
    const DRAW_END = 0.45, HOLD_END = 0.60, FADE_END = 0.90;
    if (phase <= 0) return null;
    if (phase < DRAW_END) return { alpha: 1.0, progress: phase / DRAW_END };
    if (phase < HOLD_END) return { alpha: 1.0, progress: 1.0 };
    if (phase < FADE_END) {
      return { alpha: 1.0 - (phase - HOLD_END) / (FADE_END - HOLD_END), progress: 1.0 };
    }
    return null;
  }

  // ---- 样式应用(style 变化时重建 DOM 属性) ----
  function applyStyle() {
    const s = state.style;
    const json = JSON.stringify(s);
    if (json === state.lastStyleJson) return;
    state.lastStyleJson = json;

    const isRow = s.bpmPosition === 'left' || s.bpmPosition === 'right';
    const showBpm = s.bpmPosition !== 'hidden'; // hidden = 仅显示心形(移植 OverlayView)
    const heartFirst = s.bpmPosition === 'bottom' || s.bpmPosition === 'right';
    els.content.className = isRow ? 'row' : 'col';
    els.content.style.gap = (s.gap == null ? 6 : s.gap) + 'px';
    els.bpmWrap.style.gap = '4px';

    // 内容排序(移植 OverlayView):top/left → [数字, 心形];
    // bottom/right → [心形, 数字];hidden → 仅心形。
    while (els.content.firstChild) els.content.removeChild(els.content.firstChild);
    if (heartFirst) {
      els.content.appendChild(els.heartBox);
      if (showBpm) els.content.appendChild(els.bpmWrap);
    } else {
      if (showBpm) els.content.appendChild(els.bpmWrap);
      els.content.appendChild(els.heartBox);
    }
    els.bpmWrap.style.display = showBpm ? '' : 'none';

    // 内容不透明度(0.1 ~ 1.0,移植 OverlayView 的 Opacity;背景板独立)。
    const opacity = Math.min(Math.max(s.opacity == null ? 1.0 : s.opacity, 0.1), 1.0);
    els.content.style.opacity = opacity;

    // 背景板(颜色/透明度/宽高)与整体内容透明度分离(移植 OverlayView)。
    els.panel.style.width = (s.backgroundWidth == null ? 130 : s.backgroundWidth) + 'px';
    els.panel.style.height = (s.backgroundHeight == null ? 170 : s.backgroundHeight) + 'px';
    els.panel.style.background =
        argbToCss(s.backgroundColor == null ? 0xff000000 : s.backgroundColor,
            s.backgroundOpacity == null ? 0 : s.backgroundOpacity);

    // 心形大小:Flutter 端 s = size/20*0.94,等效为 SVG 尺寸取 0.94 倍。
    const heartSize = (s.heartSize == null ? 64 : s.heartSize) * 0.94;
    els.heartSvg.setAttribute('width', heartSize);
    els.heartSvg.setAttribute('height', heartSize);

    // 心形渐变颜色依赖连接状态,交给 render 的状态翻转检查更新;
    // 此处仅标记失效,确保样式变化(如改心形颜色)也立即生效。
    heartStateConnected = null;

    // 心率数字。
    const fontSize = s.bpmFontSize == null ? 20 : s.bpmFontSize;
    els.bpmNumber.style.fontSize = fontSize + 'px';
    els.bpmNumber.style.fontWeight = Math.round(s.textWeight == null ? 700 : s.textWeight);
    els.bpmNumber.style.fontFamily = s.textFontFamily || 'system-ui, sans-serif';
    els.bpmNumber.style.color = argbToCss(s.textColor == null ? 0xffffffff : s.textColor);
    els.bpmNumber.style.textShadow = '0 0 4px rgba(0,0,0,0.6)';
    els.bpmLabel.style.fontSize = Math.max(10, fontSize * 0.55) + 'px';
    els.bpmLabel.style.fontFamily = els.bpmNumber.style.fontFamily;
    els.bpmLabel.style.color =
        argbToCss(s.textColor == null ? 0xffffffff : s.textColor, 0.7);
    els.bpmLabel.style.textShadow = '0 0 4px rgba(0,0,0,0.6)';
    els.bpmLabel.style.display = s.showBpmLabel === false ? 'none' : 'inline';
    els.bpmWrap.className = isRow ? 'v' : 'h';

    // 心电图颜色。
    const ecgColor = argbToCss(s.ecgColor == null ? 0xffffffff : s.ecgColor);
    els.ecgLine.setAttribute('stroke', ecgColor);
    els.ecgGlow.setAttribute('stroke', ecgColor);
    els.ecgDigits.setAttribute('fill', ecgColor);

    // 折线图。
    if (s.showChart) {
      els.chart.hidden = false;
      els.contentArea.className = 'with-chart';
      els.chart.style.margin =
          (s.chartSpacing == null ? 8 : s.chartSpacing) + 'px 8px 8px 8px';
      els.chart.style.height = (s.chartHeight == null ? 84 : s.chartHeight) + 'px';
    } else {
      els.chart.hidden = true;
      els.contentArea.className = '';
    }
    fitViewport();
    state.chartDirty = true;
  }

  // ---- 视口适配:OBS 源尺寸小于面板时等比缩小(移植 FittedBox.scaleDown) ----
  function fitViewport() {
    const pw = els.panel.offsetWidth || 1, ph = els.panel.offsetHeight || 1;
    const scale = Math.min(
        1, els.viewport.clientWidth / pw, els.viewport.clientHeight / ph);
    els.panel.style.transform = scale < 1 ? 'scale(' + scale.toFixed(4) + ')' : 'none';
  }
  window.addEventListener('resize', fitViewport);

  // ---- 折线图(移植 _HeartRateChartPainter) ----
  function drawChart() {
    const s = state.style;
    if (!s.showChart) return;
    const canvas = els.chart;
    const dpr = window.devicePixelRatio || 1;
    const cssW = canvas.clientWidth, cssH = canvas.clientHeight;
    if (cssW === 0 || cssH === 0) return;
    if (canvas.width !== Math.round(cssW * dpr) ||
        canvas.height !== Math.round(cssH * dpr)) {
      canvas.width = Math.round(cssW * dpr);
      canvas.height = Math.round(cssH * dpr);
    }
    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, cssW, cssH);

    const lineColorCss =
        argbToCss(s.chartLineColor == null ? 0xffffffff : s.chartLineColor);
    const lineRgb = argbToRgb(s.chartLineColor == null ? 0xffffffff : s.chartLineColor);

    // 水平网格线(3 条)。
    ctx.strokeStyle = 'rgba(255,255,255,0.08)';
    ctx.lineWidth = 1;
    for (let i = 1; i <= 3; i++) {
      const y = cssH * i / 4;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(cssW, y);
      ctx.stroke();
    }

    const values = state.history;
    if (values.length < 2) {
      // 数据不足:居中平线占位(移植)。
      ctx.strokeStyle = argbToCss(
          s.chartLineColor == null ? 0xffffffff : s.chartLineColor, 0.3);
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(cssW * 0.1, cssH / 2);
      ctx.lineTo(cssW * 0.9, cssH / 2);
      ctx.stroke();
      return;
    }

    // Y 轴动态范围:min/max ± 5bpm,跨度不足 20bpm 自动补足。
    let minY = Math.min.apply(null, values) - 5;
    let maxY = Math.max.apply(null, values) + 5;
    if (maxY - minY < 20) {
      const mid = (minY + maxY) / 2;
      minY = mid - 10;
      maxY = mid + 10;
    }
    // X 轴向内收 5px:canvas 会裁切位图外内容,末端点半径 + 描边
    // 需要余量才能完整显示(Flutter 端由 SizedBox 外边距容纳,无需收缩)。
    const EDGE_INSET = 5;
    const xOf = (i) =>
        EDGE_INSET + (cssW - EDGE_INSET * 2) * i / (values.length - 1);
    const yOf = (bpm) => cssH - (bpm - minY) / (maxY - minY) * cssH;

    const trace = () => {
      ctx.beginPath();
      for (let i = 0; i < values.length; i++) {
        const x = xOf(i), y = yOf(values[i]);
        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
    };

    // 面积填充。
    ctx.fillStyle = 'rgba(' + lineRgb.join(',') + ',0.12)';
    trace();
    ctx.lineTo(cssW, cssH);
    ctx.lineTo(0, cssH);
    ctx.closePath();
    ctx.fill();

    // 深色可读性描边 → 彩色折线。
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.strokeStyle = 'rgba(0,0,0,0.4)';
    ctx.lineWidth = 3;
    trace();
    ctx.stroke();
    ctx.strokeStyle = lineColorCss;
    ctx.lineWidth = 2;
    trace();
    ctx.stroke();

    // 末端当前点(白描边突出)。
    const lx = xOf(values.length - 1), ly = yOf(values[values.length - 1]);
    ctx.beginPath();
    ctx.arc(lx, ly, 3.5, 0, Math.PI * 2);
    ctx.fillStyle = lineColorCss;
    ctx.fill();
    ctx.strokeStyle = 'rgba(255,255,255,0.8)';
    ctx.lineWidth = 1.5;
    ctx.stroke();
  }

  // ---- 逐帧渲染:脉冲缩放 + ECG + 数字律动 ----
  let phase = 0;
  let lastFrame = null;
  // 心形颜色跟随连接状态;null = 待应用(首帧/样式变化后)。
  let heartStateConnected = null;

  function buildEcgPath(style) {
    // 波形路径:24 视窗内 x 3→21,基线 12.175(移植 _drawEcg)。
    const startX = 3.0, span = 18.0;
    let d = '';
    for (let x = startX; x <= startX + span + 1e-9; x += 0.25) {
      const u = (x - startX) / span;
      const y = 12.175 + ecgWave(style, u);
      d += (d === '' ? 'M' : 'L') + x.toFixed(2) + ' ' + y.toFixed(3);
    }
    return d;
  }

  function render(now) {
    if (lastFrame == null) lastFrame = now;
    const dt = Math.min(now - lastFrame, 200); // 长帧不跳变过多
    lastFrame = now;

    const s = state.style;
    const connected = state.status === 'connected';
    const bpm = connected ? state.bpm : null;

    // 心形颜色:连接态用样式颜色,未连接灰心(移植 AppTheme.heartIdle)。
    // 状态翻转或样式变化时才更新,避免每帧改 SVG 属性。
    if (heartStateConnected !== connected) {
      heartStateConnected = connected;
      const heartColor = connected
          ? (s.heartColor == null ? 0xffe23a3a : s.heartColor)
          : 0xff9e9e9e;
      els.gradTop.setAttribute('stop-color', lerpWhite(heartColor, 0.28));
      els.gradBottom.setAttribute('stop-color', argbToCss(heartColor));
    }

    // 心率数字文本(移植 BpmDisplay:未连接显示 '--')。
    const bpmText = bpm == null ? '--' : String(bpm);
    if (els.bpmNumber.textContent !== bpmText) {
      els.bpmNumber.textContent = bpmText;
    }

    // 相位推进:周期 = 60000/bpm(1 bpm = 每分钟一拍)。
    if (bpm != null && bpm > 0) {
      phase = (phase + dt / (60000 / bpm)) % 1.0;
    }
    const scale = (connected && s.heartPulseEnabled !== false)
        ? pulseScale(phase) : 1.0;
    els.heartSvg.style.transform = 'scale(' + scale.toFixed(4) + ')';

    // 心跳辉光:强度随脉冲扩张变化(移植 _HeartPainter 辉光段)。
    const glowRadius = s.glowRadius == null ? 1.0 : s.glowRadius;
    const glowOpacity = s.glowOpacity == null ? 0.5 : s.glowOpacity;
    if (connected && scale > 1.0 && glowOpacity > 0 && glowRadius > 0) {
      const blur = (scale - 1.0) * 90 * glowRadius;
      const [r, g, b] = argbToRgb(s.heartColor == null ? 0xffe23a3a : s.heartColor);
      const alpha = Math.min(0.45 * glowOpacity, 0.85);
      els.heartSvg.style.filter =
          'drop-shadow(0 0 ' + blur.toFixed(1) + 'px rgba(' + r + ',' + g + ',' + b + ',' + alpha.toFixed(3) + '))';
    } else {
      els.heartSvg.style.filter = 'none';
    }

    // 心电图绘制。
    const showEcg = connected && s.ecgStyle !== 'none';
    els.ecgLayer.style.display = showEcg ? '' : 'none';
    if (showEcg) {
      const info = ecgDrawInfo(phase);
      if (s.ecgStyle === 'digits') {
        els.ecgLine.style.display = 'none';
        els.ecgGlow.style.display = 'none';
        els.ecgDigits.style.display = info == null ? 'none' : '';
        els.ecgDigits.textContent = bpm == null ? '--' : String(bpm);
        els.ecgDigits.style.opacity =
            info == null ? 0 : (0.9 * info.alpha * info.progress).toFixed(3);
      } else {
        els.ecgDigits.style.display = 'none';
        if (info == null) {
          // 相位 0/静置期不绘制:零长度路径描边会渲染成圆点伪影(移植修复)。
          els.ecgLine.style.display = 'none';
          els.ecgGlow.style.display = 'none';
        } else {
          els.ecgLine.style.display = '';
          els.ecgGlow.style.display = '';
          els.ecgLine.setAttribute('d', buildEcgPath(s.ecgStyle));
          els.ecgGlow.setAttribute('d', els.ecgLine.getAttribute('d'));
          els.ecgLine.style.strokeDasharray = info.progress.toFixed(4) + ' 1';
          els.ecgGlow.style.strokeDasharray = info.progress.toFixed(4) + ' 1';
          els.ecgLine.style.opacity = info.alpha.toFixed(3);
          els.ecgGlow.style.opacity = (0.30 * info.alpha).toFixed(3);
        }
      }
    }

    // 数字律动(与心形共享同一相位,移植 ScaleTransition(pulse))。
    els.bpmWrap.style.transform =
        s.textPulseEnabled === false || !connected
            ? 'none'
            : 'scale(' + pulseScale(phase).toFixed(4) + ')';

    if (state.chartDirty) {
      drawChart();
      state.chartDirty = false;
    }
    requestAnimationFrame(render);
  }
  requestAnimationFrame(render);

  // ---- WebSocket 数据通道:断线 2 秒自动重连 ----
  let ws = null;
  function connect() {
    const proto = location.protocol === 'https:' ? 'wss' : 'ws';
    ws = new WebSocket(proto + '://' + location.host + '/ws');
    ws.onmessage = (event) => {
      const msg = JSON.parse(event.data);
      const prevStyle = state.lastStyleJson;
      state.status = msg.status;
      state.bpm = msg.bpm;
      state.style = msg.style || {};
      state.history = msg.history || [];
      state.chartDirty = true;
      if (JSON.stringify(state.style) !== prevStyle) {
        state.lastStyleJson = null; // 强制重建样式
      }
      applyStyle();
    };
    ws.onclose = () => {
      ws = null;
      setTimeout(connect, 2000);
    };
    ws.onerror = () => ws.close();
  }
  connect();
})();
</script>
</body>
</html>
''';

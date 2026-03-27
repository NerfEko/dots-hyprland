pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick

/**
 * 20-bar audio visualizer canvas.
 * Smoothly interpolates toward target bar heights at 60fps.
 * Bars fade to flat when active is false.
 */
Canvas {
    id: root

    property list<real> bars: []       // source data, 0..1 per bar (any count)
    property bool       active: false
    property color      color: Appearance.m3colors.m3primary
    property int        barCount: 20

    // Internal smoothed display values
    property var displayBars: {
        const arr = [];
        for (let i = 0; i < barCount; i++) arr.push(0.0);
        return arr;
    }

    // Minimum bar height as a fraction of total height (keeps bars visible at rest)
    readonly property real minBarFrac: 0.04

    // Smoothing factor: 0..1 — higher = faster tracking
    readonly property real smoothing: active ? 0.28 : 0.12

    // Sample the source bars down to barCount evenly spaced values
    function sampleBars(): list<real> {
        if (!active || bars.length === 0) {
            const flat = [];
            for (let i = 0; i < barCount; i++) flat.push(minBarFrac);
            return flat;
        }
        const src  = bars;
        const n    = src.length;
        const out  = [];
        const step = n / barCount;
        for (let i = 0; i < barCount; i++) {
            const idx = Math.floor(i * step);
            // small average over a few samples for smoother look
            let acc = 0;
            const w = Math.max(1, Math.floor(step));
            for (let j = 0; j < w; j++) acc += (src[Math.min(n - 1, idx + j)] ?? 0);
            out.push(Math.max(minBarFrac, acc / w));
        }
        return out;
    }

    Timer {
        id: animTimer
        interval: 16       // ~60fps
        running: true
        repeat: true
        onTriggered: {
            const target  = root.sampleBars();
            let changed   = false;
            const display = root.displayBars.slice();
            for (let i = 0; i < root.barCount; i++) {
                const t    = target[i] ?? root.minBarFrac;
                const diff = t - display[i];
                if (Math.abs(diff) > 0.001) {
                    display[i] += diff * root.smoothing;
                    changed = true;
                }
            }
            if (changed) {
                root.displayBars = display;
                root.requestPaint();
            }
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        const n      = root.barCount;
        const totalW = width;
        const slotW  = totalW / n;
        const barW   = slotW * 0.55;
        const gap    = (slotW - barW) / 2;
        const c      = root.color;
        const h      = height;

        for (let i = 0; i < n; i++) {
            const frac    = Math.max(root.minBarFrac, root.displayBars[i] ?? root.minBarFrac);
            const barH    = frac * h;
            const x       = i * slotW + gap;
            const y       = (h - barH) / 2;
            const r       = Math.min(barW / 2, barH / 2, 5);

            // gradient: brighter center, softer at tips
            const grad = ctx.createLinearGradient(0, y, 0, y + barH);
            grad.addColorStop(0.0, Qt.rgba(c.r, c.g, c.b, 0.4));
            grad.addColorStop(0.5, Qt.rgba(c.r, c.g, c.b, 0.9));
            grad.addColorStop(1.0, Qt.rgba(c.r, c.g, c.b, 0.4));
            ctx.fillStyle = grad;

            ctx.beginPath();
            if (ctx.roundRect) {
                ctx.roundRect(x, y, barW, barH, r);
            } else {
                ctx.rect(x, y, barW, barH);
            }
            ctx.fill();
        }
    }
}

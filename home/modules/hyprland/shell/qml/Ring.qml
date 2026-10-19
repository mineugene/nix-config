import QtQuick
import "corner.js" as Corner

// A square meter: a rounded-rectangle tile whose outline sweeps from twelve
// o'clock. `value` is a percentage of the full perimeter.
Item {
    id: ring

    property real value: 0
    property bool clockwise: true
    property color fill: Tokens.c.surface
    property color arc: Tokens.c.foreground
    property real thickness: 3
    property real cornerRadius: Tokens.radius.general
    property real roundingPower: Tokens.cornerRoundingPower
    default property alias content: holder.data

    implicitWidth: Tokens.barHeight
    implicitHeight: Tokens.barHeight

    // Polls step in whole percent, so the outline eases between readings.
    Behavior on value {
        NumberAnimation {
            duration: Tokens.normal
            easing.type: Easing.OutCubic
        }
    }

    onValueChanged: canvas.requestPaint()
    onFillChanged: canvas.requestPaint()
    onArcChanged: canvas.requestPaint()
    onThicknessChanged: canvas.requestPaint()
    onCornerRadiusChanged: canvas.requestPaint()
    onRoundingPowerChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width;
            const h = height;
            const power = Corner.clampPower(ring.roundingPower);
            const custom = power !== 2 && ring.cornerRadius > 0;
            const radius = Math.min(ring.cornerRadius, w / 2, h / 2);
            const effRadius = Math.min(Corner.effectiveRadius(ring.cornerRadius, power), w / 2, h / 2);

            if (ring.fill.a > 0) {
                ctx.fillStyle = ring.fill;
                if (custom) {
                    const pts = Corner.outline(w, h, effRadius, power);
                    ctx.beginPath();
                    for (let i = 0; i < pts.length; i++) {
                        if (i === 0)
                            ctx.moveTo(pts[i].x, pts[i].y);
                        else
                            ctx.lineTo(pts[i].x, pts[i].y);
                    }
                    ctx.closePath();
                } else
                    roundedRect(ctx, 0, 0, w, h, radius);
                ctx.fill();
            }

            const v = Math.min(ring.value, 100);
            if (v <= 0)
                return;

            const inset = ring.thickness / 2;
            const bw = w - ring.thickness;
            const bh = h - ring.thickness;
            const br = Math.max(0, (custom ? effRadius : radius) - inset);
            const straight = bh - 2 * br;
            const end = bw - 2 * br;
            const half = bw / 2 - br;
            const quarter = Math.PI * br / 2;

            function circularPointAt(distance) {
                let d = ((distance % total) + total) % total;
                if (d <= half)
                    return { x: bw / 2 + d, y: 0 };
                d -= half;
                if (d <= quarter) {
                    const angle = -Math.PI / 2 + d / br;
                    return { x: bw - br + br * Math.cos(angle), y: br + br * Math.sin(angle) };
                }
                d -= quarter;
                if (d <= straight)
                    return { x: bw, y: br + d };
                d -= straight;
                if (d <= quarter) {
                    const angle = d / br;
                    return { x: bw - br + br * Math.cos(angle), y: bh - br + br * Math.sin(angle) };
                }
                d -= quarter;
                if (d <= end)
                    return { x: bw - br - d, y: bh };
                d -= end;
                if (d <= quarter) {
                    const angle = Math.PI / 2 + d / br;
                    return { x: br + br * Math.cos(angle), y: bh - br + br * Math.sin(angle) };
                }
                d -= quarter;
                if (d <= straight)
                    return { x: 0, y: bh - br - d };
                d -= straight;
                if (d <= quarter) {
                    const angle = Math.PI + d / br;
                    return { x: br + br * Math.cos(angle), y: br + br * Math.sin(angle) };
                }
                d -= quarter;
                return { x: br + d, y: 0 };
            }

            let total = 2 * half + end + 2 * straight + 4 * quarter;
            let pointAt = circularPointAt;

            if (custom) {
                const base = Corner.outline(bw, bh, br, power);
                // Split the top edge at its midpoint so the sweep starts at
                // twelve o'clock like the circular case.
                const pts = [{ x: bw / 2, y: 0 }, base[1]].concat(base.slice(2), [base[0]]);
                const segs = [];
                total = 0;
                for (let i = 0; i < pts.length; i++) {
                    const a = pts[i];
                    const b = pts[(i + 1) % pts.length];
                    const dx = b.x - a.x;
                    const dy = b.y - a.y;
                    const len = Math.sqrt(dx * dx + dy * dy);
                    segs.push({ a, b, len });
                    total += len;
                }
                pointAt = distance => {
                    let d = ((distance % total) + total) % total;
                    for (const s of segs) {
                        if (d <= s.len) {
                            const f = s.len > 0 ? d / s.len : 0;
                            return { x: s.a.x + (s.b.x - s.a.x) * f, y: s.a.y + (s.b.y - s.a.y) * f };
                        }
                        d -= s.len;
                    }
                    return { x: pts[0].x, y: pts[0].y };
                };
            }

            const length = total * v / 100;
            const steps = Math.max(2, Math.ceil(length / 2));
            ctx.strokeStyle = ring.arc;
            ctx.lineWidth = ring.thickness;
            ctx.beginPath();
            for (let step = 0; step <= steps; step++) {
                const p = pointAt(ring.clockwise ? length * step / steps : -length * step / steps);
                if (step === 0)
                    ctx.moveTo(inset + p.x, inset + p.y);
                else
                    ctx.lineTo(inset + p.x, inset + p.y);
            }
            ctx.stroke();
        }
    }

    Item {
        id: holder
        anchors.fill: parent
    }

    function roundedRect(ctx, x, y, w, h, r) {
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + w - r, y);
        ctx.arcTo(x + w, y, x + w, y + r, r);
        ctx.lineTo(x + w, y + h - r);
        ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
        ctx.lineTo(x + r, y + h);
        ctx.arcTo(x, y + h, x, y + h - r, r);
        ctx.lineTo(x, y + r);
        ctx.arcTo(x, y, x + r, y, r);
        ctx.closePath();
    }
}

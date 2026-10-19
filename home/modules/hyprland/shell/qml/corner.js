.pragma library

// Hyprland draws a rounded corner on the boundary |x/rx|^power + |y/ry|^power
// = 1. Power 1 is a straight chamfer, 2 a circular arc, and higher powers
// squarer superellipse corners. These helpers mirror that geometry so shell
// surfaces match the compositor.

// Hyprland clamps to a finite 1-10 range and falls back to 2.
function clampPower(value) {
    const n = Number(value);
    return isFinite(n) ? Math.max(1, Math.min(n, 10)) : 2;
}

// Hyprland scales the configured radius by power / 2 so a change of power
// keeps the perceived roundness.
function effectiveRadius(radius, power) {
    return Math.max(0, Number(radius) || 0) * clampPower(power) / 2;
}

function cornerRadius(value) {
    return Math.max(0, Number(value) || 0);
}

// Closed point list for a superellipse rounded rectangle. Start is the
// top-left tangent, running clockwise. Power 2 is left to the caller's exact
// circular drawing.
function outline(w, h, radius, power) {
    return outlineRadii(w, h, { tl: radius, tr: radius, br: radius, bl: radius }, power);
}

// As `outline`, with a separate radius per corner.
function outlineRadii(w, h, radii, power) {
    const n = clampPower(power);
    if (w <= 0 || h <= 0)
        return [];
    const lim = Math.min(w, h) / 2;
    const tl = Math.min(cornerRadius(radii.tl), lim);
    const tr = Math.min(cornerRadius(radii.tr), lim);
    const br = Math.min(cornerRadius(radii.br), lim);
    const bl = Math.min(cornerRadius(radii.bl), lim);
    if (tl === 0 && tr === 0 && br === 0 && bl === 0)
        return [{ x: 0, y: 0 }, { x: w, y: 0 }, { x: w, y: h }, { x: 0, y: h }];

    const steps = 24;
    const pts = [{ x: tl, y: 0 }, { x: w - tr, y: 0 }];
    appendCorner(pts, w - tr, tr, 0, tr, n, steps);
    pts.push({ x: w, y: tr });
    pts.push({ x: w, y: h - br });
    appendCorner(pts, w - br, h - br, 1, br, n, steps);
    pts.push({ x: w - br, y: h });
    pts.push({ x: bl, y: h });
    appendCorner(pts, bl, h - bl, 2, bl, n, steps);
    pts.push({ x: 0, y: h - bl });
    pts.push({ x: 0, y: tl });
    appendCorner(pts, tl, tl, 3, tl, n, steps);
    return pts;
}

function appendCorner(pts, cx, cy, side, r, n, steps) {
    for (let i = 1; i < steps; i++) {
        const t = Math.PI / 2 * (i / steps);
        const s = Math.pow(Math.sin(t), 2 / n);
        const c = Math.pow(Math.cos(t), 2 / n);
        if (side === 0)
            pts.push({ x: cx + r * s, y: cy - r * c });
        else if (side === 1)
            pts.push({ x: cx + r * c, y: cy + r * s });
        else if (side === 2)
            pts.push({ x: cx - r * s, y: cy + r * c });
        else
            pts.push({ x: cx - r * c, y: cy - r * s });
    }
}

function pointsToString(pts, x, y) {
    if (pts.length === 0)
        return "";
    let d = "M " + (x + pts[0].x) + " " + (y + pts[0].y);
    for (let i = 1; i < pts.length; i++)
        d += " L " + (x + pts[i].x) + " " + (y + pts[i].y);
    return d + " Z";
}

// SVG path for a superellipse rounded rectangle drawn at (x, y).
function pathString(x, y, w, h, radius, power) {
    return pathStringRadii(x, y, w, h, { tl: radius, tr: radius, br: radius, bl: radius }, power);
}

function pathStringRadii(x, y, w, h, radii, power) {
    return pointsToString(outlineRadii(w, h, radii, power), x, y);
}
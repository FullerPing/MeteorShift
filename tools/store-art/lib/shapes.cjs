// Glossy cartoon primitives for the store art: ink outline, darker lip, soft top shine.
// Everything returns SVG strings. Coordinates are in the 1920x1080 canvas unless a function says otherwise.
const { INK, simpleText } = require('./type.cjs');

let counter = 0;
const uid = p => `${p}${counter++}`;

function rng(seed) {
  let s = seed >>> 0;
  return (a = 0, b = 1) => {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
    return a + (b - a) * (s / 4294967296);
  };
}

const f = n => Math.round(n * 100) / 100;

// ---- shape descriptors: { shape(attrs) -> element string, bb: [x, y, w, h] } ----
const rect = (x, y, w, h, r = 0) => ({ bb: [x, y, w, h], shape: a => `<rect x="${f(x)}" y="${f(y)}" width="${f(w)}" height="${f(h)}" rx="${f(r)}" ${a}/>` });
const ellipse = (cx, cy, rx, ry) => ({ bb: [cx - rx, cy - ry, rx * 2, ry * 2], shape: a => `<ellipse cx="${f(cx)}" cy="${f(cy)}" rx="${f(rx)}" ry="${f(ry)}" ${a}/>` });
const path = (d, bb) => ({ bb, shape: a => `<path d="${d}" ${a}/>` });
const poly = pts => {
  const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
  const x = Math.min(...xs), y = Math.min(...ys);
  return path('M' + pts.map(p => `${f(p[0])} ${f(p[1])}`).join('L') + 'Z', [x, y, Math.max(...xs) - x, Math.max(...ys) - y]);
};

// A smooth closed blob through points (Catmull-Rom to Bezier).
function blobPath(pts) {
  const n = pts.length;
  let d = `M${f(pts[0][0])} ${f(pts[0][1])}`;
  for (let i = 0; i < n; i++) {
    const p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
    d += `C${f(p1[0] + (p2[0] - p0[0]) / 6)} ${f(p1[1] + (p2[1] - p0[1]) / 6)} ${f(p2[0] - (p3[0] - p1[0]) / 6)} ${f(p2[1] - (p3[1] - p1[1]) / 6)} ${f(p2[0])} ${f(p2[1])}`;
  }
  return d + 'Z';
}
const blob = pts => {
  const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
  const x = Math.min(...xs), y = Math.min(...ys);
  return path(blobPath(pts), [x, y, Math.max(...xs) - x, Math.max(...ys) - y]);
};

// ---- gradients ----
function lin(stops, { x1 = 0, y1 = 0, x2 = 0, y2 = 1 } = {}) {
  const id = uid('lg');
  return { id, ref: `url(#${id})`, defs: `<linearGradient id="${id}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}">${stops.map(([o, c, a]) => `<stop offset="${o}" stop-color="${c}"${a === undefined ? '' : ` stop-opacity="${a}"`}/>`).join('')}</linearGradient>` };
}
function rad(stops, { cx = .5, cy = .5, r = .5, fx, fy } = {}) {
  const id = uid('rg');
  return { id, ref: `url(#${id})`, defs: `<radialGradient id="${id}" cx="${cx}" cy="${cy}" r="${r}"${fx === undefined ? '' : ` fx="${fx}" fy="${fy}"`}>${stops.map(([o, c, a]) => `<stop offset="${o}" stop-color="${c}"${a === undefined ? '' : ` stop-opacity="${a}"`}/>`).join('')}</radialGradient>` };
}
const vgrad = (top, bottom) => lin([[0, top], [1, bottom]]);

// ---- glossy body: lip, gradient face with ink outline, soft shine ----
function gloss(desc, { top = '#FFF078', bottom = '#FFB21E', lip = '#B06806', ink = INK, sw = 6, lipDy, shine = .32, fill, noLip = false } = {}) {
  const [x, y, w, h] = desc.bb;
  const g = vgrad(top, bottom), c = uid('cp');
  const dy = noLip ? 0 : (lipDy === undefined ? sw * 1.1 : lipDy);
  return `<defs>${g.defs}<clipPath id="${c}">${desc.shape('')}</clipPath></defs><g stroke-linejoin="round" stroke-linecap="round">
    ${noLip ? '' : `<g transform="translate(0 ${f(dy)})">${desc.shape(`fill="${lip}" stroke="${ink}" stroke-width="${sw}"`)}</g>`}
    ${desc.shape(`fill="${fill || g.ref}" stroke="${ink}" stroke-width="${sw}"`)}
    ${shine ? `<g clip-path="url(#${c})"><ellipse cx="${f(x + w * .42)}" cy="${f(y + h * .12)}" rx="${f(w * .5)}" ry="${f(h * .2)}" fill="white" opacity="${shine}"/></g>` : ''}</g>`;
}

// ---- sparkles, bursts, rays ----
function sparkle(x, y, s, { fill = '#FFFFFF', ink = true, rot = 0 } = {}) {
  const d = `M0 ${-s}Q${f(s * .14)} ${f(-s * .14)} ${s} 0Q${f(s * .14)} ${f(s * .14)} 0 ${s}Q${f(-s * .14)} ${f(s * .14)} ${-s} 0Q${f(-s * .14)} ${f(-s * .14)} 0 ${-s}Z`;
  return `<path d="${d}" transform="translate(${f(x)} ${f(y)}) rotate(${rot})" fill="${fill}"${ink ? ` stroke="${INK}" stroke-width="${f(Math.max(2, s * .16))}" stroke-linejoin="round"` : ''}/>`;
}
function sparkles(list) { return list.map(s => sparkle(...s)).join(''); }

function starburst(cx, cy, r, { points = 8, inner = .5, top = '#FFFFFF', bottom = '#FFD250', sw = 8, rot = 0 } = {}) {
  const pts = [];
  for (let i = 0; i < points * 2; i++) {
    const a = rot + i * Math.PI / points - Math.PI / 2;
    const rr = i % 2 ? r * inner : r;
    pts.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr]);
  }
  return gloss(poly(pts), { top, bottom, lip: '#E88A10', sw, shine: 0, noLip: true });
}

function rays(cx, cy, count, length, { color = '#FFFFFF', alpha = .2, rot = 0, spread = .5 } = {}) {
  let out = '';
  const step = Math.PI * 2 / count;
  for (let i = 0; i < count; i++) {
    const a0 = rot + i * step, a1 = a0 + step * spread;
    out += `M${f(cx)} ${f(cy)}L${f(cx + Math.cos(a0) * length)} ${f(cy + Math.sin(a0) * length)}L${f(cx + Math.cos(a1) * length)} ${f(cy + Math.sin(a1) * length)}Z`;
  }
  return `<path d="${out}" fill="${color}" opacity="${alpha}"/>`;
}

// ---- the red before/after arrow (pointing along +x from x,y) ----
function arrow(x, y, len, { angle = 0, thick = 1, face = ['#FF6876', '#E21A38'], lip = '#8C0A1E', bend = 0 } = {}) {
  const h = 74 * thick, sh = h * .36, hl = h * 1.05;
  const d = `M0 ${-sh}L${len - hl} ${-sh}L${len - hl} ${-h}L${len} 0L${len - hl} ${h}L${len - hl} ${sh}L0 ${sh}Q${f(h * .25)} 0 0 ${-sh}Z`;
  const g = vgrad(face[0], face[1]);
  return `<defs>${g.defs}</defs><g transform="translate(${f(x)} ${f(y)}) rotate(${angle})" stroke-linejoin="round">
    <path d="${d}" transform="translate(0 ${f(h * .14)})" fill="${lip}" stroke="${INK}" stroke-width="${f(h * .34)}"/>
    <path d="${d}" fill="${INK}" stroke="${INK}" stroke-width="${f(h * .34)}"/>
    <path d="${d}" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="${f(h * .2)}"/>
    <path d="${d}" fill="${g.ref}"/>
    <path d="M${f(h * .2)} ${f(-sh * .45)}L${f(len - hl - 8)} ${f(-sh * .45)}" stroke="white" stroke-opacity=".5" stroke-width="${f(h * .1)}" stroke-linecap="round"/></g>`;
}

// ---- text ribbons and pills in any colour ----
function banner(text, width, H, { top = '#FFF078', bottom = '#FFB21E', lip = '#B06806', color = '#FFFFFF', tilt = 0, tail = true } = {}) {
  const label = simpleText(text, H * .5);
  const k = Math.min(1, (width * .8) / label.width);
  const t = tail ? H * .36 : 0;
  const d = tail
    ? `M${-t} ${H * .05}Q${width / 2} ${-H * .12} ${width + t} ${H * .05}L${width + t * .55} ${H * .5}L${width + t} ${H * .95}Q${width / 2} ${H * 1.08} ${-t} ${H * .95}L${-t * .55} ${H * .5}Z`
    : `M0 0H${width}V${H}H0Z`;
  const body = gloss(path(d, [-t, 0, width + t * 2, H]), { top, bottom, lip, sw: Math.max(4, H * .075) });
  const textSvg = label.body.replace('fill="white"', `fill="${color}"`);
  return `<g transform="rotate(${tilt} ${f(width / 2)} ${f(H / 2)})">${body}<g transform="translate(${f((width - label.width * k) / 2)} ${f(H * .5 + H * .25)}) scale(${f(k)})">${textSvg}</g></g>`;
}
function pill(text, width, H, opts = {}) {
  const label = simpleText(text, H * .46);
  const k = Math.min(1, (width * .78) / label.width);
  const body = gloss(rect(0, 0, width, H, H * .5), { top: '#B2FF4A', bottom: '#32C41E', lip: '#166E12', sw: Math.max(4, H * .07), ...opts });
  return `${body}<g transform="translate(${f((width - label.width * k) / 2 + (opts.pad || 0))} ${f(H * .5 + H * .23)}) scale(${f(k)})">${label.body}</g>`;
}

// ---- small props ----
function coin(x, y, r, tilt = 0) {
  const e = ellipse(0, 0, r * .86, r);
  return `<g transform="translate(${f(x)} ${f(y)}) rotate(${tilt})">${gloss(e, { top: '#FFF078', bottom: '#FFB21E', lip: '#B06806', sw: Math.max(3, r * .16), shine: .35 })}
    <ellipse rx="${f(r * .56)}" ry="${f(r * .68)}" fill="none" stroke="#C97C0A" stroke-width="${f(r * .12)}"/>${sparkle(0, 0, r * .36, { fill: '#FFFBD0', ink: false })}</g>`;
}

// A bar in 3/4 view: top, front and side faces.
function bar(x, y, w, h, d, { top = '#FFE07A', front = ['#FFC840', '#E89A12'], side = '#B86E08', lip } = {}) {
  const dx = d * .8, dy = d * .5, sw = Math.max(3, w * .05);
  const fr = vgrad(front[0], front[1]);
  const topFace = `M${x} ${y}L${x + dx} ${y - dy}L${x + w + dx} ${y - dy}L${x + w} ${y}Z`;
  const sideFace = `M${x + w} ${y}L${x + w + dx} ${y - dy}L${x + w + dx} ${y + h - dy}L${x + w} ${y + h}Z`;
  return `<defs>${fr.defs}</defs><g stroke="${INK}" stroke-width="${sw}" stroke-linejoin="round">
    <path d="${sideFace}" fill="${side}"/><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${f(h * .12)}" fill="${fr.ref}"/><path d="${topFace}" fill="${top}"/></g>
    <path d="M${x + w * .12} ${y + h * .22}H${x + w * .55}" stroke="white" stroke-opacity=".6" stroke-width="${f(h * .12)}" stroke-linecap="round"/>`;
}

// A fluffy outlined cloud made of circles: ink behind, face on top.
function cloud(x, y, s, { fill = '#FFFFFF', shade = '#EEECFC', alpha = 1 } = {}) {
  const parts = [[0, 0, 1], [-.9, .25, .72], [.95, .2, .8], [-.45, -.4, .7], [.45, -.5, .78], [1.6, .4, .5], [-1.5, .42, .5]];
  const c = parts.map(([dx, dy, k]) => `cx="${f(dx * s)}" cy="${f(dy * s)}" r="${f(k * s * .6)}"`);
  const base = `<rect x="${f(-1.6 * s)}" y="${f(.12 * s)}" width="${f(3.2 * s)}" height="${f(.5 * s)}" rx="${f(.25 * s)}"`;
  return `<g transform="translate(${f(x)} ${f(y)})" opacity="${alpha}" stroke-linejoin="round">
    <g fill="${INK}" stroke="${INK}" stroke-width="${f(s * .2)}">${c.map(a => `<circle ${a}/>`).join('')}${base}/></g>
    <g fill="${fill}">${c.map(a => `<circle ${a}/>`).join('')}${base}/></g>
    <rect x="${f(-1.5 * s)}" y="${f(.3 * s)}" width="${f(3 * s)}" height="${f(.32 * s)}" rx="${f(.16 * s)}" fill="${shade}"/></g>`;
}

// soft drop shadow ellipse on the ground
const shadow = (cx, cy, rx, ry, a = .3) => `<ellipse cx="${f(cx)}" cy="${f(cy)}" rx="${f(rx)}" ry="${f(ry)}" fill="#1A2A5A" opacity="${a}"/>`;

module.exports = { uid, rng, f, rect, ellipse, path, poly, blob, blobPath, lin, rad, vgrad, gloss, sparkle, sparkles, starburst, rays, arrow, banner, pill, coin, bar, cloud, shadow, INK };

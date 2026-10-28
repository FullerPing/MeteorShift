// Meteor, pickaxe and the Craterworks Miner, drawn as glossy cartoon vectors.
const S = require('./shapes.cjs');
const { gloss, path, poly, rect, ellipse, vgrad, rad, f, INK, rng } = S;

// ---------------- meteor ----------------
// Plates of crust over a molten core; the glow shows in the gaps. Origin at the centre.
function meteor(R, { crust = ['#D99A6C', '#B07050', '#84482E'], core = ['#FFFBD0', '#FFC040', '#E8561A'], seed = 7, broken = false, coreColor, spokes = true } = {}) {
  const r = rng(seed);
  const id = S.uid('mt');
  const dmin = R * .31;
  const pts = [];
  for (let tries = 0; tries < 1200 && pts.length < 34; tries++) {
    const a = r(0, Math.PI * 2), d = Math.sqrt(r()) * R * .92;
    const x = Math.cos(a) * d, y = Math.sin(a) * d;
    if (broken && d < R * .55) continue;
    if (pts.every(p => Math.hypot(p[0] - x, p[1] - y) > dmin)) pts.push([x, y]);
  }
  pts.sort((a, b) => a[1] - b[1]);
  const baseFill = rad([[0, core[0]], [.45, core[1]], [1, core[2]]]);
  let out = `<defs>${baseFill.defs}<clipPath id="${id}"><circle r="${R}"/></clipPath></defs>`;
  out += `<circle r="${R}" fill="${INK}" stroke="${INK}" stroke-width="${f(R * .07)}"/><circle r="${R}" fill="${baseFill.ref}"/>`;
  if (broken) {
    const cc = coreColor || ['#F2FFF4', '#6EFFA0', '#1E9A58'];
    const cg = rad([[0, cc[0]], [.5, cc[1]], [1, cc[2]]]);
    out += `<defs>${cg.defs}</defs><circle r="${f(R * .66)}" fill="${INK}" stroke="${INK}" stroke-width="${f(R * .05)}"/><circle r="${f(R * .66)}" fill="${cg.ref}"/>`;
    for (let i = 0; i < 9; i++) {
      const a = i * Math.PI * 2 / 9 + r(0, .3);
      let d = `M0 0`;
      let x = 0, y = 0;
      for (let k = 1; k <= 5; k++) { const rr = R * .13 * k, aa = a + r(-.22, .22); x = Math.cos(aa) * rr; y = Math.sin(aa) * rr; d += `L${f(x)} ${f(y)}`; }
      out += `<path d="${d}" fill="none" stroke="#FFFFFF" stroke-width="${f(R * .03)}" stroke-linecap="round" stroke-linejoin="round" opacity=".85"/>`;
    }
  }
  out += `<g clip-path="url(#${id})">`;
  for (const [x, y] of pts) {
    const rr = dmin * r(.6, .9);
    const n = 5 + Math.floor(r(0, 3)), poly_ = [];
    const rot = r(0, 6);
    for (let i = 0; i < n; i++) { const a = rot + i * Math.PI * 2 / n; poly_.push([x + Math.cos(a) * rr * r(.7, 1.2), y + Math.sin(a) * rr * r(.7, 1.15)]); }
    const tone = [crust[0], crust[1], crust[2]][Math.floor(r(0, 3))];
    const d = 'M' + poly_.map(p => `${f(p[0])} ${f(p[1])}`).join('L') + 'Z';
    const g = vgrad(crust[0], tone);
    out += `<defs>${g.defs}</defs><path d="${d}" fill="${g.ref}" stroke="${INK}" stroke-width="${f(R * .026)}" stroke-linejoin="round"/>`;
    out += `<path d="M${poly_.slice(0, 4).map(p => `${f(x + (p[0] - x) * .62 - rr * .1)} ${f(y + (p[1] - y) * .5 - rr * .2)}`).join('L')}Z" fill="white" opacity=".15"/>`;
  }
  const shade = rad([[.55, '#000000', 0], [1, '#1A0A2A', .42]], { cx: .38, cy: .34, r: .85 });
  out += `<defs>${shade.defs}</defs><circle r="${R}" fill="${shade.ref}"/><ellipse cx="${f(-R * .34)}" cy="${f(-R * .46)}" rx="${f(R * .34)}" ry="${f(R * .16)}" fill="white" opacity=".22" transform="rotate(-28 ${f(-R * .34)} ${f(-R * .46)})"/></g>`;
  out += `<circle r="${R}" fill="none" stroke="${INK}" stroke-width="${f(R * .035)}"/>`;
  return out;
}

// ---------------- pickaxe ----------------
// Origin at the middle of the handle; the head points up. Length L.
const PICKS = {
  1: { head: ['#D2D8E4', '#8E98AE'], lip: '#4A5470', handle: ['#FFB24A', '#D8661A'], glow: null },
  4: { head: ['#9AF0FF', '#2CB8E8'], lip: '#106C98', handle: ['#FF9A3A', '#D8561A'], glow: '#7CF4FF' },
  6: { head: ['#D8A0FF', '#8C32E8'], lip: '#541696', handle: ['#7A5CC8', '#41288A'], glow: '#C48CFF' },
  8: { head: ['#FFA0E4', '#E83CB8'], lip: '#8C1070', handle: ['#4A3A8E', '#241A58'], glow: '#FF7AE0' },
};
function pickaxe(L, tier = 1, fat = 1) {
  const P = PICKS[tier] || PICKS[1];
  const hw = L * .42, hh = L * .12 * fat, top = -L / 2;
  const headD = `M${f(-hw)} ${f(top + hh * 1.7)}C${f(-hw * .62)} ${f(top - hh * .7)} ${f(hw * .62)} ${f(top - hh * .7)} ${f(hw)} ${f(top + hh * 1.7)}C${f(hw * .6)} ${f(top + hh * .3)} ${f(-hw * .6)} ${f(top + hh * .3)} ${f(-hw)} ${f(top + hh * 1.7)}Z`;
  const sw = Math.max(4, L * .028);
  let out = '';
  if (P.glow) out += `<path d="${headD}" fill="${P.glow}" stroke="${P.glow}" stroke-width="${f(L * .09)}" opacity=".5" stroke-linejoin="round"/>`;
  out += gloss(rect(-L * .035, top + hh * .6, L * .07, L * .98, L * .03), { top: P.handle[0], bottom: P.handle[1], lip: '#7A3410', sw, shine: .3 });
  for (const k of [.3, .38, .46]) out += `<rect x="${f(-L * .037)}" y="${f(L * k - L * .1)}" width="${f(L * .074)}" height="${f(L * .03)}" fill="#7A3410" stroke="${INK}" stroke-width="${f(sw * .6)}"/>`;
  out += gloss(rect(-L * .075, top + hh * .5, L * .15, L * .1, L * .03), { top: '#8E98AE', bottom: '#4A5470', lip: '#2A3350', sw, shine: .25, noLip: true });
  out += gloss(path(headD, [-hw, top - hh, hw * 2, hh * 2.7]), { top: P.head[0], bottom: P.head[1], lip: P.lip, sw, shine: .4, lipDy: sw * .9 });
  if (tier >= 4) out += `<path d="M${f(-hw * .78)} ${f(top + hh * 1.2)}C${f(-hw * .4)} ${f(top - hh * .1)} ${f(hw * .4)} ${f(top - hh * .1)} ${f(hw * .78)} ${f(top + hh * 1.2)}" fill="none" stroke="white" stroke-width="${f(L * .016)}" stroke-linecap="round" opacity=".85"/>`;
  if (tier >= 8) out += S.sparkle(0, top + hh * .1, L * .07, { fill: '#FFFFFF' });
  return out;
}

// ---------------- the Craterworks Miner ----------------
// Feet at y = 0, about 400 tall including the plume, facing the viewer. A box in 3/4 view: front, right side, top.
function box(x, y, w, h, d, { front, side, topc, rx = 8, sw = 6 }) {
  const dx = d * .62, dy = d * .38;
  const sideP = `M${x + w} ${y}L${x + w + dx} ${y - dy}L${x + w + dx} ${y + h - dy}L${x + w} ${y + h}Z`;
  const topP = `M${x} ${y}L${x + dx} ${y - dy}L${x + w + dx} ${y - dy}L${x + w} ${y}Z`;
  const g = vgrad(front[0], front[1]);
  return `<defs>${g.defs}</defs><g stroke="${INK}" stroke-width="${sw}" stroke-linejoin="round"><path d="${sideP}" fill="${side}"/><path d="${topP}" fill="${topc}"/><rect x="${f(x)}" y="${f(y)}" width="${f(w)}" height="${f(h)}" rx="${rx}" fill="${g.ref}"/></g>`;
}
const ARMOUR = {
  orange: { a: ['#FFC25A', '#F2801E'], side: '#BA4E1A', topc: '#FFD890', gem: '#2ED6C4' },
  blue: { a: ['#78C4FF', '#2E80F0'], side: '#1C4AA8', topc: '#B8E0FF', gem: '#FFF078' },
  violet: { a: ['#D890FF', '#8C32E8'], side: '#541696', topc: '#EBC6FF', gem: '#FFF078' },
  green: { a: ['#B2FF4A', '#32C41E'], side: '#166E12', topc: '#DCFF9A', gem: '#FFF078' },
  pink: { a: ['#FFA0E4', '#E83CB8'], side: '#8C1070', topc: '#FFD0F2', gem: '#FFF078' },
};
function miner({ pose = 'swing', armour = 'orange', tier = 4, pickTilt = 32, pickLen = 330 } = {}) {
  const A = ARMOUR[armour];
  const suit = { front: ['#3E4C86', '#232C5C'], side: '#161E40', topc: '#52609E' };
  const skin = { front: ['#FFD9AE', '#F0B27E'], side: '#D49A68', topc: '#FFE6C8' };
  const plate = { front: A.a, side: A.side, topc: A.topc };
  let o = '';
  // backpack, peeking out behind
  o += box(-86, -214, 56, 112, 36, { front: ['#E8C896', '#C29458'], side: '#8E6232', topc: '#F4DEB8', rx: 12 });
  // legs and boots
  for (const x of [-56, 8]) {
    o += box(x, -96, 48, 96, 40, { ...suit, rx: 10 });
    o += box(x - 2, -42, 52, 42, 44, { front: ['#2E3A6E', '#161E40'], side: '#0E1430', topc: '#46548C', rx: 12 });
    o += `<rect x="${x + 2}" y="-92" width="44" height="34" rx="10" fill="${A.a[1]}" stroke="${INK}" stroke-width="6"/>`;
  }
  // torso with belt and gem
  o += box(-66, -226, 132, 134, 58, { ...plate, rx: 16 });
  o += gloss(rect(-66, -118, 132, 24, 8), { top: '#FFF078', bottom: '#FFB21E', lip: '#B06806', sw: 6, shine: .3, noLip: true });
  o += `<circle cx="0" cy="-170" r="17" fill="${A.gem}" stroke="${INK}" stroke-width="6"/><circle cx="-5" cy="-175" r="5" fill="white" opacity=".9"/>`;
  // arms
  const arm = (side, angle) => {
    const px = side * 82, py = -202;
    const g = `<g transform="translate(${px} ${py}) rotate(${angle})">
      ${box(-20, 0, 40, 116, 30, { ...suit, rx: 12 })}
      ${box(-23, 54, 46, 56, 34, { ...plate, rx: 12 })}
      <circle cy="132" r="21" fill="${skin.front[0]}" stroke="${INK}" stroke-width="6"/>
      ${gloss(ellipse(0, 2, 36, 30), { top: A.a[0], bottom: A.a[1], lip: A.side, sw: 7, shine: .3 })}</g>`;
    return g;
  };
  const headY = -334;
  const head = () => {
    let h = box(-54, headY, 108, 104, 54, { ...skin, rx: 20 });
    h += `<circle cx="-22" cy="${headY + 62}" r="8" fill="${INK}"/><circle cx="22" cy="${headY + 62}" r="8" fill="${INK}"/>`;
    h += `<path d="M-18 ${headY + 82}Q0 ${headY + 98} 18 ${headY + 82}" fill="none" stroke="${INK}" stroke-width="6" stroke-linecap="round"/>`;
    h += `<circle cx="-40" cy="${headY + 76}" r="9" fill="#FF8A80" opacity=".5"/><circle cx="40" cy="${headY + 76}" r="9" fill="#FF8A80" opacity=".5"/>`;
    // helmet: dome, brim and visor band, plume
    h += gloss(path(`M-64 ${headY + 46}C-64 ${headY - 44} 64 ${headY - 44} 64 ${headY + 46}Q0 ${headY + 40} -64 ${headY + 46}Z`, [-64, headY - 20, 128, 66]), { top: A.a[0], bottom: A.a[1], lip: A.side, sw: 7, shine: .3 });
    h += gloss(rect(-66, headY + 28, 132, 22, 8), { top: '#7CF4E4', bottom: '#1EB8A8', lip: '#0E6E66', sw: 6, shine: .35, noLip: true });
    h += gloss(path(`M-10 ${headY - 18}C-4 ${headY - 70} 40 ${headY - 86} 78 ${headY - 52}C52 ${headY - 52} 38 ${headY - 34} 38 ${headY - 8}Z`, [-10, headY - 86, 90, 80]), { top: '#FF6876', bottom: '#B8142C', lip: '#6E0A1C', sw: 7, shine: .3 });
    return h;
  };
  const pickG = (tx, ty, rot) => `<g transform="translate(${tx} ${ty}) rotate(${rot}) translate(0 ${f(-pickLen * .1)})">${pickaxe(pickLen, tier)}</g>`;
  if (pose === 'swing') {
    o += arm(-1, -16);
    o += pickG(106, -330, pickTilt);
    o += arm(1, 192);
    o += head();
    o += `<circle cx="${106 + 3}" cy="-326" r="22" fill="${skin.front[0]}" stroke="${INK}" stroke-width="6"/>`;
  } else if (pose === 'cheer') {
    o += arm(-1, 14);
    o += arm(1, 166);
    o += head();
  } else {
    o += arm(-1, 8);
    o += arm(1, -8);
    o += head();
  }
  return o;
}

module.exports = { meteor, pickaxe, miner, ARMOUR };

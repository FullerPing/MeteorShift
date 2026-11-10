// Backdrop pieces shared by thumbnail 1 and the loading screen: sky, Meteor Peak, sky island, rampart, plaza and crater.
const fs = require('node:fs');
const S = require('./shapes.cjs');
const { gloss, path, ellipse, rect, poly, blob, vgrad, rad, lin, f, INK, rng } = S;

function embed(file, width) {
  const { sharp } = require('./type.cjs');
  return sharp(file).resize({ width }).png().toBuffer().then(async b => {
    const m = await sharp(b).metadata();
    return { href: 'data:image/png;base64,' + b.toString('base64'), w: m.width, h: m.height };
  });
}

function sky(W, H, hy) {
  const g = lin([[0, '#2E8CF6'], [.55, '#6CC0FF'], [1, '#C6EEFF']]);
  return `<defs>${g.defs}</defs><rect width="${W}" height="${hy + 6}" fill="${g.ref}"/>`;
}

// Meteor Peak: a violet-blue volcano with a glowing rim and a smoke plume. base y = by, centre x = cx.
function peak(cx, by, w, h) {
  const body = lin([[0, '#8A94E0'], [1, '#4C56A8']]);
  const d = `M${cx - w / 2} ${by}C${cx - w * .3} ${by - h * .2} ${cx - w * .16} ${by - h * .86} ${cx - w * .09} ${by - h}L${cx + w * .09} ${by - h}C${cx + w * .16} ${by - h * .86} ${cx + w * .3} ${by - h * .2} ${cx + w / 2} ${by}Z`;
  let o = `<defs>${body.defs}</defs>`;
  o += `<path d="${d}" fill="${body.ref}" stroke="${INK}" stroke-width="6" stroke-linejoin="round"/>`;
  o += `<path d="M${cx + w * .09} ${by - h}C${cx + w * .16} ${by - h * .86} ${cx + w * .3} ${by - h * .2} ${cx + w / 2} ${by}L${cx + w * .2} ${by}C${cx + w * .12} ${by - h * .4} ${cx + w * .1} ${by - h * .7} ${cx + w * .09} ${by - h}Z" fill="#3A4290" opacity=".55"/>`;
  // snow-free ridges
  o += `<path d="M${cx - w * .2} ${by - h * .3}L${cx - w * .1} ${by - h * .62}M${cx - w * .02} ${by - h * .1}L${cx - w * .04} ${by - h * .55}" stroke="#A8B2F0" stroke-width="7" stroke-linecap="round" opacity=".45"/>`;
  // rim and lava
  const rimY = by - h;
  o += gloss(ellipse(cx, rimY, w * .105, h * .045), { top: '#B8C0F4', bottom: '#7C86D4', lip: '#4C56A8', sw: 6, shine: 0 });
  o += `<ellipse cx="${cx}" cy="${rimY + 2}" rx="${w * .08}" ry="${h * .028}" fill="#FF9A1E" stroke="${INK}" stroke-width="4"/><ellipse cx="${cx}" cy="${rimY}" rx="${w * .05}" ry="${h * .016}" fill="#FFE070"/>`;
  // lava drips
  o += `<path d="M${cx - w * .06} ${rimY + h * .02}Q${cx - w * .07} ${rimY + h * .12} ${cx - w * .045} ${rimY + h * .2}M${cx + w * .05} ${rimY + h * .02}Q${cx + w * .07} ${rimY + h * .1} ${cx + w * .055} ${rimY + h * .17}" stroke="#FF9A1E" stroke-width="12" fill="none" stroke-linecap="round"/>`;
  // plume
  const puffs = [[0, -60, 56], [26, -150, 74], [-10, -250, 92], [46, -360, 110], [4, -480, 124]];
  o += puffs.map(([dx, dy, r]) => `<circle cx="${cx + dx}" cy="${rimY + dy}" r="${r}" fill="#EDE9FA" stroke="${INK}" stroke-width="5" opacity=".95"/>`).join('');
  o += puffs.map(([dx, dy, r]) => `<circle cx="${cx + dx - r * .2}" cy="${rimY + dy - r * .2}" r="${r * .62}" fill="#FFFFFF" opacity=".7"/>`).join('');
  return o;
}

function rangeHills(W, by, color, seed, count = 9, hmin = 90, hmax = 220, ink = true) {
  const r = rng(seed);
  let o = '';
  for (let i = 0; i < count; i++) {
    const cx = (i + .5) * W / count + r(-60, 60), w = r(300, 520), h = r(hmin, hmax);
    o += `<ellipse cx="${f(cx)}" cy="${by}" rx="${f(w / 2)}" ry="${f(h)}" fill="${color}"${ink ? ` stroke="${INK}" stroke-width="5"` : ''}/>`;
  }
  return o;
}

function skyIsland(cx, cy, s) {
  let o = `<g transform="translate(${cx} ${cy}) scale(${s})">`;
  o += gloss(path('M-120 6C-100 100 -40 150 0 190C40 150 100 100 120 6Z', [-120, 6, 240, 184]), { top: '#C98A5A', bottom: '#8A5230', lip: '#5A3018', sw: 6, shine: .15 });
  o += `<rect x="-6" y="120" width="12" height="90" rx="6" fill="#5FD8FF" opacity=".75"/>`;
  o += gloss(ellipse(0, 0, 130, 30), { top: '#8CF05A', bottom: '#32B83A', lip: '#1A6E22', sw: 6, shine: .3 });
  o += `<rect x="-60" y="-52" width="14" height="46" rx="5" fill="#8A5230" stroke="${INK}" stroke-width="5"/><circle cx="-53" cy="-70" r="34" fill="#46D04A" stroke="${INK}" stroke-width="6"/><circle cx="-62" cy="-80" r="12" fill="#B2FF7A" opacity=".6"/>`;
  o += `<path d="M44 -8L60 -62L76 -8Z" fill="#B874FF" stroke="${INK}" stroke-width="5" stroke-linejoin="round"/><path d="M70 -6L88 -38L100 -4Z" fill="#6ED4FF" stroke="${INK}" stroke-width="5" stroke-linejoin="round"/>`;
  return o + '</g>';
}

// A cream rampart band with navy base and rounded merlons, with a tree line peeking over it.
function rampart(W, y, hgt, seed = 4) {
  const r = rng(seed);
  let o = '';
  // trees behind
  for (let x = 40; x < W; x += r(70, 120)) {
    const th = r(60, 120);
    o += `<circle cx="${f(x)}" cy="${f(y - th * .55)}" r="${f(th * .5)}" fill="${r() > .5 ? '#46C846' : '#32B03C'}" stroke="${INK}" stroke-width="5"/>`;
  }
  const wall = lin([[0, '#FFF6E2'], [1, '#E6D8B8']]);
  o += `<defs>${wall.defs}</defs>`;
  for (let x = 0; x < W; x += 72) o += `<rect x="${x + 8}" y="${y - 30}" width="52" height="44" rx="14" fill="${wall.ref}" stroke="${INK}" stroke-width="5"/>`;
  o += `<rect x="-10" y="${y}" width="${W + 20}" height="${hgt}" fill="${wall.ref}" stroke="${INK}" stroke-width="6"/>`;
  o += `<rect x="-10" y="${y + hgt * .62}" width="${W + 20}" height="${hgt * .38}" fill="#3A4A88" stroke="${INK}" stroke-width="6"/>`;
  o += `<rect x="-10" y="${y + 6}" width="${W + 20}" height="9" fill="white" opacity=".6"/>`;
  return o;
}

// Plaza floor with the yellow ring and the crater bowl. (cx, cy) is the crater centre.
function crater(cx, cy, rx, ry) {
  let o = `<ellipse cx="${cx}" cy="${cy + ry * .12}" rx="${rx * 1.24}" ry="${ry * 1.34}" fill="#1A2A5A" opacity=".25"/>`;
  o += gloss(ellipse(cx, cy, rx * 1.18, ry * 1.2), { top: '#FFE45A', bottom: '#F2A010', lip: '#B06806', sw: 7, shine: .25 });
  o += `<ellipse cx="${cx}" cy="${cy + ry * .04}" rx="${rx * 1.02}" ry="${ry * 1.02}" fill="${INK}"/>`;
  const bowl = rad([[0, '#5A6C9E'], [.7, '#3E4E84'], [1, '#2A3768']], { cx: .5, cy: .38, r: .7 });
  o += `<defs>${bowl.defs}</defs><ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${bowl.ref}"/>`;
  return o;
}

function plaza(W, y0, H) {
  const g = lin([[0, '#F4ECD8'], [1, '#E2D6BA']]);
  let o = `<defs>${g.defs}</defs><rect x="0" y="${y0}" width="${W}" height="${H - y0}" fill="${g.ref}"/>`;
  return o;
}

module.exports = { embed, sky, peak, rangeHills, skyIsland, rampart, crater, plaza };

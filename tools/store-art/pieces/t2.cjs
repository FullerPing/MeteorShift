// Thumbnail 2: PICKAXE POWER. Three panels, x1 / x5 / x20 ore per hit.
// Config.Pickaxes[1,4,8].OrePerHit = 1, 5, 20 (flat per tier; the Gear Hall tooltip says "ore per hit").
const path = require('node:path');
const S = require('../lib/shapes.cjs');
const Hh = require('../lib/hero.cjs');
const { letters } = require('../lib/type.cjs');
const { render } = require('../lib/raster.cjs');
const W = 1920, H = 1080;
const OUT = path.resolve(__dirname, '../../../assets/marketing/v2/thumb-2-pickaxe-power.png');

module.exports = async function build() {
  const r = S.rng(21);
  const lean = 56; // 6 degrees over the frame height
  const edge = [0, 640, 1280, 1920];
  const panels = [
    { top: '#6CC8FF', bottom: '#1E68E8', ray: '#FFFFFF', tier: 1, num: 'x1', cx: 330, cy: 650, len: 520, rot: -34, numTop: '#FFFFFF', numBot: '#D8F0FF', lip: '#103A96' },
    { top: '#FFD250', bottom: '#FF7A14', ray: '#FFF6C0', tier: 4, num: 'x5', cx: 975, cy: 660, len: 680, rot: -34, numTop: '#FFFFFF', numBot: '#FFF2B0', lip: '#AA4608' },
    { top: '#E6A0FF', bottom: '#7A24D8', ray: '#FFE0FF', tier: 8, num: 'x20', cx: 1610, cy: 650, len: 820, rot: -34, numTop: '#FFFFFF', numBot: '#FFD6F4', lip: '#541696' },
  ];
  let body = '', fx = '';
  panels.forEach((p, i) => {
    const x0 = edge[i], x1 = edge[i + 1];
    const pts = `${i === 0 ? 0 : x0 + lean},0 ${i === 2 ? W : x1 + lean},0 ${i === 2 ? W : x1 - lean},${H} ${i === 0 ? 0 : x0 - lean},${H}`;
    const g = S.vgrad(p.top, p.bottom), id = S.uid('pn');
    const cx = (x0 + x1) / 2;
    body += `<defs>${g.defs}<clipPath id="${id}"><polygon points="${pts}"/></clipPath></defs><g clip-path="url(#${id})"><rect width="${W}" height="${H}" fill="${g.ref}"/>`;
    body += S.rays(cx, p.cy, i === 0 ? 10 : 16, 1500, { color: p.ray, alpha: i === 0 ? .1 : .2, rot: i * .3, spread: .5 });
    for (let k = 0; k < 7; k++) body += `<circle cx="${S.f(r(x0, x1))}" cy="${S.f(r(60, H))}" r="${S.f(r(14, 54))}" fill="#FFFFFF" opacity="${S.f(r(.06, .15))}"/>`;
    body += `<ellipse cx="${cx}" cy="${p.cy + p.len * .36}" rx="${p.len * .36}" ry="40" fill="#0E1834" opacity=".25"/>`;
    body += `</g>`;
    if (i > 0) fx += `<g transform="translate(${p.cx} ${p.cy}) rotate(${p.rot})"><ellipse cy="${-p.len * .36}" rx="${p.len * .46}" ry="${p.len * .2}" fill="${i === 1 ? '#7CF4FF' : '#FF7AE0'}" opacity=".55"/></g>`;
    body += `<g transform="translate(${p.cx} ${p.cy}) rotate(${p.rot})">${Hh.pickaxe(p.len, p.tier)}</g>`;
    const t = letters(p.num, 215, { faceTop: p.numTop, faceBottom: p.numBot, lipColor: p.lip });
    body += `<g transform="translate(${S.f(cx - t.width / 2)} 268) rotate(${i === 1 ? 0 : i === 0 ? -3 : 3})">${t.body}</g>`;
  });
  [640, 1280].forEach(x => { body += `<line x1="${x + lean}" y1="-10" x2="${x - lean}" y2="${H + 10}" stroke="${S.INK}" stroke-width="34"/><line x1="${x + lean}" y1="-10" x2="${x - lean}" y2="${H + 10}" stroke="#FFFFFF" stroke-width="14"/>`; });
  const up = (x, y, len) => S.arrow(x, y, len, { angle: -90, thick: .9, face: ['#B2FF4A', '#32C41E'], lip: '#166E12' });
  body += up(742, 890, 150) + up(1396, 890, 190);
  body += `<g transform="translate(610 944)">${S.banner('ORE PER HIT', 640, 98, { top: '#56BAFF', bottom: '#1E68E8', lip: '#103A96' })}</g>`;
  const sparks = [];
  for (let i = 0; i < 28; i++) sparks.push([r(1330, 1890), r(40, 900), r(10, 34), { fill: r() > .5 ? '#FFFFFF' : '#FFC8F2', ink: r() > .5, rot: r(0, 30) }]);
  for (let i = 0; i < 12; i++) sparks.push([r(700, 1240), r(300, 880), r(8, 26), { fill: '#FFFFFF', ink: r() > .5, rot: r(0, 30) }]);
  body += S.sparkles(sparks);
  fx += `<ellipse cx="1610" cy="360" rx="420" ry="300" fill="#FF7AE0" opacity=".4"/>${S.sparkles(sparks.slice(0, 16).map(s => [s[0], s[1], s[2] * 1.2, { fill: '#FFFFFF', ink: false }]))}`;
  await render(OUT, W, H, body, { fxBody: fx });
};

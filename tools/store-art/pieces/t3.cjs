// Thumbnail 3: HATCH A LEGENDARY. Meteor Egg, red arrow, the Meteor Drake, "1 IN 200".
// 200 = 100 / Config.Pets.Eggs[meteorEgg].Odds.legendary (0.5); the Drake is the only non-premium legendary.
const path = require('node:path');
const S = require('../lib/shapes.cjs');
const A = require('../lib/art.cjs');
const { letters, simpleText } = require('../lib/type.cjs');
const { render } = require('../lib/raster.cjs');
const W = 1920, H = 1080;
const OUT = path.resolve(__dirname, '../../../assets/marketing/v2/thumb-3-hatch-legendary.png');

module.exports = async function build() {
  const r = S.rng(33);
  const bg = S.rad([[0, '#FFFBD2'], [.28, '#FFE070'], [.62, '#FFA21E'], [1, '#F2640E']], { cx: .69, cy: .5, r: .78 });
  let back = `<defs>${bg.defs}</defs><rect width="${W}" height="${H}" fill="${bg.ref}"/>`;
  back += S.rays(1330, 540, 20, 1700, { color: '#FFFFFF', alpha: .26, rot: .1, spread: .5 });
  for (let i = 0; i < 16; i++) back += `<circle cx="${S.f(r(0, W))}" cy="${S.f(r(0, H))}" r="${S.f(r(18, 70))}" fill="#FFFFFF" opacity="${S.f(r(.06, .16))}"/>`;
  // ground glow under the egg
  back += `<ellipse cx="400" cy="900" rx="330" ry="50" fill="#B04A10" opacity=".22"/>`;

  // the Drake, facing left toward the egg
  const drake = A.drake();
  const dk = { x: 1030, y: 250, s: 1.06 };
  const drakeG = `<g transform="translate(${dk.x} ${dk.y}) scale(${dk.s})">${drake.halo.replace(/fill="#FFFFFF"/g, 'fill="#FFF6C0"').replace(/stroke="#FFFFFF"/g, 'stroke="#FFF6C0"')}${drake.body}</g>`;
  const ring = `<ellipse cx="1450" cy="640" rx="470" ry="440" fill="none" stroke="#FFFFFF" stroke-width="22" opacity=".55"/><ellipse cx="1450" cy="640" rx="430" ry="400" fill="none" stroke="#FFBE3C" stroke-width="12" opacity=".8"/>`;
  const dropShadow = S.shadow(1430, 1000, 400, 36, .28);

  // the egg on its pedestal
  const eggG = `<g transform="translate(385 842)">${A.pedestal(430)}</g><g transform="translate(385 548) rotate(-5)">${A.egg(440, 570)}</g>`;
  const eggGlow = `<g transform="translate(385 548) rotate(-5)"><path d="M-22 -195L12 -125L-18 -73L30 -12L-8 37L36 94" fill="none" stroke="#FFFFFF" stroke-width="30" stroke-linecap="round" stroke-linejoin="round"/></g>`;

  const arrow = S.arrow(690, 560, 270, { angle: 6, thick: 1.15 });

  // text: "1 IN 200" fitted to the top-right box, "200" in gold
  let T = 150;
  let one = letters('1 IN ', T, { faceTop: '#FFFFFF', faceBottom: '#D8F0FF', lipColor: '#789CD2', personality: true });
  let two = letters('200', T, { faceTop: '#FFF078', faceBottom: '#FFB21E', lipColor: '#AA4608', personality: true });
  const total = one.width + two.width;
  const fit = Math.min(1, 860 / total);
  const num = `<g transform="translate(${S.f(1450 - total * fit / 2)} ${S.f(92 + T * fit * 1.02)}) rotate(-3) scale(${S.f(fit)})">${one.body}<g transform="translate(${S.f(one.width)} 0)">${two.body}</g></g>`;

  const ribbon = `<g transform="translate(880 880)">${S.banner('LEGENDARY!', 470, 100, { tilt: -6 })}</g>`;
  const eggIcon = '';
  const pillSvg = `<g transform="translate(77 950)">${S.pill('HATCH!', 400, 86)}</g>`;
  const sparkles = [];
  for (let i = 0; i < 30; i++) {
    const a = r(0, Math.PI * 2), d = r(.92, 1.28);
    const x = 1450 + Math.cos(a) * 470 * d, y = 640 + Math.sin(a) * 440 * d;
    if (x > 940 && x < 1900 && y > 250 && y < 1030) sparkles.push([x, y, r(12, 36), { fill: r() > .5 ? '#FFFFFF' : '#FFF078', ink: r() > .45, rot: r(0, 30) }]);
  }
  const confetti = Array.from({ length: 14 }, () => {
    let x = r(60, 900), y = r(90, 940); if (Math.hypot((x - 385) / 260, (y - 548) / 330) < 1) { x = r(640, 900); y = r(120, 380); } const col = ['#FF6876', '#56BAFF', '#B2FF4A', '#D480FF', '#FFFFFF'][Math.floor(r(0, 5))];
    return `<rect x="${S.f(x)}" y="${S.f(y)}" width="${S.f(r(14, 26))}" height="${S.f(r(8, 14))}" rx="3" fill="${col}" stroke="${S.INK}" stroke-width="3" transform="rotate(${S.f(r(0, 180))} ${S.f(x)} ${S.f(y)})"/>`;
  }).join('');

  const body = `${back}${ring}${dropShadow}${drakeG}${eggG}${confetti}${arrow}${ribbon}${pillSvg}${eggIcon}${num}${S.sparkles(sparkles)}`;
  const fx = `<ellipse cx="1450" cy="600" rx="560" ry="520" fill="#FFFFFF" opacity=".35"/><ellipse cx="1450" cy="640" rx="470" ry="440" fill="none" stroke="#FFF078" stroke-width="26" opacity=".8"/>${eggGlow}<ellipse cx="385" cy="560" rx="240" ry="260" fill="#FFF078" opacity=".25"/>${S.sparkles(sparkles.slice(0, 18).map(s => [s[0], s[1], s[2] * 1.2, { fill: '#FFFFFF', ink: false }]))}`;
  await render(OUT, W, H, body, { fxBody: fx, bloom: 1 });
};

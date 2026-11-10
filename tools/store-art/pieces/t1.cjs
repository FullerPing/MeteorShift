// Thumbnail 1: METEOR IMPACT. A giant Iron meteor in the crater, the Craterworks Miner mid-swing, the logo.
// "+5" is the real ore for a Plasma Pick hit (Config.Pickaxes[4].OrePerHit = 5), not a damage figure.
const path = require('node:path');
const S = require('../lib/shapes.cjs');
const A = require('../lib/art.cjs');
const Hh = require('../lib/hero.cjs');
const Sc = require('../lib/scene.cjs');
const { letters } = require('../lib/type.cjs');
const { render } = require('../lib/raster.cjs');
const W = 1920, H = 1080;
const root = path.resolve(__dirname, '../../..');
const OUT = path.join(root, 'assets/marketing/v2/thumb-1-meteor-impact.png');

const plus = (txt, x, y, h, rot) => {
  const t = letters(txt, h, { faceTop: '#FFF078', faceBottom: '#FFB21E', lipColor: '#AA4608' });
  return `<g transform="translate(${x} ${y}) rotate(${rot})">${t.body}</g>`;
};

module.exports = async function build() {
  const r = S.rng(11);
  const logo = await Sc.embed(path.join(root, 'assets/marketing/v2/wordmark.png'), 960);
  const hy = 640;
  let b = Sc.sky(W, H, hy);
  // light fan and clouds
  b += S.rays(1380, 640, 14, 1900, { color: '#FFFFFF', alpha: .13, rot: .2, spread: .5 });
  b += Sc.skyIsland(1230, 150, .62);
  b += S.cloud(1560, 150, 78) + S.cloud(260, 360, 58) + S.cloud(850, 420, 46, { alpha: .9 }) + S.cloud(1780, 380, 50);
  b += Sc.rangeHills(W, hy + 30, '#59B8C8', 5, 8, 100, 190);
  b += Sc.peak(1560, hy + 40, 900, 560);
  b += Sc.rangeHills(W, hy + 50, '#3FB3A0', 9, 10, 70, 140);
  b += Sc.rampart(W, hy + 20, 82);
  b += Sc.plaza(W, hy + 102, H);
  b += `<rect x="0" y="${hy + 102}" width="${W}" height="16" fill="#CDBF9E" opacity=".5"/>`;
  b += Sc.crater(1380, 905, 560, 112);
  // shockwave dust + glow on the ground
  b += `<ellipse cx="1380" cy="940" rx="700" ry="110" fill="#FF9A1E" opacity=".28"/><ellipse cx="1380" cy="960" rx="640" ry="70" fill="none" stroke="#FFFFFF" stroke-width="16" opacity=".55"/>`;

  // the meteor
  const meteor = `<g transform="translate(1390 600)">${Hh.meteor(385, { seed: 7 })}</g>`;
  // friend + hero
  const friend = `<g transform="translate(835 1000) scale(.82)">${Hh.miner({ pose: 'cheer', armour: 'blue' })}</g>`;
  const hero = `<g transform="translate(360 1030) scale(1.78)">${Hh.miner({ pose: 'swing', armour: 'orange', tier: 4, pickTilt: 52, pickLen: 330 })}</g>`;
  const drake = A.drake();
  const flyer = `<g transform="translate(640 500) scale(.34)">${drake.halo}${drake.body}</g>`;
  b += S.shadow(360, 1038, 250, 30, .3) + S.shadow(835, 1010, 130, 18, .3);

  // impact spark where the pick meets the rock
  const hit = [1020, 330];
  const burst = S.starburst(hit[0], hit[1], 92, { points: 9, inner: .48, top: '#FFFFFF', bottom: '#FFD250' });
  const nums = plus('+5', 905, 392, 70, 10) + plus('+5', 1120, 232, 54, -10);
  const chips = Array.from({ length: 14 }, (_, i) => {
    const a = r(0, Math.PI * 2), d = r(90, 300);
    const x = hit[0] + Math.cos(a) * d, y = hit[1] + Math.sin(a) * d * .8, s = r(10, 24);
    return `<polygon points="${S.f(x)},${S.f(y - s)} ${S.f(x + s)},${S.f(y)} ${S.f(x)},${S.f(y + s * .9)} ${S.f(x - s * .9)},${S.f(y)}" fill="${['#D99A6C', '#B07050', '#FFC040'][i % 3]}" stroke="${S.INK}" stroke-width="4" stroke-linejoin="round"/>`;
  }).join('');
  const coins = S.coin(930, 560, 34, -14) + S.coin(1180, 330, 28, 12);
  const sparks = [];
  for (let i = 0; i < 26; i++) sparks.push([r(40, 1880), r(40, 900), r(8, 30), { fill: r() > .5 ? '#FFFFFF' : '#FFF078', ink: r() > .5, rot: r(0, 30) }]);
  const logoImg = `<g transform="translate(70 40) rotate(0)"><image href="${logo.href}" width="${logo.w}" height="${logo.h}"/></g>`;

  const body = `${b}${meteor}${friend}${flyer}${hero}${burst}${chips}${coins}${nums}${S.sparkles(sparks)}${logoImg}`;
  const fx = `<circle cx="1390" cy="610" r="470" fill="#FF9A1E" opacity=".38"/><circle cx="${hit[0]}" cy="${hit[1]}" r="150" fill="#FFF078" opacity=".7"/><circle cx="1390" cy="600" r="250" fill="#FFE070" opacity=".35"/>${S.sparkles(sparks.slice(0, 14).map(s => [s[0], s[1], s[2] * 1.2, { fill: '#FFFFFF', ink: false }]))}`;
  await render(OUT, W, H, body, { fxBody: fx });
};

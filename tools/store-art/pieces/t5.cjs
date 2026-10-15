// Thumbnail 5: BOSS METEOR. The Alien boss meteor, cracked open, with four miners.
// Config.Meteor.Boss = { Type = "Alien", EveryMeteors = 10, MinRebirths = 3 }; Alien colours from Config.Meteor.Types.Alien.
const path = require('node:path');
const S = require('../lib/shapes.cjs');
const Hh = require('../lib/hero.cjs');
const { letters } = require('../lib/type.cjs');
const { render } = require('../lib/raster.cjs');
const W = 1920, H = 1080;
const OUT = path.resolve(__dirname, '../../../assets/marketing/v2/thumb-5-boss-meteor.png');

function shard(x, y, s, rot) {
  const d = `M0 ${-s}L${s * .5} ${-s * .2}L${s * .36} ${s * .8}L0 ${s}L${-s * .36} ${s * .8}L${-s * .5} ${-s * .2}Z`;
  return `<g transform="translate(${S.f(x)} ${S.f(y)}) rotate(${rot})">${S.gloss(S.path(d, [-s * .5, -s, s, s * 2]), { top: '#C8F0FF', bottom: '#2E8CF0', lip: '#1648BE', sw: Math.max(3, s * .13), shine: .4, noLip: true })}</g>`;
}

module.exports = async function build() {
  const r = S.rng(55);
  const bg = S.rad([[0, '#F4FFB8'], [.3, '#B0FF5C'], [.65, '#32C41E'], [1, '#0E5A60']], { cx: .5, cy: .52, r: .75 });
  let body = `<defs>${bg.defs}</defs><rect width="${W}" height="${H}" fill="${bg.ref}"/>`;
  body += S.rays(960, 560, 18, 1800, { color: '#FFFFFF', alpha: .2, rot: .15, spread: .5 });
  for (let i = 0; i < 14; i++) body += `<circle cx="${S.f(r(0, W))}" cy="${S.f(r(0, H))}" r="${S.f(r(20, 80))}" fill="#FFFFFF" opacity="${S.f(r(.05, .14))}"/>`;
  const floor = S.vgrad('#1B8A7A', '#0A4A58');
  body += `<defs>${floor.defs}</defs><ellipse cx="960" cy="1010" rx="1250" ry="210" fill="${floor.ref}" stroke="${S.INK}" stroke-width="7"/>`;
  body += `<ellipse cx="1000" cy="975" rx="640" ry="70" fill="#6EFFA0" opacity=".35"/>`;
  body += `<rect x="900" y="0" width="200" height="700" fill="#E8FFF0" opacity=".28"/>`;

  const alien = { crust: ['#7CE0AC', '#3EB07E', '#26805A'], core: ['#CFFFD8', '#6EFFA0', '#1E9A58'], broken: true, seed: 5 };
  const back = [[640, 1010, .95, 'violet', 6, 0], [1345, 1010, .95, 'green', 8, 1]];
  const meteor = `<g transform="translate(1000 590)"><circle r="450" fill="#6EFFA0" opacity=".22"/>${Hh.meteor(385, alien)}</g>`;
  const minersBack = back.map(([x, y, sc, ar, tier, flip]) => `<g transform="translate(${x} ${y}) scale(${flip ? -sc : sc} ${sc})">${Hh.miner({ pose: 'cheer', armour: ar })}</g>`).join('');
  const minerL = `<g transform="translate(290 1040) scale(1.72)">${Hh.miner({ pose: 'swing', armour: 'orange', tier: 4, pickTilt: 60, pickLen: 280 })}</g>`;
  const minerR = `<g transform="translate(1650 1040) scale(-1.72 1.72)">${Hh.miner({ pose: 'swing', armour: 'blue', tier: 6, pickTilt: 60, pickLen: 280 })}</g>`;
  const shadows = S.shadow(290, 1044, 230, 28, .3) + S.shadow(1650, 1044, 230, 28, .3);

  let shards = '';
  for (let i = 0; i < 11; i++) {
    const a = -Math.PI * (.08 + i * .084), d = r(380, 560);
    shards += shard(1000 + Math.cos(a) * d * 1.05, 560 + Math.sin(a) * d * .8, r(24, 52), r(-40, 40));
  }
  const ring = `<ellipse cx="1000" cy="590" rx="560" ry="520" fill="none" stroke="#9AF4FF" stroke-width="22" opacity=".55"/>`;
  const chips = Array.from({ length: 12 }, (_, i) => {
    const a = r(0, Math.PI * 2), d = r(420, 640), x = 1000 + Math.cos(a) * d, y = 590 + Math.sin(a) * d * .7, s = r(10, 22);
    return `<polygon points="${S.f(x)},${S.f(y - s)} ${S.f(x + s)},${S.f(y)} ${S.f(x)},${S.f(y + s * .9)} ${S.f(x - s * .9)},${S.f(y)}" fill="${['#7CE0AC', '#3EB07E', '#FFFFFF'][i % 3]}" stroke="${S.INK}" stroke-width="4" stroke-linejoin="round"/>`;
  }).join('');
  const sparks = [];
  for (let i = 0; i < 30; i++) sparks.push([r(60, 1860), r(260, 960), r(8, 30), { fill: r() > .5 ? '#FFFFFF' : '#E8FFB0', ink: r() > .5, rot: r(0, 30) }]);
  const crit = (txt, x, y, h, rot) => `<g transform="translate(${x} ${y}) rotate(${rot})">${letters(txt, h, { faceTop: '#FFF078', faceBottom: '#FFB21E', lipColor: '#AA4608' }).body}</g>`;

  const T = 190;
  const t = letters('BOSS METEOR!', T, { faceTop: '#FFFFFF', faceBottom: '#B0FF5C', lipColor: '#166E12' });
  const fit = Math.min(1, 1500 / t.width);
  const title = `<g transform="translate(${S.f(960 - t.width * fit / 2)} ${S.f(70 + T * fit * 1.02)}) rotate(-2) scale(${S.f(fit)})">${t.body}</g>`;

  const all = `${body}${ring}${meteor}${shards}${chips}${minersBack}${shadows}${minerL}${minerR}${crit('CRIT!', 1190, 330, 62, 8)}${crit('CRIT!', 700, 420, 52, -10)}${S.sparkles(sparks)}${title}`;
  const fx = `<circle cx="1000" cy="590" r="260" fill="#C8FFD8" opacity=".35"/><circle cx="1000" cy="590" r="520" fill="#6EFFA0" opacity=".14"/>${S.sparkles(sparks.slice(0, 16).map(s => [s[0], s[1], s[2] * 1.2, { fill: '#FFFFFF', ink: false }]))}`;
  await render(OUT, W, H, all, { fxBody: fx });
};

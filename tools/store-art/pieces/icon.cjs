// Icon: a molten Iron meteor, a Plasma Pick biting into it, an impact burst and a fiery tail. No text, no baked corners.
const path = require('node:path');
const S = require('../lib/shapes.cjs');
const Hh = require('../lib/hero.cjs');
const { render, sharp } = require('../lib/raster.cjs');
const root = path.resolve(__dirname, '../../..');

module.exports = async function build() {
  const W = 1024, H = 1024;
  const r = S.rng(9);
  const bg = S.rad([[0, '#8AD4FF'], [.55, '#3E9BFF'], [1, '#1E5FE0']], { cx: .5, cy: .45, r: .75 });
  let body = `<defs>${bg.defs}</defs><rect width="${W}" height="${H}" fill="${bg.ref}"/>`;
  body += S.rays(480, 520, 14, 1500, { color: '#FFFFFF', alpha: .15, rot: .2, spread: .5 });
  body += S.cloud(110, 905, 105) + S.cloud(925, 925, 112);
  // fiery tail from the top right
  const tail = S.lin([[0, '#FFF078', 1], [.5, '#FF9A1E', .9], [1, '#FF6A10', 0]], { x1: 1, y1: 0, x2: 0, y2: 1 });
  body += `<defs>${tail.defs}</defs><path d="M1010 40L560 250L700 470L1040 190Z" fill="${tail.ref}" opacity=".95"/><path d="M1000 120L620 290L720 400L1000 230Z" fill="#FFF8D0" opacity=".7"/>`;
  for (let i = 0; i < 9; i++) body += `<circle cx="${S.f(r(760, 1000))}" cy="${S.f(r(80, 300))}" r="${S.f(r(6, 16))}" fill="#FFD250" stroke="${S.INK}" stroke-width="3"/>`;
  body += S.shadow(470, 930, 330, 36, .3);
  body += `<g transform="translate(470 590)">${Hh.meteor(345, { seed: 7 })}</g>`;
  const hit = [668, 318];
  body += `<g transform="translate(440 575) rotate(40)">${Hh.pickaxe(640, 4, 1.8)}</g>`;
  body += S.starburst(hit[0], hit[1], 96, { points: 8, inner: .48, top: '#FFFFFF', bottom: '#FFD250', sw: 9 });
  for (let i = 0; i < 7; i++) {
    const a = -Math.PI * r(.05, .7), d = r(150, 260);
    const x = hit[0] + Math.cos(a) * d, y = hit[1] + Math.sin(a) * d, s = r(10, 20);
    body += `<polygon points="${S.f(x)},${S.f(y - s)} ${S.f(x + s)},${S.f(y)} ${S.f(x)},${S.f(y + s * .9)} ${S.f(x - s * .9)},${S.f(y)}" fill="${['#D99A6C', '#FFC040'][i % 2]}" stroke="${S.INK}" stroke-width="4" stroke-linejoin="round"/>`;
  }
  body += S.sparkles([[170, 190, 40, { fill: '#FFFFFF' }], [880, 640, 34, { fill: '#FFF078' }], [140, 560, 26, { fill: '#FFFFFF', ink: false }], [820, 860, 28, { fill: '#FFFFFF' }]]);
  const fx = `<circle cx="470" cy="590" r="420" fill="#FF9A1E" opacity=".3"/><circle cx="${hit[0]}" cy="${hit[1]}" r="170" fill="#FFF078" opacity=".7"/>`;
  const master = path.join(root, 'assets/marketing/v2/icon-1024-master.png');
  await render(master, W, H, body, { fxBody: fx, vignette: 0 });
  await sharp(master).resize(512, 512, { kernel: 'lanczos3' }).png({ compressionLevel: 9 }).toFile(path.join(root, 'assets/marketing/v2/icon-512.png'));
};

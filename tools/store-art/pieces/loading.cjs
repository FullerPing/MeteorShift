// Loading backdrop: Crater Isle seen across the plaza. No text. The crater sits at (38%, 62%) where the animated meteor lands,
// and the bottom 38% stays quiet because the progress panel sits there.
const path = require('node:path');
const S = require('../lib/shapes.cjs');
const Sc = require('../lib/scene.cjs');
const { render } = require('../lib/raster.cjs');
const root = path.resolve(__dirname, '../../..');

module.exports = async function build() {
  const W = 2048, H = 1152;
  const hy = 520;
  let b = Sc.sky(W, H, hy);
  b += S.rays(780, 700, 16, 2400, { color: '#FFFFFF', alpha: .11, rot: .3, spread: .5 });
  b += Sc.skyIsland(300, 190, .8) + Sc.skyIsland(1100, 130, .55);
  b += S.cloud(1000, 300, 70) + S.cloud(160, 430, 54) + S.cloud(1880, 250, 64) + S.cloud(560, 160, 44, { alpha: .9 });
  b += Sc.rangeHills(W, hy + 20, '#59B8C8', 8, 9, 100, 200);
  b += Sc.peak(1640, hy + 30, 900, 400);
  b += Sc.rangeHills(W, hy + 44, '#3FB3A0', 12, 11, 70, 150);
  b += Sc.rampart(W, hy + 14, 90);
  b += Sc.plaza(W, hy + 104, H);
  b += `<rect x="0" y="${hy + 104}" width="${W}" height="14" fill="#CDBF9E" opacity=".5"/>`;
  b += Sc.crater(Math.round(W * .38), Math.round(H * .62), 320, 70);
  // darken the lower part so the white UI text reads
  const fade = S.lin([[0, '#1E3A8A', 0], [1, '#1E3A8A', .5]]);
  b += `<defs>${fade.defs}</defs><rect x="0" y="${Math.round(H * .62)}" width="${W}" height="${H - Math.round(H * .62)}" fill="${fade.ref}"/>`;
  await render(path.join(root, 'assets/marketing/v2/loading/loading-bg.png'), W, H, b, { vignette: .14 });
};

const path = require('node:path');
const S = require('../lib/shapes.cjs'); const Hh = require('../lib/hero.cjs'); const { render } = require('../lib/raster.cjs');
module.exports = async function () {
  const sky = S.vgrad('#3E9BFF', '#BFEBFF');
  let b = `<defs>${sky.defs}</defs><rect width="1920" height="1080" fill="${sky.ref}"/>`;
  b += `<g transform="translate(260 760) scale(1.5)">${Hh.miner({ pose: 'swing', armour: 'orange', tier: 4 })}</g>`;
  b += `<g transform="translate(720 760) scale(1)">${Hh.miner({ pose: 'cheer', armour: 'blue' })}</g>`;
  b += `<g transform="translate(1000 760) scale(1)">${Hh.miner({ pose: 'idle', armour: 'violet' })}</g>`;
  b += `<g transform="translate(1500 330)">${Hh.meteor(260, { seed: 7 })}</g>`;
  b += `<g transform="translate(1500 800)">${Hh.meteor(200, { seed: 3, broken: true, crust: ['#7CE0AC', '#3EB07E', '#26805A'], core: ['#CFFFD8', '#6EFFA0', '#1E9A58'] })}</g>`;
  [1, 4, 6, 8].forEach((t, i) => { b += `<g transform="translate(${1000 + i * 120} 160) rotate(${-14 + i * 5})">${Hh.pickaxe(280, t)}</g>`; });
  await render(path.resolve(__dirname, '../out/proof.png'), 1920, 1080, b, { vignette: 0 });
};

// SVG to PNG: supersample 2x, add a bloom layer (blurred bright pieces, screen blended), a vignette, then downsample.
const fs = require('node:fs');
const path = require('node:path');
const { sharp, document } = require('./type.cjs');

const wrap = (w, h, body, title) => document(w, h, title, body);

// svgBody: the picture. fxBody: only the glowing pieces (drawn on transparent), or null.
async function render(file, w, h, svgBody, { fxBody = null, bloom = 1, bloomBlur = 22, vignette = .16, scale = 2 } = {}) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const raster = async body => sharp(Buffer.from(wrap(w, h, body, path.basename(file))), { density: 72 * scale }).ensureAlpha().png().toBuffer();
  let base = await raster(svgBody);
  const layers = [];
  if (fxBody) {
    const fx = await raster(fxBody);
    const blurred = await sharp(fx).blur(bloomBlur * scale / 2).png().toBuffer();
    layers.push({ input: blurred, blend: 'screen' });
    if (bloom > 1) layers.push({ input: blurred, blend: 'screen' });
  }
  if (vignette) {
    const v = wrap(w, h, `<defs><radialGradient id="v" cx=".5" cy=".5" r=".78"><stop offset=".6" stop-color="#0A1432" stop-opacity="0"/><stop offset="1" stop-color="#0A1432" stop-opacity="${vignette}"/></radialGradient></defs><rect width="${w}" height="${h}" fill="url(#v)"/>`, 'v');
    layers.push({ input: await raster(v.replace(/^<svg[^>]*>|<\/svg>$/g, '')), blend: 'over' });
  }
  if (layers.length) base = await sharp(base).composite(layers).png().toBuffer();
  await sharp(base).resize(w, h, { kernel: 'lanczos3' }).flatten({ background: '#FFFFFF' }).png({ compressionLevel: 9 }).toFile(file);
  const bytes = fs.statSync(file).size;
  console.log(JSON.stringify({ file: path.relative(process.cwd(), file), w, h, bytes }));
  return bytes;
}

module.exports = { render, sharp };

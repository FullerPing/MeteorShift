const fs = require('node:fs');
const path = require('node:path');
const sharp = require('C:/Users/37062/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const dir = path.resolve('assets/hud/rebirth-icons');
const names = ['reset', 'cycle', 'spark'];
const labels = ['Reset', 'Cycle', 'Spark'];
const source = names.map(n => fs.readFileSync(path.join(dir, `rebirth-${n}.svg`), 'utf8'));
function icon(i, x, y, size, color) {
  return source[i].replace('<svg ', `<svg x="${x}" y="${y}" color="${color}" `)
    .replace('width="64" height="64"', `width="${size}" height="${size}"`);
}
(async () => {
  for (let i = 0; i < names.length; i++) {
    const svg = source[i].replace('<svg ', '<svg color="#ffffff" ');
    const output = path.join(dir, `rebirth-${names[i]}-white.png`);
    await sharp(Buffer.from(svg)).png().toFile(output);
    const { data, info } = await sharp(output).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    let left = 64, top = 64, right = -1, bottom = -1;
    for (let y = 0; y < 64; y++) for (let x = 0; x < 64; x++) {
      if (data[(y * 64 + x) * 4 + 3] > 0) {
        left = Math.min(left, x); top = Math.min(top, y);
        right = Math.max(right, x); bottom = Math.max(bottom, y);
      }
    }
    if (left < 3 || top < 3 || right > 60 || bottom > 60) throw new Error(`Clipped ${names[i]}`);
    console.log(`${names[i]}: ${info.width}x${info.height}, alpha bounds ${left},${top}–${right},${bottom}`);
  }
  const cards = names.map((_, i) => {
    const x = 24 + i * 248;
    return `<rect x="${x}" y="94" width="232" height="292" rx="16" fill="#ffffff"/>
      <text x="${x+20}" y="128" fill="#192536" font-size="18" font-weight="600">${labels[i]}</text>
      ${icon(i, x+84, 157, 64, '#182332')}
      <rect x="${x+12}" y="244" width="208" height="130" rx="12" fill="#13212b"/>
      ${icon(i, x+38, 268, 64, '#89edc9')}
      ${icon(i, x+145, 288, 24, '#ffffff')}
      <text x="${x+56}" y="356" fill="#a5b5c4" font-size="12">64px</text>
      <text x="${x+143}" y="356" fill="#a5b5c4" font-size="12">24px</text>`;
  }).join('');
  const preview = `<svg xmlns="http://www.w3.org/2000/svg" width="792" height="414" viewBox="0 0 792 414">
    <rect width="792" height="414" fill="#eaf0f3"/>
    <g font-family="Segoe UI, Arial, sans-serif">
    <text x="24" y="39" font-size="24" font-weight="600" fill="#172536">Rebirth icons</text>
    <text x="24" y="65" font-size="14" fill="#536475">64 × 64 · transparent SVG · one color</text>
    ${cards}</g></svg>`;
  await sharp(Buffer.from(preview)).png().toFile(path.join(dir, 'preview.png'));
})();

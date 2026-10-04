const fs = require('node:fs');
const path = require('node:path');
const sharp = require('C:/Users/37062/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const dir = path.resolve('assets/hud/teleport-icons');
const names = ['portal', 'warp', 'pad', 'linked', 'blink', 'pad-refined', 'warp-refined'];
const labels = ['01  Portal', '02  Warp', '03  Teleport pad', '04  Linked portals', '05  Blink burst', '06  Pad refined', '07  Warp refined'];
const sources = names.map(name => fs.readFileSync(path.join(dir, `teleport-${name}.svg`), 'utf8'));
function icon(i, x, y, size, color) {
  return sources[i].replace('<svg ', `<svg x="${x}" y="${y}" color="${color}" `)
    .replace('width="64" height="64"', `width="${size}" height="${size}"`);
}
async function caption(size, color) {
  const fontfile = 'C:/Users/37062/AppData/Local/Roblox/Versions/version-76e1a02649ad4f35/content/fonts/Montserrat-Bold.ttf';
  const { data, info } = await sharp({ text: {
    text: `<span foreground="${color}">TELEPORT</span>`, font: `Montserrat Bold ${size}`,
    fontfile, dpi: 72, rgba: true,
  } }).png().toBuffer({ resolveWithObject: true });
  return { width: info.width, height: info.height, url: `data:image/png;base64,${data.toString('base64')}` };
}
function captionImage(caption, center, top) {
  return `<image x="${center - caption.width / 2}" y="${top}" width="${caption.width}" height="${caption.height}" href="${caption.url}"/>`;
}
(async () => {
  const desktopDark = await caption(16, '#182332');
  const desktopLight = await caption(16, '#ffffff');
  const touchLight = await caption(12, '#ffffff');
  for (let i = 0; i < names.length; i++) {
    const output = path.join(dir, `teleport-${names[i]}-white.png`);
    await sharp(Buffer.from(sources[i].replace('<svg ', '<svg color="#ffffff" '))).png().toFile(output);
    const { data, info } = await sharp(output).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    let left = 64, top = 64, right = -1, bottom = -1;
    for (let y = 0; y < 64; y++) for (let x = 0; x < 64; x++) {
      if (data[(y * 64 + x) * 4 + 3]) {
        left = Math.min(left, x); top = Math.min(top, y);
        right = Math.max(right, x); bottom = Math.max(bottom, y);
      }
    }
    if (info.width !== 64 || info.height !== 64 || left < 3 || top < 3 || right > 60 || bottom > 60) throw new Error(`Clipped canvas: ${names[i]}`);
    if (data[3] !== 0 || data[(64 * 64 - 1) * 4 + 3] !== 0) throw new Error('Nontransparent corners');
    console.log(`${names[i]}: 64x64 transparent, alpha bounds ${left},${top} to ${right},${bottom}`);
  }
  function card(i, column) {
    const x = 24 + column * 248;
    return `<rect x="${x}" y="94" width="232" height="292" rx="16" fill="#ffffff"/>
      <text x="${x + 20}" y="128" fill="#192536" font-size="18" font-weight="600">${labels[i]}</text>
      ${icon(i, x + 84, 150, 64, '#182332')}
      ${captionImage(desktopDark, x + 116, 220)}
      <rect x="${x + 12}" y="244" width="208" height="130" rx="12" fill="#13212b"/>
      ${icon(i, x + 38, 258, 64, '#89e7fb')}
      ${captionImage(desktopLight, x + 70, 328)}
      ${icon(i, x + 141, 280, 32, '#ffffff')}
      ${captionImage(touchLight, x + 157, 320)}
      <text x="${x + 46}" y="359" fill="#a5b5c4" font-size="11">Desktop</text>
      <text x="${x + 141}" y="349" fill="#a5b5c4" font-size="11">Touch</text>`;
  }
  async function preview(indices, title, filename) {
    const width = 48 + indices.length * 248;
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="414" viewBox="0 0 ${width} 414">
    <rect width="${width}" height="414" fill="#eaf0f3"/>
    <g font-family="Segoe UI, Arial, sans-serif">
      <text x="24" y="39" font-size="24" font-weight="600" fill="#172536">${title}</text>
      <text x="24" y="65" font-size="14" fill="#536475">64 × 64 SVG · matching HUD caption · single-line TELEPORT label</text>
      ${indices.map((i, column) => card(i, column)).join('')}
    </g>
  </svg>`;
    await sharp(Buffer.from(svg)).png().toFile(path.join(dir, filename));
  }
  await preview([0, 1, 2, 3, 4], 'Teleport icons', 'preview.png');
  await preview([3, 4], 'Two more teleport icons', 'preview-more.png');
  await preview([5, 6], 'Refined teleport icons', 'preview-refined.png');
})();

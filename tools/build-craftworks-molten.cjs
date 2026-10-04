// Authored vector composition. Shared illustration paths remain editable.
const fs = require('node:fs');
const path = require('node:path');
const opentype = require('../.tmp/craterworks-opentype.cjs');
const sharp = require('C:/Users/37062/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '..');
const artDir = path.join(root, 'assets/marketing/vector-art');
const outDir = path.join(root, 'assets/marketing/craftworks');
const font = opentype.loadSync(path.join(artDir, 'fonts/FredokaOne-Regular.ttf'));
fs.mkdirSync(outDir, { recursive: true });

function paths(text, size, spacing = 0) {
  let x = 0;
  const glyphs = font.stringToGlyphs(text);
  const d = glyphs.map((g, i) => {
    const result = g.getPath(x, 0, size).toPathData(3);
    x += g.advanceWidth / font.unitsPerEm * size + spacing;
    if (i < glyphs.length - 1) x += font.getKerningValue(g, glyphs[i + 1]) / font.unitsPerEm * size;
    return result;
  }).join(' ');
  return { d, width: x - spacing, box: font.getPath(text, 0, 0, size).getBoundingBox() };
}
function label(text, size, x, top, fill, id, options = {}) {
  let p = paths(text, size, options.spacing || 0);
  if (options.maxWidth) {
    while (p.width > options.maxWidth) { size -= .5; p = paths(text, size, options.spacing || 0); }
  }
  if (options.center) x -= p.width / 2;
  const baseline = top - p.box.y1;
  const stroke = options.stroke ?? Math.max(3, size * .062);
  const depth = options.depth ?? Math.max(3, size * .062);
  return `<g id="${id}" aria-label="${text}" stroke-linejoin="round">
    <path d="${p.d}" transform="translate(${x} ${baseline + depth + 3})" fill="#061A28" stroke="#061A28" stroke-width="${stroke + 4}"/>
    <path d="${p.d}" transform="translate(${x} ${baseline + depth})" fill="#D96622" stroke="#061A28" stroke-width="${stroke + 2}"/>
    <path d="${p.d}" transform="translate(${x} ${baseline})" fill="${fill}" stroke="#061A28" stroke-width="${stroke}" paint-order="stroke fill"/>
  </g>`;
}
function inner(name, prefix) {
  let source = fs.readFileSync(path.join(artDir, `${name}.svg`), 'utf8');
  source = source.slice(source.indexOf('>') + 1, source.lastIndexOf('</svg>'));
  source = source.replace(/<(title|desc)[^>]*>[\s\S]*?<\/\1>/g, '');
  return source.replace(/id="([^"]+)"/g, (_, id) => `id="${prefix}-${id}"`)
    .replace(/url\(#([^)]*)\)/g, (_, id) => `url(#${prefix}-${id})`);
}
function piece(name, id, x, y, width, height, viewBox) {
  return `<svg id="${id}" x="${x}" y="${y}" width="${width}" height="${height}" viewBox="${viewBox}" overflow="visible">${inner(name, id)}</svg>`;
}
function star(x, y, scale, color = '#FFF3BD') {
  return `<path d="M0-24 6-6 24 0 6 6 0 24-6 6-24 0-6-6Z" transform="translate(${x} ${y}) scale(${scale})" fill="${color}"/>`;
}
function chunk(x, y, scale, rotation = 0, glowing = false) {
  return `<g transform="translate(${x} ${y}) rotate(${rotation}) scale(${scale})" stroke="#102334" stroke-width="5" stroke-linejoin="round">
    <path d="m-29-8 17-26 37 2 18 25-9 30-41 9-24-22Z" fill="#344855"/>
    <path d="m-29-8 17-26 37 2-6 24-24 9Z" fill="#73838A" stroke="none"/>
    <path d="m19-8 24 1-9 30-41 9 12-31Z" fill="#183143" stroke="none"/>
    ${glowing ? '<path d="m-19-17 13 18 25-9-4 24" stroke="#FF8B32" stroke-width="7" fill="none"/><path d="m-19-17 13 18 25-9-4 24" stroke="#FFEFA0" stroke-width="2.5" fill="none"/>' : ''}
  </g>`;
}
const defs = `<defs>
  <linearGradient id="night" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#164F67"/><stop offset=".5" stop-color="#102C46"/><stop offset="1" stop-color="#08182C"/></linearGradient>
  <radialGradient id="impact"><stop stop-color="#FFBA56" stop-opacity=".66"/><stop offset=".45" stop-color="#FF8236" stop-opacity=".22"/><stop offset="1" stop-color="#FF6430" stop-opacity="0"/></radialGradient>
  <linearGradient id="letters" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#FFF9D4"/><stop offset=".45" stop-color="#FFEBA0"/><stop offset="1" stop-color="#FFC55E"/></linearGradient>
  <linearGradient id="trail" x1="0" y1="1" x2="1" y2="0"><stop stop-color="#FF923A" stop-opacity=".8"/><stop offset="1" stop-color="#FFCC76" stop-opacity="0"/></linearGradient>
  <linearGradient id="lowerShade" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#091C30" stop-opacity="0"/><stop offset="1" stop-color="#091C30" stop-opacity=".98"/></linearGradient>
</defs>`;
function document(width, height, title, body) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" fill="none" role="img" aria-label="${title}"><title>${title}</title><desc>Craftworks: Meteor Mining. Molten Impact. Editable vector artwork with outlined Fredoka lettering, a mining pickaxe and a glowing basalt meteor.</desc>${defs}${body}</svg>`;
}
const icon = document(512, 512, 'Craftworks Meteor Mining — Molten Impact game icon', `
  <g id="icon-atmosphere">
    <path d="M0 0h512v512H0Z" fill="url(#night)"/>
    <circle cx="328" cy="228" r="278" fill="url(#impact)"/>
    <path d="M210 170 410-35H545L345 262Z" fill="url(#trail)"/>
    <path d="m324 174 190-202m-80 72-130 147" stroke="#FFDB8C" stroke-opacity=".32" stroke-width="8" stroke-linecap="round"/>
    <path d="M-10 325 74 287 149 325 205 298 287 336 373 296 436 317 524 286V512H-10Z" fill="#0B2338"/>
    <ellipse cx="290" cy="389" rx="202" ry="44" fill="#071B2B"/>
    <ellipse cx="290" cy="383" rx="162" ry="30" fill="#F79037" opacity=".35"/>
    <ellipse cx="290" cy="379" rx="142" ry="23" stroke="#FFD777" stroke-width="5" opacity=".65"/>
  </g>
  <g id="mining-hero">
    ${piece('meteor-pickaxe', 'crossed-pickaxe-meteor', 19, 20, 475, 393, '43 43 510 514')}
    ${chunk(465, 292, .5, 19, true)}
    ${chunk(73, 319, .4, -21)}
    ${star(420, 56, .9)}
    ${star(49, 221, .65, '#92F4F7')}
    ${star(468, 188, .35)}
    <path d="m356 67 13-21m-302 68 14-12m358 232 20 10" stroke="#FFC361" stroke-width="5" stroke-linecap="round"/>
  </g>
  <path d="M0 387h512v125H0Z" fill="url(#lowerShade)"/>
  ${label('CRAFTWORKS', 67, 256, 435, 'url(#letters)', 'craftworks-icon-wordmark', { center: true, maxWidth: 462, stroke: 5, depth: 4 })}
`);
const thumbnail = document(1920, 1080, 'Craftworks Meteor Mining — Molten Impact thumbnail', `
  <g id="quarry-sky">
    <path d="M0 0h1920v1080H0Z" fill="url(#night)"/>
    <ellipse cx="1380" cy="536" rx="780" ry="660" fill="url(#impact)"/>
    <path d="M1174 475 1575-85H2020L1519 719Z" fill="url(#trail)"/>
    <path d="m1438 380 328-426m-241 421L1904-7" stroke="#FFDA92" stroke-width="16" stroke-opacity=".18" stroke-linecap="round"/>
    <path d="m1523 64 58-72m203 179 72-99m-252 333 96-126" stroke="#FFC976" stroke-width="8" stroke-opacity=".46" stroke-linecap="round"/>
    ${star(1456, 65, .8)}${star(1780, 234, 1.1)}${star(902, 137, .55, '#95EDF1')}
    <circle cx="800" cy="82" r="5" fill="#92DAE7" opacity=".65"/>
    <circle cx="1157" cy="107" r="4" fill="#FFE09A" opacity=".65"/>
  </g>
  <g id="quarry-walls">
    <path d="M0 531 124 434 293 503 421 432 614 505 762 459 918 524 1122 446 1330 527 1491 430 1664 476 1842 388 1920 422V869H0Z" fill="#284B61"/>
    <path d="m0 627 193-111 157 37 218-57 167 115 180-57 126 75 185-118 186 118 209-85 159 66 140-86v370H0Z" fill="#203B50"/>
    <path d="m0 627 193-111-50 150 126 131H0Zm568-131 167 115-68 126-140 44Zm658 15 186 118-94 181-161-143Zm515 100 179-86v377h-93l-96-160Z" fill="#33566A"/>
    <path d="M0 740 229 689 479 743 732 693 1032 744 1251 685 1531 736 1710 677 1920 725V1040H0Z" fill="#122B42"/>
  </g>
  <g id="crater-impact-floor">
    <ellipse cx="1000" cy="1110" rx="1420" ry="451" fill="#536976"/>
    <ellipse cx="1000" cy="1136" rx="1350" ry="438" fill="#1D374B"/>
    <path d="m0 829 185 44 229-54 292 71 205-38 291 69 214-38 249 50 255-49v196H0Z" fill="#2F4B5F"/>
    <path d="m0 949 190 53 228-44 235 51 229-38 278 43 294-39 239 47 227-36v94H0Z" fill="#203B50"/>
    <path d="m0 829 185 44 229-54 292 71 205-38 291 69m-1017-48 36 76m485-59 23 80m705-87 80 96" stroke="#688593" stroke-width="8" opacity=".54"/>
    <ellipse cx="1385" cy="922" rx="487" ry="117" fill="#071A2C"/>
    <ellipse cx="1385" cy="912" rx="426" ry="96" fill="#743E30"/>
    <ellipse cx="1385" cy="906" rx="393" ry="80" fill="#E07532"/>
    <ellipse cx="1385" cy="900" rx="369" ry="65" fill="#FFCA62"/>
    <ellipse cx="1385" cy="895" rx="340" ry="51" fill="#FFEA9D"/>
  </g>
  <g id="meteor-and-debris">
    ${chunk(929, 789, 1.1, -24, true)}
    ${chunk(1810, 542, .78, 32, true)}
    ${chunk(1770, 922, 1.3, 9, true)}
    ${chunk(1165, 244, .7, -28, true)}
    ${piece('meteor', 'molten-hero-meteor', 992, 227, 770, 751, '145 160 397 387')}
    <path d="m937 609-51-21m111-176-29-60m777 59 42-46m-7 389 41 18" stroke="#FFE696" stroke-width="8" stroke-linecap="round"/>
    ${star(968, 568, 1.45)}${star(1729, 327, .8)}
  </g>
  <g id="foreground-miner">
    <ellipse cx="492" cy="1030" rx="256" ry="31" fill="#081D30" opacity=".75"/>
    ${piece('miner-with-pickaxe', 'gold-armored-miner', 178, 300, 625, 754, '0 0 680 820')}
    ${chunk(95, 953, 1.45, -16)}
    ${chunk(798, 1039, 1.1, 12)}
  </g>
  <g id="game-title">
    ${label('CRAFTWORKS', 143, 93, 83, 'url(#letters)', 'craftworks-thumbnail-wordmark', { maxWidth: 1030, stroke: 9, depth: 8 })}
    ${label('METEOR MINING', 54, 100, 235, '#9DF5F2', 'meteor-mining-subtitle', { spacing: 4, stroke: 4, depth: 2 })}
  </g>
`);
async function main() {
  for (const [name, svg, width, height] of [['icon', icon, 512, 512], ['thumbnail', thumbnail, 1920, 1080]]) {
    const prefix = path.join(outDir, `molten-impact-${name}`);
    fs.writeFileSync(`${prefix}.svg`, svg);
    await sharp(Buffer.from(svg)).png({ compressionLevel: 9 }).toFile(`${prefix}.png`);
    const meta = await sharp(`${prefix}.png`).metadata();
    if (meta.width !== width || meta.height !== height) throw new Error('Unexpected export dimensions');
    console.log(JSON.stringify({ file: `${prefix}.png`, width, height, bytes: fs.statSync(`${prefix}.png`).size, embeddedImages: (svg.match(/<image\b/g) || []).length }));
  }
  await sharp(path.join(outDir, 'molten-impact-icon.png')).resize(150, 150).png().toFile(path.join(outDir, 'molten-impact-icon-150.png'));
  await sharp(path.join(outDir, 'molten-impact-thumbnail.png')).resize(960, 540).png().toFile(path.join(outDir, 'molten-impact-thumbnail-preview.png'));
}
main().catch(error => { console.error(error); process.exitCode = 1; });

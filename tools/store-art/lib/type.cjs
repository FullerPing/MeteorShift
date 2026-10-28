// Typography for the store art: Fredoka One outlines with the Craterworks stacked-ink look.
// Copied from tools/key-art/typography.cjs (pure Node, no Blender) so this folder stands alone.
const fs = require('node:fs');
const path = require('node:path');
const opentype = require('../../../.tmp/craterworks-opentype.cjs');
const sharp = require('C:/Users/37062/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '../../..');
const font = opentype.loadSync(path.join(root, 'assets/marketing/vector-art/fonts/FredokaOne-Regular.ttf'));
const INK = '#0E1834';
const cap = -font.charToGlyph('H').getPath(0, 0, 1000).getBoundingBox().y1 / 1000;
let serial = 0;

function glyphRun(text, H, personality = true, spacing = 0) {
  const size = H / cap;
  const glyphs = font.stringToGlyphs(text);
  let x = 0;
  const list = glyphs.map((glyph, i) => {
    const advance = glyph.advanceWidth / font.unitsPerEm * size;
    const rotation = personality ? [-1.4, 1.6, -.8, 1.1, -1.8, .5, 1.8, -.9, 1.2, -1.1, .6][i % 11] : 0;
    const dy = personality ? [-.018, .022, -.009, .027, -.021, .008, -.025, .02, -.008, .026, -.015][i % 11] * H : 0;
    const d = glyph.getPath(0, 0, size).toPathData(3);
    const transform = `translate(${x} ${dy}) rotate(${rotation} ${advance / 2} ${-H / 2})`;
    x += advance + spacing * H;
    if (i < glyphs.length - 1) x += font.getKerningValue(glyph, glyphs[i + 1]) / font.unitsPerEm * size;
    return { d, transform, char: text[i] };
  });
  return { list, width: x - spacing * H };
}

function letters(text, H, { split = 0, personality = true, spacing = 0, gold = true, faceTop = '#FFF078', faceBottom = '#FFB21E', lipColor, pinkFrom } = {}) {
  const run = glyphRun(text, H, personality, spacing);
  const id = `letters${serial++}`;
  const shapes = run.list.map(g => `<path d="${g.d}" transform="${g.transform}"/>`).join('');
  const defs = `<defs><g id="${id}">${shapes}</g>
    <linearGradient id="${id}-ice" x1="0" y1="${-H}" x2="0" y2="0" gradientUnits="userSpaceOnUse"><stop stop-color="#FFFFFF"/><stop offset="1" stop-color="#C4F2FF"/></linearGradient>
    <linearGradient id="${id}-gold" x1="0" y1="${-H}" x2="0" y2="0" gradientUnits="userSpaceOnUse"><stop stop-color="${faceTop}"/><stop offset="1" stop-color="${faceBottom}"/></linearGradient>
    <filter id="${id}-shadow" x="-20%" y="-100%" width="140%" height="350%"><feGaussianBlur stdDeviation="${H * .12}"/></filter>
    <clipPath id="${id}-top"><rect x="${-H}" y="${-H * 1.1}" width="${run.width + H * 2}" height="${H * .59}"/></clipPath>
  </defs>`;
  const outer = `<use href="#${id}" fill="${INK}" stroke="${INK}" stroke-width="${H * .16}"/>`;
  const layers = run.list.map((g, i) => {
    const ice = split ? i < split : !gold;
    const lip = lipColor || (ice ? '#789CD2' : '#AA4608');
    const gId = `${id}-glyph${i}`;
    return `<g transform="${g.transform}"><defs><clipPath id="${gId}"><path d="${g.d}"/></clipPath></defs>
      <path d="${g.d}" transform="translate(0 ${H * .09})" fill="${lip}" stroke="${INK}" stroke-width="${H * .10}"/>
      <path d="${g.d}" fill="url(#${id}-${ice ? 'ice' : 'gold'})" stroke="${INK}" stroke-width="${H * .06}" paint-order="stroke fill"/>
      <g clip-path="url(#${gId})"><rect x="${-H}" y="${-H * 1.1}" width="${H * 3}" height="${H * .6}" fill="white" opacity=".28"/>
      <g clip-path="url(#${id}-top)"><path d="${g.d}" transform="translate(0 ${H * .035})" fill="none" stroke="white" stroke-width="${H * .03}" opacity=".9"/></g></g></g>`;
  }).join('');
  const glow = pinkFrom === undefined ? '' : `<g fill="#FF6EBE" stroke="#FF6EBE" stroke-width="${H * .20}" opacity=".45" filter="url(#${id}-shadow)">${run.list.slice(pinkFrom).map(g => `<path d="${g.d}" transform="${g.transform}"/>`).join('')}</g>`;
  return { width: run.width, body: `${defs}<g stroke-linejoin="round" stroke-linecap="round">${glow}<g transform="translate(0 ${H * .22})" opacity=".4" filter="url(#${id}-shadow)">${outer}</g>${outer}${layers}</g>` };
}

function simpleText(text, H, spacing = .06) {
  const run = glyphRun(text, H, false, spacing);
  return { width: run.width, body: `<g fill="white" stroke="${INK}" stroke-width="${H * .12}" stroke-linejoin="round" paint-order="stroke fill">${run.list.map(g => `<path d="${g.d}" transform="${g.transform}"/>`).join('')}</g>` };
}

function ribbon(text, width, H, wordH) {
  const id = `ribbon${serial++}`;
  const textH = H * .47;
  const label = simpleText(text, textH);
  const textScale = Math.min(1, (width * .83) / label.width);
  const tail = H * .42;
  const d = `M${-tail} ${H * .03} Q${width / 2} ${-H * .13} ${width + tail} ${H * .03} L${width + tail * .58} ${H * .46} L${width + tail} ${H * .92} Q${width / 2} ${H * 1.06} ${-tail} ${H * .92} L${-tail * .58} ${H * .46}Z`;
  return `<defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#56BAFF"/><stop offset="1" stop-color="#1E68E8"/></linearGradient></defs>
    <g stroke="${INK}" stroke-linejoin="round" stroke-width="${wordH * .08}"><path d="${d}" transform="translate(0 ${H * .10})" fill="#103A96"/><path d="${d}" fill="url(#${id})"/>
    <path d="M${-tail * .45} ${H * .13} Q${width / 2} ${H * -.01} ${width + tail * .45} ${H * .13}" fill="none" stroke="white" stroke-opacity=".28" stroke-width="${H * .055}"/>
    <g transform="translate(${(width - label.width * textScale) / 2} ${H * .69}) scale(${textScale})">${label.body}</g></g>`;
}

function document(width, height, title, body, viewBox = `0 0 ${width} ${height}`) {
  return `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${width}" height="${height}" viewBox="${viewBox}"><title>${title}</title>${body}</svg>`;
}
module.exports = { sharp, font, INK, letters, simpleText, ribbon, glyphRun, document, cap, root };

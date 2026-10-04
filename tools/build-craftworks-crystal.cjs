/*
 * Craftworks: Meteor Mining / Crystal Rush artwork.
 * Manually composed vector illustration. No bitmap generation, embedded images,
 * external resources, or runtime fonts. Text is outlined from project Fredoka.
 * Rebuild from the repository root with the bundled Node runtime.
 */
const fs = require('node:fs');
const path = require('node:path');
const opentype = require('../.tmp/craterworks-opentype.cjs');
const sharp = require('C:/Users/37062/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '..');
const output = path.join(root, 'assets/marketing/craftworks');
const source = path.join(root, 'assets/marketing/vector-art');
fs.mkdirSync(output, { recursive: true });
const font = opentype.loadSync(path.join(source, 'fonts/FredokaOne-Regular.ttf'));
const readInner = name => fs.readFileSync(path.join(source, name + '.svg'), 'utf8').replace(/^.*?<title>.*?<\/title>/s, '').replace(/<\/svg>\s*$/, '');
function outlined(words, x, y, maxWidth, size, fill, stroke = 9, shadow = 8) {
  let p = font.getPath(words, 0, 0, size);
  let box = p.getBoundingBox();
  if (box.x2 - box.x1 > maxWidth) {
    size *= maxWidth / (box.x2 - box.x1);
    p = font.getPath(words, 0, 0, size);
    box = p.getBoundingBox();
  }
  const d = p.toPathData(2);
  return `<g aria-label="${words}" transform="translate(${(x-box.x1).toFixed(2)} ${(y-box.y1).toFixed(2)})"><path d="${d}" transform="translate(0 ${shadow})" fill="#246A9B" stroke="#0B183B" stroke-width="${stroke+3}" stroke-linejoin="round"/><path d="${d}" fill="${fill}" stroke="#0B183B" stroke-width="${stroke}" stroke-linejoin="round" paint-order="stroke fill"/></g>`;
}
function centeredOutlined(words, canvasWidth, y, maxWidth, size, fill, stroke, shadow) {
  const bounds = font.getPath(words, 0, 0, size).getBoundingBox();
  const width = Math.min(maxWidth, bounds.x2 - bounds.x1);
  return outlined(words, (canvasWidth-width)/2, y, maxWidth, size, fill, stroke, shadow);
}
const defs = `<defs>
  <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#20275C"/><stop offset="1" stop-color="#123752"/></linearGradient>
  <linearGradient id="crystal-front" x1="0" y1="0" x2=".7" y2="1"><stop stop-color="#C7FEFF"/><stop offset=".55" stop-color="#54DEF0"/><stop offset="1" stop-color="#258AB6"/></linearGradient>
  <linearGradient id="crystal-side" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#379AC8"/><stop offset="1" stop-color="#185179"/></linearGradient>
  <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#FFF5B1"/><stop offset="1" stop-color="#FFD24D"/></linearGradient>
  <radialGradient id="light"><stop stop-color="#69EDFF" stop-opacity=".48"/><stop offset="1" stop-color="#50D7F6" stop-opacity="0"/></radialGradient>
</defs>`;
const meteor = `<g id="crystal-meteor" stroke="#0B183B" stroke-width="11" stroke-linejoin="round">
  <g id="back-crystal-spires">
    <path d="m325 205 52-156 61-30 41 68-82 172Z" fill="#587CCF"/>
    <path d="m377 49 5 144 56-174Z" fill="#A7B7FF" stroke="none"/>
    <path d="m382 193 97-106-41-68Z" fill="#6F50B3" stroke="none"/>
    <path d="m366 270 122-123 59 6 14 76-160 103Z" fill="#5880D0"/>
    <path d="m488 147-81 139 140-133Z" fill="#C0C5FF" stroke="none"/>
    <path d="m407 286 154-57-14-76Z" fill="#755EC2" stroke="none"/>
    <path d="m246 192 11-127 55-44 29 58-23 150Z" fill="#79DEF4"/>
    <path d="m257 65 28 132 27-176Z" fill="#D3FCFF" stroke="none"/>
    <path d="m285 197 56-118-29-58Z" fill="#489FD2" stroke="none"/>
  </g>
  <path d="m126 210 80-65 117-12 119 53 58 92-24 114-90 86-128 22-119-59-73-96 16-81Z" fill="url(#crystal-front)"/>
  <g stroke="none" id="meteor-facets">
    <path d="m126 210 80-65 79 94-102 57Z" fill="#B7F7FC"/>
    <path d="m206 145 117-12-38 106Z" fill="#F0FEFF"/>
    <path d="m323 133 119 53-93 94-64-41Z" fill="#7BDDED"/>
    <path d="m442 186 58 92-78 70-73-68Z" fill="#3B9BC7"/>
    <path d="m500 278-24 114-54-44Z" fill="#255882"/>
    <path d="m476 392-90 86-27-94 63-36Z" fill="#197AA9"/>
    <path d="m386 478-128 22 25-115 76-1Z" fill="#2595BC"/>
    <path d="m258 500-119-59 68-79 76 23Z" fill="#49CAE0"/>
    <path d="m139 441-73-96 117-49 24 66Z" fill="#86E4ED"/>
    <path d="m66 345 16-81 44-54 57 86Z" fill="#D1FAFB"/>
    <path d="m183 296 102-57 64 41 10 104-76 1-76-23Z" fill="#51C9DE"/>
    <path d="m285 239 64 41-66 105-100-89Z" fill="#8AEAF3"/>
  </g>
  <g id="crystal-veins" fill="none" stroke="#0B183B" stroke-width="15" stroke-linecap="round">
    <path d="m314 163-28 77 34 42-39 98 35 60"/>
    <path d="m181 298 104-58m35 42 102 65 34 1m-175 32-73-16-24 40"/>
  </g>
  <g fill="none" stroke="#C7FDFF" stroke-width="7" stroke-linecap="round">
    <path d="m314 163-28 77 34 42-39 98 35 60"/>
    <path d="m181 298 104-58m35 42 102 65 34 1m-175 32-73-16-24 40"/>
  </g>
  <path d="m115 223 64-53m160-18 37 17" stroke="#F0FEFF" stroke-width="9" stroke-linecap="round"/>
</g>`;
const spark = (x,y,s=1,color='#DFFFFF') => `<path d="M0-23 6-6 23 0 6 6 0 23-6 6-23 0-6-6Z" transform="translate(${x} ${y}) scale(${s})" fill="${color}"/>`;
const shard = (x,y,s=1,angle=0) => `<g transform="translate(${x} ${y}) rotate(${angle}) scale(${s})" stroke="#0B183B" stroke-width="6" stroke-linejoin="round"><path d="m0-49 34 22-5 47L-3 43-30 16-27-27Z" fill="#83E6F2"/><path d="m0-49 1 91 28-22 5-47Z" fill="#389DCB" stroke="none"/><path d="m0-49-27 22-3 43 31-12Z" fill="#D1F9FF" stroke="none"/></g>`;
const pickaxe = `<g id="crystal-pickaxe" stroke="#0B183B" stroke-linejoin="round">
  <path d="m179 103 29 15-115 285q-7 14-19 10l-13-8q-11-8-5-20Z" fill="#FFCA54" stroke-width="10"/>
  <path d="m184 119 9 4-113 272-8-3Z" fill="#FFF4A6" stroke="none"/>
  <path d="M66 153q17-62 79-86 100-38 185 67l-25 19q-62-48-122-41-61 3-96 45Z" fill="#537ADC" stroke-width="11"/>
  <path d="M76 139q34-54 89-61 67-10 127 45-84-45-154-6Z" fill="#B9D3FF" stroke="none"/>
  <path d="m72 139 15 18 28-16-12-18Zm223-6 10 20 25-19-16-16Z" fill="#E8FFFF" stroke-width="5"/>
  <path d="m173 95 29 6-13 40-27-10Z" fill="#303D6C" stroke-width="7"/>
  <path d="m171 103 9 3-6 23-9-4Z" fill="#7394CF" stroke="none"/>
</g>`;

function icon() {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512" role="img" aria-labelledby="title desc"><title id="title">Craftworks: Meteor Mining / Crystal Rush icon</title><desc id="desc">A cyan crystal meteor and a purple mining pickaxe on a deep blue background. Craftworks is drawn in outlined Fredoka lettering.</desc>${defs}
  <g id="icon-background"><path d="M0 0h512v512H0Z" fill="url(#sky)"/><path d="M0 374 512 90v422H0Z" fill="#284777"/>
  <path d="m269 219 192-219h51v153L350 300Z" fill="#584496"/><path d="m304 221 176-174 18 58-151 173Z" fill="#687CCA"/>
  <circle cx="257" cy="262" r="217" fill="url(#light)"/>
  <ellipse cx="251" cy="396" rx="196" ry="39" fill="#0B183B"/><ellipse cx="259" cy="388" rx="167" ry="24" fill="#377797"/>
  </g>
  <g transform="translate(66 42) scale(.66)">${meteor}</g>
  <g transform="translate(117 121) rotate(-19 145 225) scale(.68)">${pickaxe}</g>
  ${shard(54,303,.38,-28)}${shard(441,348,.38,26)}${spark(64,156,.54)}${spark(423,136,.60)}${spark(390,389,.38,'#B6A6FF')}
  ${centeredOutlined('CRAFTWORKS',512,435,454,63,'url(#gold)',6,4)}
  </svg>`;
}
function thumbnail() {
  let miner = readInner('miner-with-pickaxe');
  miner = miner.replaceAll('#FFB642','#9264D4').replaceAll('#FFE08D','#C9B2F0').replaceAll('#FF742C','#573B89').replaceAll('#46B5B7','#4CCBE4').replaceAll('#92313B','#2E4572').replaceAll('#D95246','#6EB3E8').replaceAll('#6A2430','#1E2C4B');
  let refinery = readInner('refinery');
  refinery = refinery.replaceAll('#FFB642','#59C9DF').replaceAll('#FFE08D','#BBF5FC').replaceAll('#E77935','#25729D');
  // Finished bars stay gold; they are the output, unlike the cyan machines.
  refinery = refinery.replace(/(<g id="collection-bars".*?<\/g>)/s, m => m.replaceAll('#BBF5FC','#FFF4A5').replaceAll('#59C9DF','#FFCA54'));
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080" role="img" aria-labelledby="title desc"><title id="title">Craftworks: Meteor Mining / Crystal Rush thumbnail</title><desc id="desc">A purple armored miner chips a bright cyan meteor in a rocky blue quarry, beside a cyan hopper, refinery, and conveyor delivering gold bars. Title Craftworks Meteor Mining.</desc>${defs}
  <g id="sky-and-arrival"><path d="M0 0h1920v1080H0Z" fill="url(#sky)"/><path d="m1130 390 487-390h303v120l-589 424Z" fill="#3F3B7A"/><path d="m1278 443 490-387h152v53l-546 409Z" fill="#62569F"/><path d="m1317 419 454-292 30 26-428 334Z" fill="#87B7DD" opacity=".45"/>
  ${spark(1658,224,1.5,'#A2BDF6')}${spark(1814,350,.75,'#BBF6FC')}${spark(1110,96,.62,'#A5B7E8')}
  <ellipse cx="1375" cy="651" rx="615" ry="466" fill="url(#light)"/>
  </g>
  <g id="quarry-walls"><path d="M0 587 174 493 311 556 444 488 630 559 814 488 987 546 1167 487 1395 561 1581 477 1744 528 1920 440v640H0Z" fill="#28435C"/>
  <path d="m0 588 174-95-22 188 179 113H0Zm444-100 186 71-83 161-218 42Zm370 0 173 58-119 191-102-124Zm767-11 163 51-138 223-169-57Zm339-37v411l-195-76Z" fill="#3A5369"/>
  <path d="M0 734 211 708 383 781 541 711 745 756 913 704 1122 758 1301 713 1464 772 1611 711 1778 746 1920 698v382H0Z" fill="#172A43"/>
  </g>
  <g id="mining-floor"><path d="M0 892q778-426 1920-106v294H0Z" fill="#465E78"/><path d="m0 960 282-70 346 57 364-70 443 83 485-90v210H0Z" fill="#3A516C"/><path d="m0 1036 291-21 386 44 382-38 420 59H0Z" fill="#243C59"/>
  <ellipse cx="1368" cy="883" rx="489" ry="131" fill="#20354F"/><ellipse cx="1368" cy="876" rx="427" ry="91" fill="#193449"/><ellipse cx="1368" cy="874" rx="370" ry="54" fill="#3A7994"/>
  <path d="m0 905 126 41 219-85 173 29m955 85 180 38 204-54 63 32" fill="none" stroke="#1D3653" stroke-width="12" stroke-linejoin="round"/>
  <path d="m1593 768 30 61 84-38m-66 217 44 43m-1002-52-31 81" fill="none" stroke="#213C5A" stroke-width="9"/>
  </g>
  <g transform="translate(981 198) scale(1.48)">${meteor}</g>
  <g id="floating-chips">${shard(1046,586,.61,-31)}${shard(1725,563,.65,26)}${shard(1601,922,.66,55)}${shard(1143,968,.4,-42)}${spark(1281,380,1.4)}${spark(1599,767,.86)}${spark(1020,675,.70,'#C9BCFF')}</g>
  <ellipse cx="898" cy="1000" rx="210" ry="36" fill="#14273E" opacity=".7"/>
  <g id="miner-hero" transform="translate(657 286) scale(.88)">${miner}</g>
  <g id="refinery-loop" transform="translate(38 641) scale(.88)">${refinery}</g>
  <g id="foreground-crystal-vein">${shard(1827,1007,1.23,17)}${shard(1744,1041,.76,-24)}${shard(104,1062,.68,7)}</g>
  <g id="game-title">${outlined('CRAFTWORKS',86,104,1130,146,'url(#gold)',15,13)}${outlined('METEOR MINING',93,277,715,72,'#C7FBFF',8,6)}</g>
  </svg>`;
}
async function main() {
  for (const [name, svg] of [['crystal-rush-icon',icon()],['crystal-rush-thumbnail',thumbnail()]]) {
    fs.writeFileSync(path.join(output,name+'.svg'), svg);
    const result = await sharp(Buffer.from(svg)).png().toFile(path.join(output,name+'.png'));
    console.log(JSON.stringify({name,width:result.width,height:result.height,bytes:result.size,outlinedText:true,embeddedImages:false}));
  }
}
main().catch(e => { console.error(e); process.exitCode = 1; });

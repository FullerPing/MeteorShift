const fs = require('node:fs');
const path = require('node:path');
const opentype = require('./craterworks-opentype.cjs');
const sharp = require('C:/Users/37062/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const dir = path.resolve('assets/marketing');
const art = path.join(dir,'vector-art');
const font = opentype.loadSync(path.join(art,'fonts/FredokaOne-Regular.ttf'));
function inner(name){const svg=fs.readFileSync(path.join(art,name+'.svg'),'utf8');return svg.slice(svg.indexOf('>')+1,svg.lastIndexOf('</svg>'));}
function illustration(name,x,y,w,h,nw,nh){return `<g id="art-${name}" transform="translate(${x} ${y}) scale(${w/nw} ${h/nh})">${inner(name)}</g>`;}
function letters(chars,size,tracking=0){let x=0;const glyphs=font.stringToGlyphs(chars);return glyphs.map((g,i)=>{const d=g.getPath(x,0,size).toPathData(3);x+=g.advanceWidth/font.unitsPerEm*size+tracking;if(i<glyphs.length-1)x+=font.getKerningValue(g,glyphs[i+1])/font.unitsPerEm*size;return{char:chars[i],d};});}
function width(chars,size,tracking=0){return font.getAdvanceWidth(chars,size)+Math.max(0,chars.length-1)*tracking;}
function outlinedText(chars,size,x,top,fill,tracking=0,name='label'){
  const entries=letters(chars,size,tracking);const bbox=font.getPath(chars,0,0,size).getBoundingBox();
  return `<g id="${name}" aria-label="${chars}" transform="translate(${x} ${top-bbox.y1})">${entries.map((g,i)=>`<path id="${name}-letter-${i}" d="${g.d}" fill="${fill}"/>`).join('')}</g>`;
}
function wordmark(maxWidth,size,x,top){while(width('CRATERWORKS',size)>maxWidth)size-=0.5;const w=width('CRATERWORKS',size);const entries=letters('CRATERWORKS',size);const box=font.getPath('CRATERWORKS',0,0,size).getBoundingBox();const baseline=top-box.y1;const all=entries.map(g=>g.d).join(' ');return{width:w,size,svg:`<g id="craterworks-wordmark" aria-label="CRATERWORKS"><path id="logo-depth" d="${all}" transform="translate(${x} ${baseline+8})" fill="#FF742C" stroke="#101E25" stroke-width="11" stroke-linejoin="round" paint-order="stroke fill"/><g id="logo-face" transform="translate(${x} ${baseline})" stroke="#101E25" stroke-width="5" stroke-linejoin="round" paint-order="stroke fill">${entries.map((g,i)=>`<path id="logo-letter-${i}" d="${g.d}" fill="${i>=6?'#FFB642':'#FFF1CB'}"/>`).join('')}</g></g>`};}
function svg(w,h,title,body){return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" fill="none" role="img" aria-label="${title}"><title>${title}</title><desc>Original vector composition using editable paths and groups. No generated raster imagery or embedded bitmaps. Typography: Fredoka One, outlined for portable rendering.</desc>${body}</svg>`;}
const iconLogo=wordmark(459,54,0,445);const centeredLogo=wordmark(459,54,(512-iconLogo.width)/2,445);
const icon=svg(512,512,'Craterworks game icon',illustration('icon-background',0,0,512,512,512,512)+illustration('meteor-pickaxe',13,-8,474,474,600,600)+centeredLogo.svg);
const title=wordmark(1110,155,105,78);
const thumb=svg(1920,1080,'Craterworks Meteor Mining game thumbnail',illustration('crater-scene',0,0,1920,1080,1920,1080)+illustration('meteor',670,116,1010,1010,600,600)+illustration('refinery',1371,689,505,350,620,430)+illustration('miner-with-pickaxe',235,288,638,769,680,820)+title.svg+outlinedText('METEOR MINING',53,111,228,'#A2F2E2',6,'meteor-mining-subtitle')+outlinedText('MINE  •  REFINE  •  REBIRTH',29,111,306,'#FFF1CB',1,'game-loop'));
async function main(){
  fs.writeFileSync(path.join(dir,'craterworks-icon-vector.svg'),icon);
  fs.writeFileSync(path.join(dir,'craterworks-thumbnail-vector.svg'),thumb);
  for(const [name,source,w,h] of [['icon',icon,512,512],['thumbnail',thumb,1920,1080]]){
    const output=path.join(dir,`craterworks-${name}-vector.png`);await sharp(Buffer.from(source)).png({compressionLevel:9}).toFile(output);const m=await sharp(output).metadata();if(m.width!==w||m.height!==h)throw new Error('Wrong export dimensions');console.log(JSON.stringify({name,width:m.width,height:m.height,bytes:fs.statSync(output).size,paths:(source.match(/<path\b/g)||[]).length,images:(source.match(/<image\b/g)||[]).length}));
  }
  await sharp(path.join(dir,'craterworks-icon-vector.png')).resize(150,150).png().toFile('.tmp/craterworks-icon-small.png');
  await sharp(path.join(dir,'craterworks-thumbnail-vector.png')).resize(960,540).png().toFile('.tmp/craterworks-thumbnail-preview.png');
  console.log(JSON.stringify({iconLogo:{size:iconLogo.size,width:iconLogo.width},thumbnailLogo:{size:title.size,width:title.width}}));
}
main().catch(e=>{console.error(e);process.exitCode=1;});

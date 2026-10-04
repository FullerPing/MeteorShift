const fs = require('node:fs');
const path = require('node:path');
const art = path.resolve('assets/marketing/vector-art');
let hero = fs.readFileSync(path.join(art, 'meteor-pickaxe.svg'), 'utf8');
hero = hero.replaceAll('67-11 53 46', '67-11 40 36');
if (!hero.includes('meteor-fissures-boundary')) {
  hero = hero.replace('<g id="connected-fissures"', '<defs><clipPath id="meteor-fissures-boundary"><path d="m277 178 90-11 84 35 59 69 25 84-21 96-74 63-96 26-93-18-71-59-27-88 16-95 45-64Z"/></clipPath></defs><g clip-path="url(#meteor-fissures-boundary)" id="connected-fissures"');
}
fs.writeFileSync(path.join(art, 'meteor-pickaxe.svg'), hero);
let refinery = fs.readFileSync(path.join(art, 'refinery.svg'), 'utf8');
refinery = refinery.replace('M350 22q-21-15-4-27', 'M350 28q-15-9-4-15').replace('M380 20q24-14 6-29', 'M380 26q18-9 6-16');
fs.writeFileSync(path.join(art, 'refinery.svg'), refinery);
const pickaxe = hero.slice(hero.indexOf('<g id="pickaxe">'), hero.indexOf('<g id="meteor">'));
const meteor = hero.slice(hero.indexOf('<g id="meteor">'), hero.lastIndexOf('</svg>'));
const minerSource = fs.readFileSync(path.join(art, 'miner.svg'), 'utf8');
const miner = minerSource.slice(minerSource.indexOf('<g stroke='), minerSource.lastIndexOf('</svg>'));
const mining = `<svg xmlns="http://www.w3.org/2000/svg" width="680" height="820" viewBox="0 0 680 820" fill="none"><title>Miner holding a teal pickaxe</title><g transform="translate(219 25)">${pickaxe}</g><g transform="translate(0 200)">${miner}</g></svg>`;
const rock = `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600" fill="none"><title>Craterworks meteor</title>${meteor}</svg>`;
fs.writeFileSync(path.join(art, 'miner-with-pickaxe.svg'), mining);
fs.writeFileSync(path.join(art, 'meteor.svg'), rock);
const assets = Object.fromEntries(['icon-background','meteor-pickaxe','crater-scene','meteor','miner-with-pickaxe','refinery'].map(n=>[n,fs.readFileSync(path.join(art,n+'.svg'),'utf8')]));
const code = `
const assets = ${JSON.stringify(assets)};
const font = {family:'Fredoka One',style:'Regular'};
const secondary = {family:'Fredoka',style:'SemiBold'};
await Promise.all([figma.loadFontAsync({family:'Inter',style:'Regular'}),figma.loadFontAsync(font),figma.loadFontAsync(secondary)]);
const page = await figma.getNodeByIdAsync('0:1');
await figma.setCurrentPageAsync(page);
page.name = 'Artwork';
const created = [];
const mutated = [page.id];
const paint = hex => ({type:'SOLID',color:{r:parseInt(hex.slice(1,3),16)/255,g:parseInt(hex.slice(3,5),16)/255,b:parseInt(hex.slice(5,7),16)/255}});
function remember(node) {created.push(node.id); if('children' in node) for(const c of node.children) remember(c); return node;}
function frame(name,w,h,x,y) {const n=figma.createFrame();n.name=name;n.resize(w,h);n.x=x;n.y=y;n.clipsContent=true;n.fills=[paint('#17343C')];n.exportSettings=[{format:'PNG',constraint:{type:'SCALE',value:1},contentsOnly:true}];remember(n);return n;}
function vector(parent,key,name,x,y,w,h) {const n=figma.createNodeFromSvg(assets[key]);n.name=name;parent.appendChild(n);n.resize(w,h);n.x=x;n.y=y;remember(n);return n;}
function text(parent,chars,size,x,y,color,name,face=font) {const n=figma.createText();n.fontName=face;n.fontSize=size;n.lineHeight={unit:'PERCENT',value:100};n.letterSpacing={unit:'PIXELS',value:0};n.textAutoResize='WIDTH_AND_HEIGHT';n.characters=chars;n.name=name;n.fills=[paint(color)];parent.appendChild(n);n.x=x;n.y=y;remember(n);return n;}
function wordmark(parent,maxWidth,size,x,y) {
  const back=text(parent,'CRATERWORKS',size,x,y+8,'#FF742C','Wordmark / warm extrusion');back.strokes=[paint('#101E25')];back.strokeWeight=11;back.strokeAlign='OUTSIDE';
  while(back.width>maxWidth){size-=1;back.fontSize=size;}
  const front=text(parent,'CRATERWORKS',size,x,y,'#FFF1CB','Wordmark / editable title');front.strokes=[paint('#101E25')];front.strokeWeight=5;front.strokeAlign='OUTSIDE';front.setRangeFills(6,11,[paint('#FFB642')]);
  return {front,back,size,width:front.width};
}
const icon=frame('Icon • 512 × 512',512,512,100,100);
vector(icon,'icon-background','Background / rings and meteor streak',0,0,512,512);
vector(icon,'meteor-pickaxe','Hero / faceted meteor and pickaxe',13,-8,474,474);
const iconLogo=wordmark(icon,462,51,25,441);iconLogo.front.x=(512-iconLogo.width)/2;iconLogo.back.x=iconLogo.front.x;
const thumb=frame('Thumbnail • 1920 × 1080',1920,1080,800,100);
vector(thumb,'crater-scene','Environment / crater landscape',0,0,1920,1080);
vector(thumb,'meteor','Hero / iron meteor',670,116,1010,1010);
vector(thumb,'refinery','Plot / hopper → refinery → bars',1371,689,505,350);
vector(thumb,'miner-with-pickaxe','Hero / gold miner holding pickaxe',235,288,638,769);
const logo=wordmark(thumb,1110,143,105,75);
const subtitles=figma.createAutoLayout('VERTICAL');subtitles.name='Brand / subtitle and game loop';subtitles.fills=[];subtitles.itemSpacing=26;subtitles.counterAxisAlignItems='MIN';thumb.appendChild(subtitles);subtitles.x=111;subtitles.y=239;remember(subtitles);
const subtitle=text(subtitles,'METEOR MINING',48,0,0,'#A2F2E2','Subtitle / editable');subtitle.letterSpacing={unit:'PIXELS',value:6};
const loop=text(subtitles,'MINE  •  REFINE  •  REBIRTH',29,0,0,'#FFF1CB','Game loop / editable',secondary);loop.letterSpacing={unit:'PIXELS',value:1.5};
figma.viewport.scrollAndZoomIntoView([icon,thumb]);
return {createdNodeIds:created,mutatedNodeIds:mutated,frames:[icon,thumb].map(n=>({id:n.id,name:n.name,width:n.width,height:n.height,descendants:n.findAll(()=>true).length,vectorCount:n.findAllWithCriteria({types:['VECTOR']}).length,textCount:n.findAllWithCriteria({types:['TEXT']}).length})),wordmarks:{icon:{size:iconLogo.size,width:iconLogo.width},thumbnail:{size:logo.size,width:logo.width}},imageFills:page.findAll(n=>'fills' in n && Array.isArray(n.fills) && n.fills.some(p=>p.type==='IMAGE')).map(n=>n.id)};
`;
fs.writeFileSync('.tmp/craterworks-figma-create.js',code);
console.log(JSON.stringify({script:'.tmp/craterworks-figma-create.js',bytes:code.length,assets:Object.keys(assets)}));

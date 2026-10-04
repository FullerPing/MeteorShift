const fs = require('node:fs');
const {parse,REPLACEMENTS} = require('./patch-backpack-place.cjs');
const target = parse(fs.readFileSync('MeteorShift-backpack-foundry.rbxl'));
const expected = parse(fs.readFileSync('.tmp/backpack-source-build.rbxl'));
function sources(place) {
 const out = new Map();
 for (const source of place.sources) {
  if (source.info.name !== 'ModuleScript') continue;
  source.values.forEach((bytes,i)=>out.set(source.info.names[i].toString('utf8'),bytes.toString('utf8')));
 }
 return out;
}
const actual = sources(target), wanted = sources(expected);
const results = [];
for (const [name,file] of REPLACEMENTS) {
 const a=actual.get(name), b=wanted.get(name), disk=fs.readFileSync(file,'utf8');
 let first=0; while(first<Math.min(a.length,b.length)&&a[first]===b[first]) first++;
 results.push({name,rawEqual:a===b,diskEqual:a===disk,normalizedEqual:a.replace(/\r\n/g,'\n')===b.replace(/\r\n/g,'\n'),actualLength:a.length,buildLength:b.length,actualCRLF:(a.match(/\r\n/g)||[]).length,buildCRLF:(b.match(/\r\n/g)||[]).length,firstMismatch:first,codes:[a.charCodeAt(first),b.charCodeAt(first)]});
}
console.log(JSON.stringify(results,null,2));
if(results.some(r=>!r.diskEqual||!r.normalizedEqual)) process.exitCode=1;

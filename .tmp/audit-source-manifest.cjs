const fs=require('node:fs');
const files=fs.readFileSync('.tmp/audit-tracked-sources.txt','utf8').replace(/^\uFEFF/,'').trim().split(/\r?\n/);
const result=files.filter(f=>/\.(lua|luau)$/.test(f)).map(file=>{
  const source=fs.readFileSync(file,'utf8').replace(/\r\n/g,'\n');
  const roots={'src/server':['ServerScriptService','Server'],'src/client':['StarterPlayer','StarterPlayerScripts','Client'],'src/shared':['ReplicatedStorage','Shared'],'tests':['ServerStorage','Tests']};
  const key=Object.keys(roots).find(k=>file.startsWith(k+'/'));
  const suffix=file.slice(key.length+1).replace(/\.(?:server|client)?\.?luau?$/,'').split('/');
  if(suffix.at(-1)==='init')suffix.pop();
  let hash=5381;for(const byte of Buffer.from(source))hash=(hash*33+byte)>>>0;
  return{file,path:[...roots[key],...suffix],hash,bytes:Buffer.byteLength(source)};
});
fs.writeFileSync('.tmp/audit-source-manifest.json',JSON.stringify(result));
console.log(JSON.stringify(result));

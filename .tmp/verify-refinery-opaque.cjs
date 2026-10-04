// Read-only binary audit. Preserve and compare unknown Terrain properties too.
// Chunk framing is documented by rojo-rbx/rbx-dom/docs/binary.md.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const zlib = require('node:zlib');
const hash = data => crypto.createHash('sha256').update(data).digest('hex');
function lz4(block, size) {
  const out = Buffer.alloc(size); let p = 0, q = 0;
  while (p < block.length) {
    const token = block[p++]; let literals = token >>> 4;
    if (literals === 15) { let b; do { b = block[p++]; literals += b; } while (b === 255); }
    block.copy(out, q, p, p + literals); p += literals; q += literals;
    if (p === block.length) break;
    const offset = block.readUInt16LE(p); p += 2;
    if (offset === 0 || offset > q) throw new Error('Invalid LZ4 match');
    let count = (token & 15) + 4;
    if ((token & 15) === 15) { let b; do { b = block[p++]; count += b; } while (b === 255); }
    for (let i = 0; i < count; i++) out[q + i] = out[q + i - offset];
    q += count;
  }
  if (q !== size) throw new Error('LZ4 size mismatch');
  return out;
}
function stringAt(buf, p) {
  const n = buf.readUInt32LE(p); const end = p + 4 + n;
  if (end > buf.length) throw new Error('String overrun');
  return [buf.subarray(p + 4, end), end];
}
function ints(buf, n) {
  if (buf.length !== 4 * n) throw new Error('Interleaved integer size mismatch');
  return Array.from({length:n}, (_, i) => ((buf[i] * 2 ** 24) + (buf[i+n] << 16) + (buf[i+2*n] << 8) + buf[i+3*n]) >>> 0);
}
function read(file) {
  const bytes = fs.readFileSync(file), classes = new Map(), chunks = [], props = new Map(), shared = [];
  if (bytes.subarray(0,8).toString() !== '<roblox!') throw new Error('Invalid Roblox header');
  let p = 32;
  while (p < bytes.length) {
    const tag = bytes.subarray(p,p+4).toString('ascii').replace(/\0/g,'');
    const compressed = bytes.readUInt32LE(p+4), size = bytes.readUInt32LE(p+8);
    const block = bytes.subarray(p+16,p+16+(compressed || size)); p += 16+(compressed || size);
    const data = !compressed ? block : block.readUInt32LE(0) === 0xfd2fb528 ? zlib.zstdDecompressSync(block) : lz4(block,size);
    if (data.length !== size) throw new Error('Chunk length mismatch: '+tag);
    chunks.push({tag,data});
    if (tag === 'INST') {
      const id = data.readUInt32LE(0); const [name,pos] = stringAt(data,4);
      classes.set(id,{name:name.toString(),count:data.readUInt32LE(pos+1)});
    }
    if (tag === 'SSTR') {
      const n = data.readUInt32LE(4); let q=8;
      for(let i=0;i<n;i++) { q+=16; const [value,end]=stringAt(data,q); shared.push(value); q=end; }
      if(q!==data.length) throw new Error('Shared string chunk trailer');
    }
  }
  for(const {tag,data} of chunks) if(tag==='PROP') {
    const info = classes.get(data.readUInt32LE(0)); const [name,pos] = stringAt(data,4);
    const type=data[pos], values=data.subarray(pos+1);
    let normalized=values;
    if(type===0x1c) {
      const ids=ints(values,info.count);
      normalized=Buffer.from(JSON.stringify(ids.map(i=>hash(shared[i]))));
    }
    props.set(info.name+'.'+name.toString(),{className:info.name,name:name.toString(),count:info.count,type,bytes:normalized,hash:hash(normalized)});
  }
  return {file,sha256:hash(bytes),bytes:bytes.length,classes,props};
}
const base=read('.tmp/refinery-native-baseline.rbxl');
const target=read(process.argv[2] || 'MeteorShift-hud-redesign.rbxl');
const report={base:base.file,target:target.file,baseSha256:base.sha256,targetSha256:target.sha256,checks:[],errors:[]};
for(const [key,original] of base.props) if (/^(Terrain|UnionOperation|NegateOperation|CSGDictionaryService|NonReplicatedCSGDictionaryService)\./.test(key)) {
  const saved=target.props.get(key);
  const equal=!!saved && saved.count===original.count && saved.type===original.type && saved.bytes.equals(original.bytes);
  report.checks.push({property:key,count:original.count,type:original.type,bytes:original.bytes.length,equal,baseSha256:original.hash,targetSha256:saved?.hash});
  if(!equal) report.errors.push(key+' raw opaque data changed');
}
for(const [key] of target.props) if (/^(Terrain|UnionOperation|NegateOperation|CSGDictionaryService|NonReplicatedCSGDictionaryService)\./.test(key) && !base.props.has(key)) report.errors.push('New opaque property '+key);
report.success=report.errors.length===0;
fs.writeFileSync('.tmp/refinery-native-opaque-verification.json',JSON.stringify(report,null,2));
console.log(JSON.stringify({success:report.success,checks:report.checks.length,opaque:report.checks.filter(x=>/SmoothGrid|PhysicsGrid|VoxelGridAssetContentMap|MeshData|PhysicalData|CSGDictionaryService/.test(x.property)),errors:report.errors},null,2));
if(!report.success) process.exitCode=1;



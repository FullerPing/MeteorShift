// Source-only patcher for a native-saved Roblox place. This never serializes the DOM.
// Format: https://github.com/rojo-rbx/rbx-dom/blob/master/docs/binary.md
// Run without arguments to validate in memory; pass --write to replace the target.
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const zlib = require('node:zlib');
const { TextDecoder } = require('node:util');

const WORKSPACE = path.resolve(__dirname, '..');
const BASELINE = path.join(WORKSPACE, '.tmp', 'backpack-input-fix-baseline.rbxl');
const TARGET = path.join(WORKSPACE, 'MeteorShift-backpack-foundry.rbxl');
const REPLACEMENTS = new Map([
  ['HudView', 'src/client/HudView.luau'],
  ['HUDController', 'src/client/Controllers/HUDController.luau'],
  ['HudLayout', 'src/shared/HudLayout.luau'],
  ['HudLayout.spec', 'tests/HudLayout.spec.luau'],
  ['HudResources', 'src/shared/HudResources.luau'],
  ['HudResources.spec', 'tests/HudResources.spec.luau'],
  ['MiningController', 'src/client/Controllers/MiningController.luau'],
  ['MobileControlsController', 'src/client/Controllers/MobileControlsController.luau'],
  ['EconomyService', 'src/server/Services/EconomyService.luau'],
]);
const utf8 = new TextDecoder('utf-8', { fatal: true });
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const check = (condition, message) => { if (!condition) throw new Error(message); };

function available(buf, pos, count, context) {
  check(Number.isSafeInteger(pos) && Number.isSafeInteger(count)
    && pos >= 0 && count >= 0 && pos + count <= buf.length,
  `${context}: truncated or invalid byte range`);
}

// Same raw-block LZ4 layout used by verify-hud-opaque.cjs, with bounds checks.
function lz4(block, size) {
  const out = Buffer.alloc(size);
  let p = 0;
  let q = 0;
  function extension(context) {
    let total = 0;
    let b;
    do {
      available(block, p, 1, context);
      b = block[p++];
      total += b;
    } while (b === 255);
    return total;
  }
  while (p < block.length) {
    const token = block[p++];
    let literals = token >>> 4;
    if (literals === 15) literals += extension('LZ4 literals');
    available(block, p, literals, 'LZ4 literals');
    available(out, q, literals, 'LZ4 literal output');
    block.copy(out, q, p, p + literals);
    p += literals;
    q += literals;
    if (p === block.length) break;
    available(block, p, 2, 'LZ4 match offset');
    const offset = block.readUInt16LE(p);
    p += 2;
    check(offset > 0 && offset <= q, 'Invalid LZ4 match offset');
    let count = (token & 15) + 4;
    if ((token & 15) === 15) count += extension('LZ4 match length');
    available(out, q, count, 'LZ4 match output');
    for (let i = 0; i < count; i++) out[q + i] = out[q + i - offset];
    q += count;
  }
  check(p === block.length && q === size, 'LZ4 size mismatch');
  return out;
}

function stringAt(buf, pos, context) {
  available(buf, pos, 4, `${context} length`);
  const size = buf.readUInt32LE(pos);
  const start = pos + 4;
  available(buf, start, size, context);
  return [buf.subarray(start, start + size), start + size];
}

function stringArray(buf, pos, count, context) {
  // Every value needs a length prefix, even when empty.
  check(count <= Math.floor((buf.length - pos) / 4), `${context}: invalid string count`);
  const values = [];
  for (let i = 0; i < count; i++) {
    const [value, end] = stringAt(buf, pos, `${context}[${i}]`);
    values.push(value);
    pos = end;
  }
  check(pos === buf.length, `${context}: unexpected trailing data`);
  return values;
}

function decode(chunk) {
  if (chunk.data) return chunk.data;
  const block = chunk.raw.subarray(16);
  let data;
  if (chunk.compressed === 0) {
    data = block;
  } else if (block.length >= 4 && block.readUInt32LE(0) === 0xfd2fb528) {
    check(typeof zlib.zstdDecompressSync === 'function',
      'This Node runtime lacks zlib.zstdDecompressSync; use the bundled modern Node runtime');
    data = zlib.zstdDecompressSync(block, { maxOutputLength: chunk.size });
  } else {
    data = lz4(block, chunk.size);
  }
  check(data.length === chunk.size, `${chunk.tag}: decompressed length mismatch`);
  chunk.data = data;
  return data;
}

function parse(bytes) {
  available(bytes, 0, 32, 'RBXL header');
  check(bytes.subarray(0, 14).equals(Buffer.from([
    0x3c, 0x72, 0x6f, 0x62, 0x6c, 0x6f, 0x78, 0x21,
    0x89, 0xff, 0x0d, 0x0a, 0x1a, 0x0a,
  ])), 'Invalid Roblox binary magic/signature');
  check(bytes.readUInt16LE(14) === 0, 'Unsupported Roblox binary version');
  const classCount = bytes.readUInt32LE(16);
  const instanceCount = bytes.readUInt32LE(20);
  const chunks = [];
  let pos = 32;
  let foundEnd = false;
  while (pos < bytes.length) {
    available(bytes, pos, 16, 'Chunk header');
    const compressed = bytes.readUInt32LE(pos + 4);
    const size = bytes.readUInt32LE(pos + 8);
    const stored = compressed || size;
    available(bytes, pos + 16, stored, 'Chunk body');
    const raw = bytes.subarray(pos, pos + 16 + stored);
    const tag = raw.subarray(0, 4).toString('ascii').replace(/\0+$/, '');
    const chunk = { index: chunks.length, tag, compressed, size, raw };
    chunks.push(chunk);
    pos += raw.length;
    if (tag === 'END') {
      check(raw.subarray(0, 4).equals(Buffer.from('END\0')), 'Invalid END tag');
      check(compressed === 0 && decode(chunk).equals(Buffer.from('</roblox>')), 'Invalid END chunk');
      foundEnd = true;
      break;
    }
  }
  check(foundEnd, 'Missing END chunk');
  const header = bytes.subarray(0, 32);
  const trailing = bytes.subarray(pos);
  const classes = new Map();
  const classNames = new Set();
  let parsedInstances = 0;
  for (const chunk of chunks) {
    if (chunk.tag !== 'INST') continue;
    const data = decode(chunk);
    available(data, 0, 4, 'INST class ID');
    const id = data.readUInt32LE(0);
    const [nameBytes, nameEnd] = stringAt(data, 4, 'INST class name');
    const name = utf8.decode(nameBytes);
    available(data, nameEnd, 5, `INST ${name} format/count`);
    const format = data[nameEnd];
    const count = data.readUInt32LE(nameEnd + 1);
    check(format === 0 || format === 1, `INST ${name}: unsupported object format`);
    const expectedEnd = nameEnd + 5 + 4 * count + (format === 1 ? count : 0);
    check(expectedEnd === data.length, `INST ${name}: instance count or exact end mismatch`);
    check(!classes.has(id), `Duplicate INST class ID ${id}`);
    check(!classNames.has(name), `Duplicate INST class name ${name}`);
    classes.set(id, { id, name, count, format, names: null, source: null });
    classNames.add(name);
    parsedInstances += count;
  }
  check(classes.size === classCount, 'Header class count differs from INST chunks');
  check(parsedInstances === instanceCount, 'Header instance count differs from INST chunks');
  const propertyKeys = new Set();
  const sources = [];
  for (const chunk of chunks) {
    if (chunk.tag !== 'PROP') continue;
    const data = decode(chunk);
    available(data, 0, 4, 'PROP class ID');
    const classId = data.readUInt32LE(0);
    const info = classes.get(classId);
    check(info, `PROP refers to absent class ID ${classId}`);
    const [nameBytes, nameEnd] = stringAt(data, 4, 'PROP name');
    const name = utf8.decode(nameBytes);
    available(data, nameEnd, 1, `PROP ${info.name}.${name} type`);
    const type = data[nameEnd];
    const valuesStart = nameEnd + 1;
    const key = `${classId}:${name}`;
    check(!propertyKeys.has(key), `Duplicate PROP ${info.name}.${name}`);
    propertyKeys.add(key);
    chunk.property = { classId, name, type, valuesStart };
    if (name === 'Name' || name === 'Source') {
      check(type === 1, `PROP ${info.name}.${name}: expected datatype 0x01`);
      const values = stringArray(data, valuesStart, info.count, `${info.name}.${name}`);
      if (name === 'Name') {
        info.names = values;
      } else {
        const source = { chunk, info, values, valuesStart };
        info.source = source;
        sources.push(source);
      }
    }
  }
  for (const source of sources) {
    check(source.info.names, `${source.info.name}.Source is missing its Name property`);
  }
  return { bytes, header, chunks, trailing, classes, sources };
}

function loadReplacements() {
  return new Map(Array.from(REPLACEMENTS, ([name, relative]) => {
    const file = path.join(WORKSPACE, relative);
    const bytes = fs.readFileSync(file);
    utf8.decode(bytes); // Reject malformed UTF-8 rather than silently replacing bytes.
    return [name, { name, relative, file, bytes }];
  }));
}

function locateTargets(place, replacements) {
  const matches = new Map(Array.from(replacements.keys(), name => [name, []]));
  for (const info of place.classes.values()) {
    if (info.name !== 'ModuleScript') continue;
    check(info.names, 'ModuleScript is missing its Name property');
    for (let index = 0; index < info.count; index++) {
      const name = utf8.decode(info.names[index]);
      if (matches.has(name)) matches.get(name).push({ info, index });
    }
  }
  const targets = new Map();
  for (const [name, occurrences] of matches) {
    check(occurrences.length === 1,
      `Expected exactly one ModuleScript named ${name}; found ${occurrences.length}`);
    const { info, index } = occurrences[0];
    check(info.source, `ModuleScript ${name} has no Source PROP`);
    targets.set(`${info.id}:${index}`, { ...replacements.get(name), info, index });
  }
  check(targets.size === replacements.size, 'Replacement target count mismatch');
  return targets;
}

function framedString(value) {
  check(value.length <= 0xffffffff, 'Source exceeds the string length limit');
  const length = Buffer.alloc(4);
  length.writeUInt32LE(value.length);
  return [length, value];
}

function build(base, replacements) {
  const targets = locateTargets(base, replacements);
  const modified = new Map();
  const applied = new Map(Array.from(replacements.keys(), name => [name, 0]));
  for (const source of base.sources) {
    let changed = false;
    const values = source.values.map((original, index) => {
      const replacement = targets.get(`${source.info.id}:${index}`);
      if (!replacement) return original;
      applied.set(replacement.name, applied.get(replacement.name) + 1);
      changed ||= !original.equals(replacement.bytes);
      return replacement.bytes;
    });
    if (!changed) continue;
    const prefix = decode(source.chunk).subarray(0, source.valuesStart);
    const body = Buffer.concat([prefix, ...values.flatMap(framedString)]);
    check(body.length <= 0xffffffff, 'Source PROP exceeds the chunk length limit');
    const header = Buffer.from(source.chunk.raw.subarray(0, 16));
    header.writeUInt32LE(0, 4); // Uncompressed payload; tag and reserved bytes stay exact.
    header.writeUInt32LE(body.length, 8);
    modified.set(source.chunk.index, Buffer.concat([header, body]));
  }
  for (const [name, count] of applied) check(count === 1, `${name}: applied ${count} times`);
  const bytes = Buffer.concat([
    base.header,
    ...base.chunks.map(chunk => modified.get(chunk.index) || chunk.raw),
    base.trailing,
  ]);
  const rebuilt = parse(bytes);
  const verification = verify(base, rebuilt, replacements, modified);
  return { bytes, modified, verification };
}

function verify(base, rebuilt, replacements, modified) {
  check(base.header.equals(rebuilt.header), 'RBXL header changed');
  check(base.trailing.equals(rebuilt.trailing), 'Trailing bytes changed');
  check(base.chunks.length === rebuilt.chunks.length, 'Chunk count changed');
  let rawPreserved = 0;
  for (let i = 0; i < base.chunks.length; i++) {
    const original = base.chunks[i];
    const output = rebuilt.chunks[i];
    if (!modified.has(i)) {
      check(original.raw.equals(output.raw), `Chunk ${i} (${original.tag}) changed unexpectedly`);
      rawPreserved++;
      continue;
    }
    check(original.tag === 'PROP' && original.property?.name === 'Source',
      `Attempted modification outside Source PROP at chunk ${i}`);
    check(output.tag === 'PROP' && output.property?.name === 'Source' && output.compressed === 0,
      `Modified chunk ${i} is not an uncompressed Source PROP`);
    check(original.raw.subarray(0, 4).equals(output.raw.subarray(0, 4))
      && original.raw.subarray(12, 16).equals(output.raw.subarray(12, 16)),
    `Source chunk ${i} tag/reserved bytes changed`);
    const prefixSize = original.property.valuesStart;
    check(decode(original).subarray(0, prefixSize).equals(decode(output).subarray(0, prefixSize)),
      `Source chunk ${i} property identity changed`);
    check(modified.get(i).equals(output.raw), `Source chunk ${i} differs from assembled bytes`);
  }
  const oldTargets = locateTargets(base, replacements);
  const newTargets = locateTargets(rebuilt, replacements);
  check(base.sources.length === rebuilt.sources.length, 'Source PROP count changed');
  const applied = new Map(Array.from(replacements.keys(), name => [name, 0]));
  let untouchedSources = 0;
  const replaced = [];
  for (const oldSource of base.sources) {
    const newInfo = rebuilt.classes.get(oldSource.info.id);
    check(newInfo?.source && newInfo.name === oldSource.info.name
      && newInfo.count === oldSource.info.count, 'Source class/count changed');
    const newSource = newInfo.source;
    check(newSource.chunk.index === oldSource.chunk.index, 'Source chunk ordering changed');
    for (let index = 0; index < oldSource.values.length; index++) {
      const key = `${oldSource.info.id}:${index}`;
      const replacement = oldTargets.get(key);
      const after = newSource.values[index];
      if (!replacement) {
        check(oldSource.values[index].equals(after),
          `Untargeted Source changed: ${oldSource.info.name}[${index}]`);
        untouchedSources++;
      } else {
        check(newTargets.get(key)?.name === replacement.name, `Replacement identity moved: ${replacement.name}`);
        check(after.equals(replacement.bytes), `Rebuilt Source does not match disk: ${replacement.name}`);
        applied.set(replacement.name, applied.get(replacement.name) + 1);
        replaced.push({
          name: replacement.name,
          file: replacement.relative,
          classId: oldSource.info.id,
          classIndex: index,
          bytes: after.length,
          changed: !oldSource.values[index].equals(after),
          beforeSha256: hash(oldSource.values[index]),
          afterSha256: hash(after),
        });
      }
    }
  }
  for (const [name, count] of applied) check(count === 1, `${name}: verified ${count} times`);
  return { rawPreservedChunks: rawPreserved, modifiedSourceChunks: modified.size, untouchedSources, replaced };
}

function checkInputsStillMatch(baseBytes, replacements, previousTarget) {
  check(fs.readFileSync(BASELINE).equals(baseBytes), 'Native baseline changed during preparation');
  for (const replacement of replacements.values()) {
    check(fs.readFileSync(replacement.file).equals(replacement.bytes),
      `Source file changed during preparation: ${replacement.relative}`);
  }
  if (previousTarget === null) {
    check(!fs.existsSync(TARGET), 'Target appeared during preparation');
  } else {
    check(fs.readFileSync(TARGET).equals(previousTarget), 'Target changed during preparation');
  }
}

function main() {
  const args = process.argv.slice(2);
  check(args.length === 0 || (args.length === 1 && args[0] === '--write'),
    'Usage: node .tmp/patch-backpack-place.cjs [--write]');
  const write = args[0] === '--write';
  check(BASELINE !== TARGET, 'Baseline and target must be distinct');
  const baseBytes = fs.readFileSync(BASELINE);
  const previousTarget = fs.existsSync(TARGET) ? fs.readFileSync(TARGET) : null;
  const base = parse(baseBytes);
  const replacements = loadReplacements();
  const result = build(base, replacements);
  let diskVerification = null;
  if (write) {
    const temp = path.join(path.dirname(TARGET),
      `.${path.basename(TARGET)}.source-patch-${process.pid}-${crypto.randomBytes(8).toString('hex')}.tmp`);
    let created = false;
    try {
      const fd = fs.openSync(temp, 'wx', 0o600);
      created = true;
      try {
        fs.writeFileSync(fd, result.bytes);
        fs.fsyncSync(fd);
      } finally {
        fs.closeSync(fd);
      }
      const readback = fs.readFileSync(temp);
      check(readback.equals(result.bytes), 'Temporary file readback differs from assembled bytes');
      // Reparse the on-disk temporary place and compare every Source before rename.
      diskVerification = verify(base, parse(readback), replacements, result.modified);
      checkInputsStillMatch(baseBytes, replacements, previousTarget);
      fs.renameSync(temp, TARGET);
      created = false;
      check(fs.readFileSync(TARGET).equals(result.bytes), 'Final file readback differs from validated bytes');
    } finally {
      if (created) fs.unlinkSync(temp);
    }
  } else {
    checkInputsStillMatch(baseBytes, replacements, previousTarget);
  }
  console.log(JSON.stringify({
    success: true,
    mode: write ? 'written' : 'dry-run',
    baseline: BASELINE,
    target: TARGET,
    baselineBytes: baseBytes.length,
    targetBytes: result.bytes.length,
    baselineSha256: hash(baseBytes),
    targetSha256: hash(result.bytes),
    classCount: base.classes.size,
    instanceCount: baseBytes.readUInt32LE(20),
    headerPreserved: true,
    trailingBytesPreserved: base.trailing.length,
    ...result.verification,
    diskValidatedBeforeRename: !!diskVerification,
  }, null, 2));
}

module.exports = { lz4, stringAt, stringArray, parse, build, verify, REPLACEMENTS };
if (require.main === module) {
  try { main(); } catch (error) {
    console.error(`Source-only RBXL patch aborted: ${error.message}`);
    process.exitCode = 1;
  }
}

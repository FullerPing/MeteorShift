// Export the properties captured from Studio's editable ScreenGui hierarchy.
const fs = require('node:fs/promises');
const path = require('node:path');
const escape = value => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const integers = new Set(['DisplayOrder', 'BorderSizePixel', 'ZIndex', 'LayoutOrder', 'ScrollBarThickness', 'FillDirectionMaxCells', 'MinTextSize', 'MaxTextSize']);
const content = new Set(['Image']);
function property(name, data) {
  const { t, v } = data;
  const tag = (kind, body) => `<${kind} name="${escape(name)}">${body}</${kind}>`;
  const components = (names, values) => names.map((key, index) => `<${key}>${values[index]}</${key}>`).join('');
  if (t === 'boolean') return tag('bool', String(v));
  if (t === 'number') return tag(integers.has(name) ? 'int' : 'float', v);
  if (t === 'string') return content.has(name) ? tag('Content', v ? `<url>${escape(v)}</url>` : '<null></null>') : tag('string', escape(v));
  if (t === 'EnumItem') return tag('token', v);
  if (t === 'Instance') return tag('Ref', escape(v));
  if (t === 'UDim2') return tag('UDim2', components(['XS', 'XO', 'YS', 'YO'], v));
  if (t === 'UDim') return tag('UDim', components(['S', 'O'], v));
  if (t === 'Color3') return tag('Color3', components(['R', 'G', 'B'], v));
  if (t === 'Vector2') return tag('Vector2', components(['X', 'Y'], v));
  if (t === 'Vector3') return tag('Vector3', components(['X', 'Y', 'Z'], v));
  if (t === 'CFrame') return tag('CoordinateFrame', components(['X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22'], v));
  if (t === 'Font') return tag('Font', `<Family><url>${escape(v[0])}</url></Family><Weight>${v[1]}</Weight><Style>${escape(v[2])}</Style>`);
  if (t === 'ColorSequence' || t === 'NumberSequence') return tag(t, v.map(point => point.join(' ')).join(' ') + ' ');
  throw new Error(`Unsupported ${name}: ${t}`);
}
function item(node) {
  const props = Object.entries(node.props).sort(([a], [b]) => a.localeCompare(b)).map(([name, value]) => property(name, value)).join('');
  return `<Item class="${escape(node.class)}" referent="${node.id}"><Properties>${props}</Properties>${node.children.map(item).join('')}</Item>`;
}
async function exportSchema(roots, directory) {
  await fs.mkdir(directory, { recursive: true });
  const results = [];
  for (const root of roots) {
    const xml = `<?xml version="1.0" encoding="utf-8"?><roblox version="4"><External>null</External><External>nil</External>${item(root)}</roblox>\n`;
    const target = path.join(directory, `${root.name}.rbxmx`);
    await fs.writeFile(target, xml, 'utf8');
    results.push({ name: root.name, bytes: Buffer.byteLength(xml) });
  }
  return results;
}
module.exports = { exportSchema };
if (require.main === module) {
  const [source, directory] = process.argv.slice(2);
  if (!source || !directory) throw new Error('Usage: node tools/export-native-ui.cjs schema.json assets/native-ui');
  fs.readFile(source, 'utf8').then(JSON.parse).then(roots => exportSchema(roots, directory)).then(console.log);
}

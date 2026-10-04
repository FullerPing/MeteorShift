const fs = require('node:fs');
const path = require('node:path');
const sharp = require('C:/Users/37062/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const dir = path.resolve(__dirname, '../assets/marketing/craftworks');
async function main() {
  for (const [slug, title, color] of [['molten-impact', 'Molten Impact', '#FFD176'], ['crystal-rush', 'Crystal Rush', '#A9F4FF']]) {
    const header = Buffer.from(`<svg width="1400" height="572" xmlns="http://www.w3.org/2000/svg"><rect width="1400" height="572" fill="#0A1628"/><text x="28" y="52" font-family="Arial,sans-serif" font-weight="700" font-size="28" fill="${color}">${title}</text><text x="28" y="83" font-family="Arial,sans-serif" font-size="16" fill="#BBCADA">Craftworks: Meteor Mining</text><text x="28" y="552" font-family="Arial,sans-serif" font-size="15" fill="#BBCADA">512 × 512 icon • 1920 × 1080 thumbnail</text></svg>`);
    const icon = await sharp(path.join(dir, `${slug}-icon.png`)).resize(384, 384).toBuffer();
    const thumbnail = await sharp(path.join(dir, `${slug}-thumbnail.png`)).resize(960, 540).toBuffer();
    await sharp(header).composite([{input:icon,left:24,top:128},{input:thumbnail,left:424,top:16}]).png({compressionLevel:9}).toFile(path.join(dir, `${slug}-set-preview.png`));
    for (const [kind, width, height] of [['icon', 512, 512], ['thumbnail', 1920, 1080]]) {
      const file = path.join(dir, `${slug}-${kind}.png`);
      const meta = await sharp(file).metadata();
      const svg = fs.readFileSync(path.join(dir, `${slug}-${kind}.svg`), 'utf8');
      if (meta.width !== width || meta.height !== height) throw new Error(`${slug} ${kind}: unexpected dimensions`);
      if (/<image\b/i.test(svg)) throw new Error(`${slug} ${kind}: expected vector paths`);
      if (/CRATERWORKS/i.test(svg)) throw new Error(`${slug} ${kind}: old game name remains`);
      console.log(JSON.stringify({file:path.basename(file),width:meta.width,height:meta.height,bytes:fs.statSync(file).size,editableSVG:true}));
    }
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });

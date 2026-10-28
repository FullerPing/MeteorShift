"""Package and visually compare the supplied pet references with local exports."""
from pathlib import Path
import json, shutil, zipfile, html, sys
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(sys.argv[1]) if len(sys.argv)>1 else Path('Z:/final-final-actual-final/MeteorShift/blender/pets/reference-set')
manifest=json.loads((ROOT/'manifest.json').read_text())
validation=json.loads((ROOT/'validation.json').read_text())
CEILING=manifest[0]['budget']
REPLICA=manifest[0]['metadata'].get('Revision')==2
assert len(manifest)==len(validation)==18
assert all(r['passed'] and r['triangles']<=CEILING for r in validation)
assert all(r['budget']==CEILING for r in manifest)
(ROOT/'references').mkdir(exist_ok=True)
base=[r for r in manifest if not r['metadata']['Level10']]
for r in base:
 name=r['metadata']['Reference']
 shutil.copy2(Path('C:/Users/37062/Downloads')/name,ROOT/'references'/name)

def thumbnail(path,size=(330,330)):
 im=Image.open(path).convert('RGBA');im.thumbnail(size,Image.Resampling.LANCZOS)
 out=Image.new('RGBA',size,(245,246,248,255))
 out.alpha_composite(im,((size[0]-im.width)//2,(size[1]-im.height)//2))
 return out.convert('RGB')

fontpath='C:/Windows/Fonts/segoeui.ttf'
font=ImageFont.truetype(fontpath,21)
small=ImageFont.truetype(fontpath,17)
sheet=Image.new('RGB',(990,9*375+55),'#f5f6f8');draw=ImageDraw.Draw(sheet)
for i,label in enumerate(['Supplied reference','Base model','Level 10 model']):draw.text((i*330+14,12),label,font=font,fill='#192735')
rows=[]
for i,r in enumerate(base):
 stem=Path(r['id']).name;y=55+i*375
 files=[ROOT/'references'/r['metadata']['Reference'],ROOT/(r['id']+'.png'),ROOT/(r['id']+'_lv10.png')]
 for col,file in enumerate(files):sheet.paste(thumbnail(file),(col*330,y))
 draw.text((14,y+335),stem,font=font,fill='#192735')
 draw.text((344,y+337),str(r['triangles'])+' triangles',font=small,fill='#536272')
 lv=next(x for x in manifest if x['id']==r['id']+'_lv10')
 draw.text((674,y+337),str(lv['triangles'])+' triangles',font=small,fill='#536272')
 rows.append((stem,r,lv))
sheet.save(ROOT/'reference-comparison.jpg',quality=92)

overview=Image.new('RGB',(1050,1110),'#f5f6f8');d=ImageDraw.Draw(overview)
for i,r in enumerate(base):
 im=thumbnail(ROOT/(r['id']+'.png'),(350,350))
 overview.paste(im,((i%3)*350,(i//3)*370))
 d.text(((i%3)*350+12,(i//3)*370+344),Path(r['id']).name,font=small,fill='#192735')
overview.save(ROOT/'review.png')

cards=[]
for stem,r,lv in rows:
 cards.append('<article><h2>'+stem+'</h2><div class="views">'+
  '<figure><img src="references/'+html.escape(r['metadata']['Reference'])+'"><figcaption>Reference</figcaption></figure>'+
  '<figure><img src="models/'+stem+'.png"><figcaption>Base · '+str(r['triangles'])+' triangles</figcaption></figure>'+
  '<figure><img src="models/'+stem+'_lv10.png"><figcaption>Level 10 · '+str(lv['triangles'])+' triangles</figcaption></figure></div>'+
  '<p><a href="models/'+stem+'.fbx">Base FBX</a> · <a href="models/'+stem+'_lv10.fbx">Level 10 FBX</a> · '+
  '<a href="models/'+stem+'.blend">Editable Blender source</a></p></article>')
(ROOT/'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Reference pet exports</title><style>body{font:16px system-ui;background:#f5f6f8;color:#192735;margin:40px auto;max-width:1100px;padding:0 20px}h1{font-size:32px}article{padding:24px 0;border-top:1px solid #cbd3dc}.views{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}figure{margin:0}img{width:100%;height:auto}figcaption{padding:12px 0;color:#536272}a{color:#2456a6}@media(max-width:600px){.views{grid-template-columns:1fr}}</style><h1>Reference pet exports</h1><p>Nine pets · Base and level 10 · '''+f'{CEILING:,}'+'''-triangle maximum per model</p><p>Use the reference images to compare silhouettes, colors and details. These are authored reconstructions from single views.</p>'''+''.join(cards)+'</html>',encoding='utf-8')

lines=['# Reference pet exports','',
 'Nine unique supplied references, each with a base and level-10 look: 18 local models.',
 'The pictures define the visual designs. The pasted briefs supply export conventions.',
 'Repeated clipboard images of Cargo Mole are treated as one reference.','',
 '## Files','',
 '- `models/`: individual FBX, editable Blend, transparent 512 × 512 PNG, and JSON metadata.',
 '- `previews/`: the requested separately organized PNG previews.',
 '- `palette.png`: shared 256 × 256 flat-color texture; retain the directory layout.',
 '- `references/`: copies of the nine supplied images.',
 '- `index.html`: local reference/base/level-10 comparison and individual download links.',
 '- `review.png` and `reference-comparison.jpg`: rendered overview and visual comparison.',
 '- `manifest.json` and `validation.json`: model details and actual FBX re-import results.','',
 '## Export conventions','',
 '- One Blender unit per stud; Blender Z up, front toward −Y. FBX export uses −Z forward / Y up.',
 '- All models have a named empty root and a `Body` mesh. Mesh scales are applied.',
 '- Ground roots sit at the lowest contact plane; floating roots use the body-center coordinate frame.',
 '- Articulated meshes have joint origins and `AnimationGroup` / `AnimationPivot` custom properties.',
 '- Tintable Body exports are neutral white without a color texture. JSON `PetColor` gives the reference fallback color.',
 '- Fixed colors use palette UV swatches. Neon surfaces are separate untextured meshes.',
 '- Both looks replicate the same reference design, with no added ornaments.' if REPLICA else '- Base looks follow the references. Level 10 preserves the design and adds small signature accents.',
 f'- {CEILING:,} triangles is the per-model ceiling; counts include every mesh object in that FBX.','',
 '## Roblox import','',
 'Import each FBX separately with hierarchy retained. Verify scale against its JSON dimensions.',
 'Set Body as PrimaryPart, use the reference PetColor from JSON, and apply Neon to flagged meshes.',
 'Restore mesh names and animation properties from JSON/custom properties; do not assume Studio converts them automatically.',
 'The original game PetColor values differ from several references and would recolor these bodies if reused unchanged.',
 'Preview PNGs show the intended colors; tintable source/export bodies remain white as required.',
 'No Studio templates or gameplay code have been changed.','',
 '## Verification','',
 'All 18 FBX files were actually re-imported in Blender. Checks cover mesh counts, triangle counts,',
 'dimensions, applied scale, Body, joint metadata, palette UVs, neutral untextured tint,',
 'untextured Neon, and transparent 512 × 512 PNG exports.',
 'Backs and hidden surfaces are reconstructed because each reference supplies one view.','',
 '| Pet | Base triangles | Level 10 triangles |',
 '| --- | ---: | ---: |']
for stem,r,lv in rows:lines.append(f'| {stem} | {r["triangles"]} | {lv["triangles"]} |')
(ROOT/'README.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
zip_path=ROOT.parent/('reference-pets-v2.zip' if REPLICA else 'reference-pets.zip')
with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED) as archive:
 for f in ROOT.rglob('*'):
  if f.is_file():archive.write(f,Path('reference-pets')/f.relative_to(ROOT))
with zipfile.ZipFile(zip_path) as archive:
 assert archive.testzip() is None
 assert len([n for n in archive.namelist() if n.endswith('.fbx')])==18
print(json.dumps({'models':18,'max_triangles':max(r['triangles'] for r in manifest),'ceiling':CEILING,'archive':str(zip_path),'bytes':zip_path.stat().st_size,'validated':True}))

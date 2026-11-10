"""Build the local asset review catalog from completed delivery reports."""
import json, html
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]/'blender'
data=json.loads((ROOT/'manifest.json').read_text())
cards=[]
for ident,r in sorted(data.items()):
    category='minerals' if ident.startswith('meteor/minerals/') else ident.split('/')[0]
    optional=bool(r.get('metadata',{}).get('Optional'))
    cards.append(f'<article data-category="{category}" data-optional="{str(optional).lower()}"><img loading="lazy" src="{ident}.png" alt="{html.escape(ident)}"><h2>{ident.split("/")[-1]}</h2><p>{"Optional · " if optional else ""}{r["triangles"]:,} / {r["budget"]:,} triangles · {len(r["objects"])} mesh objects</p><footer><a href="{ident}.blend">Blend</a><a href="{ident}.fbx">FBX</a><a href="{ident}.png">PNG</a><a href="{ident}.json">Import metadata</a></footer></article>')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Craterworks · Complete asset library</title>
<style>*{box-sizing:border-box}body{margin:0;background:#101722;color:#e8edf6;font:15px system-ui}header,nav,main{max-width:1440px;margin:auto;padding:24px}header{padding-top:48px}h1{font-size:38px;margin:8px 0}header p{color:#adbbce;max-width:900px;line-height:1.6}.eyebrow{color:#ffc95c;letter-spacing:.15em;font-size:12px}nav{display:flex;flex-wrap:wrap;gap:8px;padding-top:0}button{font:inherit;padding:8px 15px;border:1px solid #40516a;background:#1b283a;color:#eff5ff;border-radius:6px;cursor:pointer}button[aria-pressed=true]{background:#ffc95c;color:#151f2c}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:18px;padding-top:0}article{background:#172233;border:1px solid #293a50;border-radius:10px;overflow:hidden}article img{width:100%;aspect-ratio:1;object-fit:contain}h2{font-size:17px;margin:0 16px 8px}article p{color:#adbbce;font-size:12px;margin:8px 16px}footer{display:flex;flex-wrap:wrap;gap:14px;padding:12px 16px 18px;font-size:12px}a{color:#89c9ff}article[hidden]{display:none}</style>
<header><div class="eyebrow">CRATERWORKS / METEOR MINING</div><h1>Complete asset library</h1><p>115 original low-poly assets: 79 required assets plus 12 minerals, 11 optional landmarks and 13 repeated props. Each includes an editable Blend file, triangulated FBX, transparent 512px preview, and import metadata. Tintable meshes are neutral in source/export files and colored for these previews. Roblox Studio import and game hookup remain a separate step.</p><p><a href="README.md">Import notes</a> · <a href="validation.json">Validation report</a> · <a href="palette.png">Shared palette</a></p></header><nav>'''
for category in ['all','optional','meteor','minerals','equipment','pets','eggs','rocks','items','map','props']:
    page+=f'<button data-filter="{category}" aria-pressed="{str(category=="all").lower()}">{category.title()}</button>'
page+='</nav><main>'+''.join(cards)+'''</main><script>document.querySelectorAll('[data-filter]').forEach(b=>b.onclick=()=>{document.querySelectorAll('[data-filter]').forEach(x=>x.setAttribute('aria-pressed',x===b));document.querySelectorAll('article').forEach(x=>x.hidden=b.dataset.filter==='optional'?x.dataset.optional!=='true':b.dataset.filter!=='all'&&x.dataset.category!==b.dataset.filter)});if(location.hash==='#optional')document.querySelector('[data-filter="optional"]').click()</script></html>'''
(ROOT/'index.html').write_text(page,encoding='utf-8')
print(f'Catalog: {len(data)} assets')

"""Review sheets for the store art. Not upload files.
python tools/store-art/smalltest.py  ->  assets/marketing/v2/preview/{five-up.png, small-sizes.png, contact-sheet.png}"""
import os, json
from PIL import Image, ImageDraw
root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
v2 = os.path.join(root, 'assets', 'marketing', 'v2')
names = ['thumb-1-meteor-impact', 'thumb-2-pickaxe-power', 'thumb-3-hatch-legendary', 'thumb-4-rebirth', 'thumb-5-boss-meteor']
imgs = [Image.open(os.path.join(v2, n + '.png')).convert('RGB') for n in names]
icon = Image.open(os.path.join(v2, 'icon-512.png')).convert('RGB')
out = os.path.join(v2, 'preview'); os.makedirs(out, exist_ok=True)

# 5-up grid on dark navy, like the reference screenshot (tiles about 280 px wide)
tw, th, gap = 384, 216, 18
sheet = Image.new('RGB', (tw * 3 + gap * 4, th * 2 + gap * 3 + 150), '#0E1834')
for i, im in enumerate(imgs):
    t = im.resize((tw, th), Image.LANCZOS)
    x, y = gap + (i % 3) * (tw + gap), gap + (i // 3) * (th + gap)
    sheet.paste(t, (x, y))
ix = gap + 2 * (tw + gap) + 0
sheet.paste(icon.resize((150, 150), Image.LANCZOS), (gap + 1 * (tw + gap), gap + th + gap + 10 + 0)) if False else None
sheet.paste(icon.resize((200, 200), Image.LANCZOS), (gap + (tw + gap) * 2 + 80, gap + th + gap + 8))
sheet.save(os.path.join(out, 'five-up.png'))

# small sizes: 256x144 thumbnails and icon at 150 / 96 / 64
small = Image.new('RGB', (256 * 5 + gap * 6, 144 + 150 + gap * 3), '#0E1834')
for i, im in enumerate(imgs):
    small.paste(im.resize((256, 144), Image.LANCZOS), (gap + i * (256 + gap), gap))
x = gap
for s in (150, 96, 64):
    small.paste(icon.resize((s, s), Image.LANCZOS), (x, 144 + gap * 2)); x += s + gap
small.save(os.path.join(out, 'small-sizes.png'))

# checks
res = {}
for n, im in zip(names, imgs):
    p = os.path.join(v2, n + '.png'); res[n] = {'size': im.size, 'bytes': os.path.getsize(p), 'under5MB': os.path.getsize(p) < 5e6}
res['icon-512'] = {'size': icon.size, 'bytes': os.path.getsize(os.path.join(v2, 'icon-512.png'))}
json.dump(res, open(os.path.join(out, 'delivery-checks.json'), 'w'), indent=2)
print(json.dumps(res, indent=1))

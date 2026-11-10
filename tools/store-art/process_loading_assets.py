"""Turn the owner's generated loading-screen images into game-ready PNGs.

  python tools/store-art/process_loading_assets.py <downloads folder>

Reads the four JPGs (names start with Fiery_meteor_streak, Cartoon_cloud, Craterworks_logo, Roblox_game_loading),
keeps the originals in assets/marketing/v2/loading/source/, and writes:
  loading/trail.png     black background -> alpha from brightness, cropped
  loading/cloud.png     white background removed by flood fill from the edges, cropped
  loading/wordmark.png  white background and soft shadow removed, cropped
  loading/loading-bg.png the diorama, unchanged (PNG)
"""
import os, sys, shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
dst = os.path.join(root, 'assets', 'marketing', 'v2', 'loading')
src_dir = os.path.join(dst, 'source')
arch = os.path.join(dst, 'archive-code')
os.makedirs(src_dir, exist_ok=True)
os.makedirs(arch, exist_ok=True)
down = sys.argv[1]

def find(prefix):
    for n in sorted(os.listdir(down)):
        if n.startswith(prefix) and n.lower().endswith(('.jpg', '.jpeg', '.png')):
            return os.path.join(down, n)
    raise SystemExit('missing ' + prefix)

files = {k: find(p) for k, p in {'trail': 'Fiery_meteor_streak', 'cloud': 'Cartoon_cloud', 'logo': 'Craterworks_logo', 'bg': 'Roblox_game_loading'}.items()}
for k, p in files.items():
    shutil.copy2(p, os.path.join(src_dir, k + os.path.splitext(p)[1].lower()))
for n in ('trail.png', 'cloud.png', 'wordmark.png', 'loading-bg.png'):  # keep the code-drawn versions
    p = os.path.join(dst, n)
    if os.path.exists(p) and not os.path.exists(os.path.join(arch, n)):
        shutil.copy2(p, os.path.join(arch, n))

def crop_alpha(img, pad=6):
    a = np.array(img.split()[3])
    ys, xs = np.where(a > 8)
    box = (max(0, xs.min() - pad), max(0, ys.min() - pad), min(img.width, xs.max() + pad + 1), min(img.height, ys.max() + pad + 1))
    return img.crop(box)

def flood_background(rgb, bg_like):
    """Mask of background-like pixels connected to the image border (4-neighbour BFS)."""
    from collections import deque
    h, w = bg_like.shape
    seen = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if bg_like[y, x] and not seen[y, x]:
                seen[y, x] = True; q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if bg_like[y, x] and not seen[y, x]:
                seen[y, x] = True; q.append((y, x))
    while q:
        y, x = q.popleft()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and bg_like[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True; q.append((ny, nx))
    return seen

def cut_white(path, name, light=200, spread=40, out_w=None):
    im = Image.open(path).convert('RGB')
    a = np.array(im).astype(int)
    mn, mx = a.min(2), a.max(2)
    bg_like = (mn >= light) & ((mx - mn) <= spread)
    bg = flood_background(a, bg_like)
    alpha = np.where(bg, 0, 255).astype('uint8')
    amask = Image.fromarray(alpha, 'L').filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    out = im.convert('RGBA')
    out.putalpha(amask)
    out = crop_alpha(out)
    if out_w and out.width > out_w:
        out = out.resize((out_w, round(out.height * out_w / out.width)), Image.LANCZOS)
    out.save(os.path.join(dst, name), optimize=True)
    return out.size

def cut_black(path, name):
    im = Image.open(path).convert('RGB')
    a = np.array(im).astype(float)
    m = a.max(2)
    alpha = np.clip((m - 8) / (255 - 8) * 1.25, 0, 1)
    col = np.where(alpha[..., None] > 0.004, a / np.maximum(alpha[..., None], 0.004), 0)
    col = np.clip(col, 0, 255).astype('uint8')
    out = Image.fromarray(np.dstack([col, (alpha * 255).astype('uint8')]), 'RGBA')
    out = crop_alpha(out, 10)
    out.save(os.path.join(dst, name), optimize=True)
    return out.size

print('trail', cut_black(files['trail'], 'trail.png'))
print('cloud', cut_white(files['cloud'], 'cloud.png', light=235, spread=22))
print('wordmark', cut_white(files['logo'], 'wordmark.png', light=200, spread=40, out_w=2048))
Image.open(files['bg']).convert('RGB').save(os.path.join(dst, 'loading-bg.png'), optimize=True)
print('bg', Image.open(files['bg']).size)

# review sheet on a checker so transparency problems show up
sheet = Image.new('RGB', (1400, 900), '#3A4A88')
d = ImageDraw.Draw(sheet)
for y in range(0, 900, 40):
    for x in range(0, 1400, 40):
        if (x // 40 + y // 40) % 2: d.rectangle([x, y, x + 39, y + 39], fill='#2C3A74')
y = 10
for n, maxw in (('wordmark.png', 900), ('cloud.png', 420), ('trail.png', 900)):
    im = Image.open(os.path.join(dst, n))
    s = min(1, maxw / im.width)
    im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    sheet.paste(im, (20, y), im)
    y += im.height + 20
os.makedirs(os.path.join(root, 'assets', 'marketing', 'v2', 'preview'), exist_ok=True)
sheet.save(os.path.join(root, 'assets', 'marketing', 'v2', 'preview', 'loading-assets-check.png'))

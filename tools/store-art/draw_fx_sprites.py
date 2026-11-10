"""Particle sprites for client/RewardFX (white, so ParticleEmitter.Color tints them).

  python tools/store-art/draw_fx_sprites.py

Writes assets/fx/sparkle.png (a 4-point cartoon twinkle with a soft glow), ring.png (a soft
shock ring) and rays.png (12 soft sun rays for the hatch reveal), 256x256 RGBA.
"""
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
out = os.path.join(root, 'assets', 'fx')
os.makedirs(out, exist_ok=True)
S = 256
C = S / 2


def white(alpha):
    img = Image.new('RGBA', (S, S), (255, 255, 255, 0))
    img.putalpha(alpha)
    return img


def sparkle():
    a = Image.new('L', (S, S), 0)
    d = ImageDraw.Draw(a)
    # concave 4-point star: long vertical/horizontal tips, pinched waist
    pts = []
    for i in range(256):
        t = i / 256 * 2 * math.pi
        r = 14 + 106 * abs(math.cos(2 * t)) ** 7
        pts.append((C + math.cos(t) * r, C + math.sin(t) * r))
    d.polygon(pts, fill=255)
    glow = a.filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.7))
    core = Image.new('L', (S, S), 0)
    ImageDraw.Draw(core).ellipse([C - 30, C - 30, C + 30, C + 30], fill=200)
    core = core.filter(ImageFilter.GaussianBlur(16))
    alpha = Image.fromarray(np.maximum.reduce([np.array(x) for x in (a, glow, core)]))
    white(alpha).save(os.path.join(out, 'sparkle.png'))


def ring():
    a = Image.new('L', (S, S), 0)
    d = ImageDraw.Draw(a)
    d.ellipse([12, 12, S - 12, S - 12], outline=255, width=18)
    a = a.filter(ImageFilter.GaussianBlur(5))
    white(a).save(os.path.join(out, 'ring.png'))


def rays():
    a = Image.new('L', (S * 2, S * 2), 0)
    d = ImageDraw.Draw(a)
    c = S
    for i in range(12):
        t0 = i / 12 * 2 * math.pi
        w = math.pi / 20
        d.polygon([(c, c), (c + math.cos(t0 - w) * S, c + math.sin(t0 - w) * S), (c + math.cos(t0 + w) * S, c + math.sin(t0 + w) * S)], fill=255)
    a = a.filter(ImageFilter.GaussianBlur(6))
    # fade toward the edge
    fade = Image.new('L', (S * 2, S * 2), 0)
    fd = ImageDraw.Draw(fade)
    for r in range(S, 0, -2):
        fd.ellipse([c - r, c - r, c + r, c + r], fill=int(255 * min(1, 1.6 * (1 - r / S)) ** 0.9))
    alpha =(np.array(a).astype(float) * np.array(fade).astype(float) / 255).astype('uint8')
    white(Image.fromarray(alpha).resize((S, S), Image.LANCZOS)).save(os.path.join(out, 'rays.png'))


sparkle()
ring()
rays()
print('wrote', os.listdir(out))

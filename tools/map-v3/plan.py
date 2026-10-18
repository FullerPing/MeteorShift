"""Caldera v2 detailed plan: every footprint in world studs, checked, then drawn as a .dc.html board.

World: X east, Z north, crater at the origin. Tiers: T0 r<250 (Y0), cliff 250-266, T1 266-360 (Y16),
cliff 360-372, T2 372..wall (Y32), Crown plateau x -150..150, z 400..530 (Y56).
Avenues every 45 degrees from the ring road out to the walls/corners; slides run beside three of them.
"""
import math, sys, html

HALF = 540
RING, RING_W = 134, 18          # crater ring road (contract)
EXPRESS, EXPRESS_W = 280, 16    # T1 fast ring
AVE_HALF = 12                   # avenue is 24 wide
SLIDE_OFF, SLIDE_W = 22, 8      # slide centre line offset from its avenue
CROWN = (-150, 150, 400, 530)
BANDS = {"T0": (147, 246), "T1": (292, 356), "T2": (376, 9999), "ARENA": (86, 124)}
SLIDES = [(45, -1), (135, 1), (90, 1)]  # (avenue angle, side) side: +1 = CCW of the avenue

items = []   # dict: kind, label, x, z, w, d, rot (deg, world yaw of the box's d-axis), color, band, tag

def polar(theta, r):
    t = math.radians(theta)
    return r * math.cos(t), r * math.sin(t)

def put(cell, theta, r, u, w, d, color, label="", band=None, kind="box", tag=""):
    """Box centred at radius r on the cell's centre line, shifted u studs along the tangent (CCW),
    w across (tangent) x d deep (radial), facing the crater."""
    t = math.radians(theta)
    x = r * math.cos(t) - u * math.sin(t)
    z = r * math.sin(t) + u * math.cos(t)
    items.append(dict(kind=kind, label=label, x=x, z=z, w=w, d=d, rot=theta, color=color, band=band, cell=cell, tag=tag))

def putxy(cell, x, z, w, d, color, label="", band=None, kind="box", tag=""):
    items.append(dict(kind=kind, label=label, x=x, z=z, w=w, d=d, rot=90, color=color, band=band, cell=cell, tag=tag))

def grid(cell, theta, r, cols, rows, color, band, pitch=22, rock=10, skip=()):
    for i in range(cols):
        for j in range(rows):
            if (i, j) in skip:
                continue
            u = (i - (cols - 1) / 2) * pitch
            v = (j - (rows - 1) / 2) * pitch
            put(cell, theta, r + v, u, rock, rock, color, band=band, kind="rock")

def field(cell, theta, r, cols, rows, color, band, gate_r, chute_u, landmark=None, skip=()):
    grid(cell, theta, r, cols, rows, color, band, skip=skip)
    put(cell, theta, gate_r, 0, 30, 4, "#1B2A4A", "gate", band, kind="gate")
    put(cell, theta, gate_r + 1, chute_u, 9, 9, "#FFFFFF", "chute", band, kind="chute")
    if landmark:
        lr, lw, ld, lname = landmark
        put(cell, theta, lr, 0, lw, ld, color, lname, band, kind="landmark")

# ---- Arena (inside the ring road): podium on the north terrace
put("A", 90, 104, 0, 16, 8, "#FFD54A", "podium", "ARENA")

# ---- T0 cells (r 147..246). Cell centres at 22.5 + 45k.
put("T0-SSE", -67.5, 200, 0, 50, 36, "#5AA9FF", "Gear Hall", "T0")
put("T0-SSE", -67.5, 160, -30, 18, 5, "#1B2A4A", "board", "T0")
put("T0-SSE", -67.5, 237, 22, 24, 12, "#C9D3E0", "anvil yard", "T0")
put("T0-SSW", -112.5, 200, 0, 64, 36, "#FFB0D9", "Hatchery", "T0")
put("T0-SSW", -112.5, 160, 30, 18, 5, "#1B2A4A", "board", "T0")
for u in (-26, 0, 26):
    put("T0-SSW", -112.5, 238, u, 10, 10, "#FFE9A8", "", "T0", tag="egg plinth")
field("T0-WSW", -157.5, 202, 5, 3, "#E8763A", "T0", 160, 34, landmark=None)
put("T0-WSW", -157.5, 237, -30, 14, 8, "#B9572A", "derrick", "T0", kind="landmark")
field("T0-ESE", -22.5, 202, 5, 3, "#A8E4FF", "T0", 160, -34, landmark=None)
put("T0-ESE", -22.5, 237, 30, 16, 8, "#7FD8FF", "ice falls", "T0", kind="landmark")
put("T0-WNW", 157.5, 170, 0, 22, 6, "#D94F4F", "Quest Board", "T0")
put("T0-WNW", 157.5, 196, -22, 10, 10, "#FFE27A", "chest", "T0")
put("T0-WNW", 157.5, 196, 22, 9, 9, "#FFFFFF", "codes", "T0")
put("T0-WNW", 157.5, 228, 0, 56, 26, "#FFF1D6", "Museum", "T0")
for u in (-28, 0, 28):
    put("T0-NNW", 112.5, 180, u, 22, 18, "#C9F29B", "pen", "T0")
put("T0-NNW", 112.5, 222, 0, 18, 18, "#7FD8FF", "egg fountain", "T0")
put("T0-NNW", 112.5, 224, -38, 20, 12, "#FFB0D9", "pet shop", "T0")
put("T0-NNE", 67.5, 226, 0, 46, 22, "#F06A3B", "Shower Stage", "T0")
for i, r in enumerate((172, 184, 196)):
    put("T0-NNE", 67.5, r, 0, 44 + i * 8, 4, "#FFFFFF", "", "T0", tag="seating")
put("T0-ENE", 22.5, 196, 0, 30, 28, "#FF9F43", "Commissary", "T0")
put("T0-ENE", 22.5, 236, -30, 20, 10, "#FFF1D6", "cafe", "T0")
put("T0-ENE", 22.5, 236, 30, 20, 10, "#C9D3E0", "stats board", "T0")
# South avenue specials (exempt from avenue clearance): spawn plaza and Refinery straddle it
putxy("S", 0, -150.5, 48, 13, "#D8E8FF", "spawn", "T0", tag="axis")
putxy("S", 0, -177, 38, 32, "#FF9F43", "Refinery", "T0", tag="axis")

# ---- T1 cells (r 292..356)
field("T1-WNW", 157.5, 326, 7, 2, "#9B6BE8", "T1", 296, 86, skip=((3, 1),))
put("T1-WNW", 157.5, 337, 0, 14, 14, "#6A3BB8", "geode", "T1", kind="landmark")
field("T1-ENE", 22.5, 326, 7, 2, "#F2D33B", "T1", 296, -86, skip=((3, 1),))
put("T1-ENE", 22.5, 337, 0, 14, 14, "#C79A00", "springs", "T1", kind="landmark")
put("T1-NNE", 67.5, 324, 0, 40, 40, "#9C8B7A", "Cinder Scar", "T1", kind="scar")
for k in range(8):
    a = 22.5 + k * 45
    put("T1-NNE", 67.5, 324 + 27 * math.sin(math.radians(a)), 27 * math.cos(math.radians(a)), 6, 6, "#FF9A4D", "", "T1", kind="rock", tag="surge rock")
for k, (u, r) in enumerate(((-60, 300), (-36, 318), (-12, 302), (12, 320), (36, 304), (60, 322))):
    put("T1-NNW", 112.5, r, u, 9, 9, "#FF8FC8", "", "T1", tag="obby pad")
put("T1-NNW", 112.5, 345, 0, 30, 8, "#1B2A4A", "Ledge Run", "T1")
for u in (-50, 0, 50):
    put("T1-WSW", -157.5, 334, u, 16, 12, "#E8C48A", "tent", "T1")
put("T1-WSW", -157.5, 306, 0, 100, 4, "#8A6A4F", "cart rail", "T1")
for u in (-64, -32, 0, 32, 64):
    put("T1-SSW", -112.5, 324, u, 14, 14, "#FFE9A8", "", "T1", tag="giant egg")
put("T1-SSE", -67.5, 330, 0, 44, 14, "#FFD54A", "Hall of Fame", "T1")
for u in (-60, 60):
    put("T1-SSE", -67.5, 318, u, 10, 10, "#C9D3E0", "statue", "T1")
put("T1-ESE", -22.5, 326, -8, 84, 40, "#DDF3FF", "Frost Rink", "T1")
put("T1-ESE", -22.5, 326, 56, 12, 10, "#B5651D", "cocoa", "T1")
putxy("S", 0, -320, 40, 36, "#FFFFFF", "Rebirth Terrace", "T1", tag="axis")

# ---- T2 cells (r 376..wall)
field("T2-WNW", 157.5, 440, 6, 4, "#FF6A4E", "T2", 384, 90)
put("T2-WNW", 157.5, 510, 0, 60, 40, "#7A2E1E", "Ember vent", "T2", kind="landmark")
put("T2-ENE", 22.5, 470, 0, 80, 80, "#3FB8C8", "Glass Scar", "T2", kind="scar")
for k in range(14):
    a = k * (360 / 14)
    put("T2-ENE", 22.5, 470 + 58 * math.sin(math.radians(a)), 58 * math.cos(math.radians(a)), 10, 10, "#6FF0E0", "", "T2", kind="rock")
put("T2-ENE", 22.5, 384, 0, 30, 4, "#1B2A4A", "gate", "T2", kind="gate")
put("T2-ENE", 22.5, 385, -48, 9, 9, "#FFFFFF", "chute", "T2", kind="chute")
# Crown plateau and its contents (absolute)
putxy("CROWN", 0, 465, 300, 130, "#B8A6F0", "", "CROWN", kind="plateau")
for i in range(4):
    for j in range(3):
        putxy("CROWN", -118 + i * 22, 440 + j * 22, 10, 10, "#FF8FC8", "", "CROWN", kind="rock", tag="crownrock")
putxy("CROWN", -70, 420, 9, 9, "#FFFFFF", "chute", "CROWN", kind="chute", tag="crownrock")
for i, (x, z) in enumerate(((40, 440), (70, 440), (100, 440), (40, 480), (70, 480), (100, 480))):
    putxy("CROWN", x, z, 12, 12, "#FFD54A", "", "CROWN", kind="rock", tag="crownrock")
putxy("CROWN", 125, 420, 9, 9, "#FFFFFF", "chute", "CROWN", kind="chute", tag="crownrock")
putxy("CROWN", 0, 505, 14, 14, "#FFF7B0", "Beacon", "CROWN", tag="crownrock")
putxy("CROWN", 0, 410, 14, 10, "#FFFFFF", "lift", "CROWN", tag="crownrock")
putxy("CROWN", -30, 475, 14, 14, "#F0418E", "Dive", "CROWN", tag="crownrock")
# Outer north wings beside the Crown
for sx in (-1, 1):
    putxy("T2-N", sx * 300, 470, 70, 40, "#C9F29B", "Sky Garden", "T2")
    for k in range(3):
        putxy("T2-N", sx * (220 + k * 30), 410, 14, 14, "#7ED36B", "", "T2", tag="tree")
for theta, name in ((-157.5 - 45, None),):
    pass
# W5 outer: Iron Badlands
for (u, r, w, d) in ((-70, 420, 30, 22), (10, 440, 40, 26), (80, 410, 24, 20), (-30, 490, 34, 22), (60, 500, 30, 24)):
    put("T2-WSW", -157.5, r, u, w, d, "#8C97A8", "", "T2", tag="meteor wreck")
put("T2-WSW", -157.5, 460, -95, 9, 9, "#FFE27A", "geode", "T2", tag="secret")
# W6 outer: harbour on the south wall + lighthouse
putxy("T2-SSW", -150, -515, 190, 30, "#C8A06A", "Harbour boardwalk", "T2")
putxy("T2-SSW", -230, -470, 18, 18, "#FFFFFF", "lighthouse", "T2")
for k in range(3):
    putxy("T2-SSW", -170 + k * 40, -460, 26, 16, "#7FD8FF", "", "T2", tag="boat shed")
# W7 outer: Sky Obby Tower
putxy("T2-SSE", 170, -440, 34, 34, "#9EC9FF", "Sky Obby Tower", "T2")
putxy("T2-SSE", 230, -480, 14, 14, "#FFE27A", "chest", "T2")
for k in range(4):
    putxy("T2-SSE", 110 + k * 26, -505, 18, 12, "#C9F29B", "", "T2", tag="hedge")
# W8 outer: Waterfall Gardens
putxy("T2-ESE", 440, -170, 60, 90, "#7FD8FF", "Waterfall pools", "T2")
for k in range(3):
    putxy("T2-ESE", 370, -120 - k * 40, 18, 18, "#7ED36B", "", "T2", tag="tree")
putxy("T2-ESE", 500, -260, 9, 9, "#FFE27A", "geode", "T2", tag="secret")
# Lookout towers closing the four diagonal avenues
for sx, sz in ((1, 1), (-1, 1), (-1, -1), (1, -1)):
    putxy("CORNER", sx * 495, sz * 495, 26, 26, "#FFFFFF", "Lookout", "T2", tag="avenue-end")

# ---- More designed T2 content (the outer band was too empty)
# Ember Shelf surroundings: lava pools and ash cones
for (u, r) in ((-110, 410), (110, 415), (-120, 470), (120, 478)):
    put("T2-WNW", 157.5, r, u, 22, 16, "#C2381E", "", "T2", tag="lava pool")
for (u, r) in ((-80, 525), (80, 528)):
    put("T2-WNW", 157.5, r, u, 20, 20, "#5A3A2C", "", "T2", tag="ash cone")
# Glass Scar: crystal spire ring outside the rocks
for k in range(10):
    a = k * 36 + 18
    if math.sin(math.radians(a)) < -0.5:
        continue  # keep the gate side open
    put("T2-ENE", 22.5, 470 + 82 * math.sin(math.radians(a)), 82 * math.cos(math.radians(a)), 9, 9, "#9AF5EA", "", "T2", tag="crystal spire")
# Iron Badlands: a second small scar, crane wrecks and rails
put("T2-WSW", -157.5, 500, 110, 34, 34, "#6B7380", "old scar", "T2", kind="scar")
for (u, r) in ((-110, 470), (120, 455)):
    put("T2-WSW", -157.5, r, u, 10, 30, "#E8C48A", "", "T2", tag="crane")
put("T2-WSW", -157.5, 392, 0, 160, 4, "#8A6A4F", "rail", "T2", tag="rail")
# Harbour village: two house rows and market stalls
for k in range(6):
    putxy("T2-SSW", -300 + k * 24, -430, 18, 14, "#FFE3C2", "", "T2", tag="house")
for k in range(5):
    putxy("T2-SSW", -110 + k * 20, -410, 14, 10, "#FF9EC4" if k % 2 else "#9ED8FF", "", "T2", tag="stall")
putxy("T2-SSW", -60, -470, 30, 20, "#C8A06A", "fish market", "T2")
# Sky Obby surroundings: campground and training pads
for k in range(4):
    putxy("T2-SSE", 270 + (k % 2) * 30, -400 - (k // 2) * 30, 16, 12, "#E8C48A", "", "T2", tag="tent")
for k in range(6):
    putxy("T2-SSE", 120 + k * 20, -390 + (k % 2) * 14, 9, 9, "#FF8FC8", "", "T2", tag="obby pad")
# Waterfall Gardens: orchard grid
for i in range(4):
    for j in range(5):
        putxy("T2-ESE", 442 + i * 18, -330 - j * 18, 9, 9, "#F79AC0" if (i + j) % 2 else "#7ED36B", "", "T2", tag="orchard tree")
# North wings: windmills and orchards
for sx in (-1, 1):
    putxy("T2-N", sx * 230, 515, 16, 16, "#FFFFFF", "", "T2", tag="windmill")
    putxy("T2-N", sx * 380, 515, 16, 16, "#FFFFFF", "", "T2", tag="windmill")
    for i in range(3):
        for j in range(3):
            putxy("T2-N", sx * (470 + i * 18), 400 + j * 18, 9, 9, "#F79AC0", "", "T2", tag="orchard tree")
# Watch posts along the inner face of the walls (skipped where something is already there)
WALL_POSTS = []
for k in range(-4, 5):
    for (x, z) in ((k * 110, -522), (k * 110, 522), (-522, k * 110), (522, k * 110)):
        WALL_POSTS.append((x, z))

# ---------------------------------------------------------------- checks
def corners(it):
    t = math.radians(it["rot"])
    ox, oz = math.cos(t), math.sin(t)          # radial (d axis)
    tx, tz = -math.sin(t), math.cos(t)          # tangent (w axis)
    hw, hd = it["w"] / 2, it["d"] / 2
    return [(it["x"] + a * hw * tx + b * hd * ox, it["z"] + a * hw * tz + b * hd * oz) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]

def overlap(a, b):
    pa, pb = corners(a), corners(b)
    for poly in (pa, pb):
        for i in range(4):
            x1, z1 = poly[i]; x2, z2 = poly[(i + 1) % 4]
            nx, nz = z2 - z1, x1 - x2
            sa = [nx * x + nz * z for x, z in pa]; sb = [nx * x + nz * z for x, z in pb]
            if max(sa) <= min(sb) or max(sb) <= min(sa):
                return False
    return True

def samples(it, n=6):
    t = math.radians(it["rot"])
    ox, oz = math.cos(t), math.sin(t); tx, tz = -math.sin(t), math.cos(t)
    for i in range(n + 1):
        for j in range(n + 1):
            a = -1 + 2 * i / n; b = -1 + 2 * j / n
            yield it["x"] + a * it["w"] / 2 * tx + b * it["d"] / 2 * ox, it["z"] + a * it["w"] / 2 * tz + b * it["d"] / 2 * oz

def line_dist(x, z, ang):
    t = math.radians(ang)
    along = x * math.cos(t) + z * math.sin(t)
    if along < 0:
        return 1e9
    return abs(-x * math.sin(t) + z * math.cos(t))

def in_crown(x, z, m=0):
    return CROWN[0] - m <= x <= CROWN[1] + m and CROWN[2] - m <= z <= CROWN[3] + m

def point_error(it, x, z):
    r = math.hypot(x, z)
    if abs(x) > HALF - 6 or abs(z) > HALF - 6:
        return f"outside the wall at ({x:.0f},{z:.0f})"
    if it["band"] == "CROWN":
        return None if in_crown(x, z) else "off the Crown"
    lo, hi = BANDS[it["band"]]
    if it["tag"] == "axis":
        lo = RING + RING_W / 2  # the spawn plaza touches the ring road by contract
    if not (lo <= r <= hi):
        return f"r {r:.0f} outside band {it['band']}"
    if it["band"] == "T2" and in_crown(x, z, 10):
        return "on the Crown footprint"
    if it["band"] == "T1" and abs(r - EXPRESS) < EXPRESS_W / 2 + 3:
        return "on the Express"
    if it["tag"] in ("axis", "avenue-end"):
        return None
    for k in range(8):
        ang = k * 45
        if ang == 90 and z > CROWN[2] - 12:
            continue
        if r > RING and line_dist(x, z, ang) < AVE_HALF + 3:
            return f"on avenue {ang}"
    for ang, side in SLIDES:
        t = math.radians(ang)
        along = x * math.cos(t) + z * math.sin(t)
        across = -x * math.sin(t) + z * math.cos(t)
        top = CROWN[2] if ang == 90 else 372
        if RING < along < top and abs(across - side * SLIDE_OFF) < SLIDE_W / 2 + 3:
            return f"on the {ang} slide"
    return None

errors = []
for it in items:
    for x, z in samples(it):
        e = point_error(it, x, z)
        if e:
            errors.append(f"{it['cell']} {it['label'] or it['tag'] or it['kind']}: {e}")
            break

solid = [it for it in items if it["kind"] != "plateau"]
for i in range(len(solid)):
    for j in range(i + 1, len(solid)):
        if overlap(solid[i], solid[j]):
            a, b = solid[i], solid[j]
            errors.append(f"overlap: {a['cell']} {a['label'] or a['tag'] or a['kind']} x {b['cell']} {b['label'] or b['tag'] or b['kind']}")

if errors:
    print("\n".join(sorted(set(errors))))
    sys.exit(1)
designed = len(items)

# ---------------------------------------------------------------- scenery fill (seeded rejection sampling)
import random
rng = random.Random(7)
CELL = 40
hash_ = {}
def keys(it, pad):
    xs = [c[0] for c in corners(it)]; zs = [c[1] for c in corners(it)]
    for gx in range(int((min(xs) - pad) // CELL), int((max(xs) + pad) // CELL) + 1):
        for gz in range(int((min(zs) - pad) // CELL), int((max(zs) + pad) // CELL) + 1):
            yield gx, gz
def index(it):
    for k in keys(it, 0):
        hash_.setdefault(k, []).append(it)
def grown(it, pad):
    return dict(it, w=it["w"] + 2 * pad, d=it["d"] + 2 * pad)
# keep-clear margin round each designed footprint: access to gates, chutes and building fronts stays open
PAD = {"gate": 16, "chute": 12, "rock": 5, "box": 7, "landmark": 5, "scar": 5}
for it in items:
    if it["kind"] != "plateau":
        index(grown(it, PAD.get(it["kind"], 5)))

def biome(x, z):
    r = math.hypot(x, z)
    ang = math.degrees(math.atan2(z, x)) % 360
    wedge = int(ang // 45)  # 0 = ENE ... 7 = ESE
    band = "T0" if r < 250 else ("T1" if r < 366 else "T2")
    if band == "T2" and z > 380 and abs(x) < 330:
        return band, "blossom"
    table = {0: "glass" if band == "T2" else "sulfur", 1: "meadow", 2: "meadow", 3: "ember" if band == "T2" else "violet",
             4: "iron" if band == "T2" else "rust", 5: "village", 6: "village", 7: "frost"}
    return band, table[wedge]
PALETTE = {
    "glass": [("crystal", 6, "#9AF5EA"), ("boulder", 7, "#B9C9CC"), ("bush", 5, "#5FC9B5")],
    "sulfur": [("vent", 5, "#F2D33B"), ("boulder", 7, "#D9B860"), ("bush", 5, "#B7D45A")],
    "meadow": [("tree", 9, "#3E9E5A"), ("tree", 8, "#57B868"), ("bush", 5, "#7ED36B"), ("flowers", 6, "#FF9EC4")],
    "violet": [("crystal", 6, "#B98BFF"), ("tree", 8, "#5E4A8C"), ("bush", 5, "#8E6BC9")],
    "ember": [("ash tree", 8, "#4A3A3A"), ("boulder", 7, "#7A2E1E"), ("ember", 4, "#FF7A3D")],
    "rust": [("mesa", 10, "#D9774A"), ("boulder", 7, "#B9572A"), ("bush", 5, "#C9A75A")],
    "iron": [("scrap", 8, "#8C97A8"), ("boulder", 8, "#6B7380"), ("bush", 5, "#9AA36A")],
    "village": [("tree", 9, "#3E9E5A"), ("bush", 5, "#7ED36B"), ("flowers", 6, "#FFD54A"), ("lamp", 3, "#FFF7B0")],
    "frost": [("pine", 8, "#2F7A6A"), ("snow mound", 7, "#F4FBFF"), ("ice", 5, "#BFE6FA")],
    "blossom": [("blossom tree", 9, "#F79AC0"), ("bush", 5, "#7ED36B"), ("lamp", 3, "#FFF7B0")],
}
TARGET = {"T0": 380, "T1": 480, "T2": 2300}
placed = {"T0": 0, "T1": 0, "T2": 0}
added = []

def fits(it):
    for x, z in samples(it, 2):
        if point_error(it, x, z):
            return False
    for k in keys(it, 0):
        for other in hash_.get(k, ()):
            if overlap(it, other):
                return False
    return True

# watch posts first, then scenery
for (x, z) in WALL_POSTS:
    it = dict(kind="box", label="", x=x, z=z, w=12, d=12, rot=90, color="#E8EEF8", band="T2", cell="WALL", tag="watch post")
    if fits(it):
        items.append(it); index(grown(it, 4)); added.append(it)
tries = 0
while any(placed[b] < TARGET[b] for b in placed) and tries < 400000:
    tries += 1
    x, z = rng.uniform(-HALF + 8, HALF - 8), rng.uniform(-HALF + 8, HALF - 8)
    r = math.hypot(x, z)
    if r < BANDS["T0"][0]:
        continue
    band, b = biome(x, z)
    if placed[band] >= TARGET[band]:
        continue
    kind, size, color = rng.choice(PALETTE[b])
    s = size * rng.uniform(0.85, 1.25)
    it = dict(kind="deco", label="", x=x, z=z, w=s, d=s, rot=90, color=color, band=band, cell="SCATTER", tag=kind)
    if fits(it):
        items.append(it); index(grown(it, 1.5)); added.append(it); placed[band] += 1

# scattered vs designed is guaranteed by fits(); check scattered vs scattered here
assert all(not overlap(a, b) for i, a in enumerate(added) for b in added[i + 1:] if abs(a["x"] - b["x"]) < 30 and abs(a["z"] - b["z"]) < 30), "scenery overlap"
print(f"OK: {designed} designed footprints + {len(added)} scenery ({placed}), no overlaps, clear of avenues, slides, roads and cliffs")

# ---------------------------------------------------------------- draw
MAP = 1400
S = MAP / (2 * HALF)
def px(x): return MAP / 2 + x * S
def pz(z): return MAP / 2 - z * S

out = []
def div(style, inner=""):
    out.append(f'<div style="{style}">{inner}</div>')

def circle(r, style):
    d = 2 * r * S
    div(f"position: absolute; left: {MAP/2 - d/2:.1f}px; top: {MAP/2 - d/2:.1f}px; width: {d:.1f}px; height: {d:.1f}px; border-radius: 50%; box-sizing: border-box; {style}")

div(f"position: absolute; left: 0; top: 0; width: {MAP}px; height: {MAP}px; background: #5DBB8E")
circle(372, "background: #D9914A; border: 2px solid #1B2A4A")
circle(360, "background: #7ED36B")
circle(266, "background: #D9914A; border: 2px solid #1B2A4A")
circle(250, "background: #A6E07A")
# crown plateau
cx0, cx1, cz0, cz1 = CROWN
div(f"position: absolute; left: {px(cx0)-6:.1f}px; top: {pz(cz1):.1f}px; width: {(cx1-cx0)*S+12:.1f}px; height: {(cz1-cz0)*S+6:.1f}px; background: #D9914A; border: 2px solid #1B2A4A; border-top: none; box-sizing: border-box; border-radius: 0 0 18px 18px")
div(f"position: absolute; left: {px(cx0):.1f}px; top: {pz(cz1):.1f}px; width: {(cx1-cx0)*S:.1f}px; height: {(cz1-cz0)*S:.1f}px; background: #B8A6F0; border-radius: 0 0 14px 14px")
# avenues (from the ring road out; north stops at the Crown)
for k in range(8):
    ang = k * 45
    end = (CROWN[2] if ang == 90 else (760 if ang % 90 else 540))
    start = RING + RING_W / 2
    L = (end - start) * S
    mx, mz = polar(ang, (start + end) / 2)
    div(f"position: absolute; left: {px(mx) - L/2:.1f}px; top: {pz(mz) - AVE_HALF*S:.1f}px; width: {L:.1f}px; height: {2*AVE_HALF*S:.1f}px; background: #FFF1C9; border: 2px solid #1B2A4A; box-sizing: border-box; transform: rotate({-ang}deg)",
        f'<div style="position: absolute; left: 0; right: 0; top: 50%; height: 6px; margin-top: -3px; background: #FFC93C"></div>')
# slides
for ang, side in SLIDES:
    top = CROWN[2] if ang == 90 else 372
    start = RING + RING_W / 2
    t = math.radians(ang)
    mid = (start + top) / 2
    mx = mid * math.cos(t) - side * SLIDE_OFF * math.sin(t)
    mz = mid * math.sin(t) + side * SLIDE_OFF * math.cos(t)
    L = (top - start) * S
    div(f"position: absolute; left: {px(mx) - L/2:.1f}px; top: {pz(mz) - SLIDE_W*S/2:.1f}px; width: {L:.1f}px; height: {SLIDE_W*S:.1f}px; background: #7FD8FF; border: 2px solid #1B2A4A; border-radius: 6px; box-sizing: border-box; transform: rotate({-ang}deg)")
# roads
circle(EXPRESS + EXPRESS_W / 2, f"border: {EXPRESS_W*S:.1f}px solid #FFB547; box-shadow: 0 0 0 2px #1B2A4A, inset 0 0 0 2px #1B2A4A")
circle(RING + RING_W / 2, f"border: {RING_W*S:.1f}px solid #FFB547; box-shadow: 0 0 0 2px #1B2A4A, inset 0 0 0 2px #1B2A4A")
# crater arena
circle(124, "background: #9BE27F")
circle(118, "border: 3px dashed #F06A3B")
circle(112, "border: 2px solid #E8EEF8")
circle(104, "border: 2px solid #D3DDEE")
circle(96, "border: 2px solid #BFCCE4")
circle(83.2, "background: #8A6A4F; border: 4px solid #F2B33D")
circle(55.25, "background: #5A4636")
circle(9, "background: #FF7A3D; border: 3px solid #1B2A4A; box-shadow: 0 0 22px #FFB547")
for ang in (0, 90, 180, 270):
    mx, mz = polar(ang, 103)
    div(f"position: absolute; left: {px(mx) - 21*S:.1f}px; top: {pz(mz) - 12*S:.1f}px; width: {42*S:.1f}px; height: {24*S:.1f}px; background: #F3E3BE; border: 2px solid #1B2A4A; box-sizing: border-box; transform: rotate({-ang}deg)")

# footprints
order = {"plateau": 0, "deco": 1, "scar": 1, "box": 2, "landmark": 2, "rock": 3, "gate": 4, "chute": 5}
for it in sorted(items, key=lambda i: order[i["kind"]]):
    if it["kind"] == "plateau":
        continue
    w, d = it["w"] * S, it["d"] * S
    cx, cy = px(it["x"]), pz(it["z"])
    rot = 90 - it["rot"]
    if it["kind"] == "deco":
        round_ = it["tag"] in ("tree", "pine", "bush", "blossom tree", "ash tree", "flowers", "snow mound", "lamp")
        div(f"position: absolute; left: {cx - w/2:.1f}px; top: {cy - d/2:.1f}px; width: {w:.1f}px; height: {d:.1f}px; background: {it['color']}; border: 1px solid rgba(27,42,74,0.7); border-radius: {'50%' if round_ else '3px'}; box-sizing: border-box; transform: rotate({(it['x'] * 7) % 90:.0f}deg)")
        continue
    radius = "50%" if it["kind"] == "scar" else ("3px" if it["kind"] == "rock" else "4px")
    border = "2px dashed #1B2A4A" if it["kind"] == "scar" else ("1.5px solid #1B2A4A" if it["kind"] in ("rock", "chute") else "2px solid #1B2A4A")
    if it["kind"] == "chute":
        border = "2.5px solid #1B2A4A"
    inner = ""
    if it["label"] and it["kind"] not in ("chute", "gate", "rock") and min(w, d) >= 12:
        size = 10 if min(w, d) < 30 else 12
        inner = f'<span style="position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%) rotate({-rot}deg); font: 700 {size}px Fredoka, sans-serif; color: #1B2A4A; white-space: nowrap; background: rgba(255,255,255,0.85); padding: 0 4px; border-radius: 5px">{html.escape(it["label"])}</span>'
    div(f"position: absolute; left: {cx - w/2:.1f}px; top: {cy - d/2:.1f}px; width: {w:.1f}px; height: {d:.1f}px; background: {it['color']}; border: {border}; border-radius: {radius}; box-sizing: border-box; transform: rotate({rot:.1f}deg)", inner)

# cell tags
CELLS = [
    ("T0-SSE", -67.5, 168, "1"), ("T0-SSW", -112.5, 168, "2"), ("T0-WSW", -157.5, 182, "3"), ("T0-ESE", -22.5, 182, "4"),
    ("T0-WNW", 157.5, 152, "5"), ("T0-NNW", 112.5, 152, "6"), ("T0-NNE", 67.5, 152, "7"), ("T0-ENE", 22.5, 160, "8"),
    ("T1-WNW", 157.5, 352, "9"), ("T1-ENE", 22.5, 352, "10"), ("T1-NNE", 67.5, 350, "11"), ("T1-NNW", 112.5, 352, "12"),
    ("T1-WSW", -157.5, 300, "13"), ("T1-SSW", -112.5, 303, "14"), ("T1-SSE", -67.5, 303, "15"), ("T1-ESE", -22.5, 352, "16"),
    ("T2-WNW", 157.5, 395, "17"), ("T2-ENE", 22.5, 405, "18"), ("CROWN", 90, 520, "19"), ("T2-N", 75, 560, "20"),
    ("T2-WSW", -157.5, 395, "21"), ("T2-SSW", -112.5, 420, "22"), ("T2-SSE", -67.5, 400, "23"), ("T2-ESE", -22.5, 395, "24"),
]
for _, ang, r, n in CELLS:
    x, z = polar(ang, r)
    if n == "20":
        x, z = 300, 510
    div(f"position: absolute; left: {px(x) - 13:.1f}px; top: {pz(z) - 13:.1f}px; width: 26px; height: 26px; border-radius: 50%; background: #1B2A4A; color: #FFFFFF; font: 700 13px/26px Fredoka, sans-serif; text-align: center", n)

map_html = "\n".join(out)

legend = [
    ("1", "Gear Hall, leaderboard, anvil yard"), ("2", "Hatchery, leaderboard, egg plinths"), ("3", "Rust Works · open · 15 rocks"),
    ("4", "Frost Yard · Lv 5 · 15 rocks"), ("5", "Quest Board, daily chest, codes, Museum"), ("6", "Pet Meadow: 3 pens, fountain, pet shop"),
    ("7", "Shower Stage + seating rows"), ("8", "Commissary deposit, cafe, stats"), ("9", "Violet Quarry · Lv 12 · 13 rocks + geode"),
    ("10", "Sulfur Ridge · Lv 20 · 13 rocks + springs"), ("11", "Cinder Scar: Scar Surge event, 8 rocks"), ("12", "Ledge Run obby, 6 pads"),
    ("13", "Prospector Camp, cart rail"), ("14", "Giant egg row"), ("15", "Hall of Fame, statues"), ("16", "Frost Rink, cocoa stand"),
    ("17", "Ember Shelf · Lv 30 · 24 rocks, vent, lava pools"), ("18", "Glass Scar · Lv 40 · 14 rocks, crystal spires"), ("19", "Crown: Starfall R1 (12), Halo R3 (6), lift, Dive, Beacon"),
    ("20", "Sky Gardens, windmills, blossom orchards"), ("21", "Iron Badlands: wrecks, old scar, cranes, rail, geode"), ("22", "Harbour village: houses, stalls, fish market, lighthouse"),
    ("23", "Sky Obby Tower, training pads, campground, chest"), ("24", "Waterfall pools, orchard, geode"),
]
rows = "\n".join(
    f'<div style="display: flex; gap: 10px; align-items: flex-start; font-size: 14px; line-height: 1.3"><span style="flex: none; width: 24px; height: 24px; border-radius: 50%; background: #1B2A4A; color: #FFFFFF; font: 700 12px/24px Fredoka, sans-serif; text-align: center">{n}</span><span>{html.escape(t)}</span></div>'
    for n, t in legend)

page = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Caldera footprints</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link href="https://fonts.googleapis.com/css2?family=Fredoka:wght@500;600;700&amp;family=Nunito:wght@500;700;800&amp;display=swap" rel="stylesheet">
<style>
body{{margin:0}}
</style>
</helmet>
<div style="width: 2000px; height: 1500px; box-sizing: border-box; background: #EAF4FF; font-family: Nunito, sans-serif; color: #1B2A4A; display: flex; gap: 40px; padding: 50px">
<div style="position: relative; width: {MAP}px; height: {MAP}px; flex: none; border: 6px solid #1B2A4A; border-radius: 24px; overflow: hidden; box-sizing: content-box">
{map_html}
</div>
<div style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 12px">
<div style="font: 600 14px Nunito, sans-serif; letter-spacing: 2px; color: #2F7DE1">CALDERA V2 · FOOTPRINT PLAN</div>
<h1 style="margin: 0; font: 700 40px/1.05 Fredoka, sans-serif">Every slice, every box</h1>
<p style="margin: 0; font-size: 14.5px; line-height: 1.4">True scale: 1.3 px per stud. Each footprint is a real object facing the crater: every rock (10×10), chute, gate, building and plinth. {designed} designed footprints plus {len(added)} scenery pieces (trees, bushes, boulders, crystals, lamps, watch posts) themed per slice; the script refuses to draw if two overlap or one sits on an avenue, slide, road or cliff edge.</p>
{rows}
<div style="margin-top: auto; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 6px 10px; font-size: 12.5px; font-weight: 700">
<div style="display: flex; gap: 8px; align-items: center"><div style="width: 12px; height: 12px; background: #E8763A; border: 1.5px solid #1B2A4A; border-radius: 3px"></div>Mineable rock</div>
<div style="display: flex; gap: 8px; align-items: center"><div style="width: 12px; height: 12px; background: #FFFFFF; border: 2.5px solid #1B2A4A"></div>Ore chute</div>
<div style="display: flex; gap: 8px; align-items: center"><div style="width: 20px; height: 5px; background: #1B2A4A"></div>Field gate</div>
<div style="display: flex; gap: 8px; align-items: center"><div style="width: 20px; height: 8px; background: #FFF1C9; border: 2px solid #1B2A4A"></div>Gold avenue (up)</div>
<div style="display: flex; gap: 8px; align-items: center"><div style="width: 20px; height: 8px; background: #7FD8FF; border: 2px solid #1B2A4A; border-radius: 4px"></div>Slide (down)</div>
<div style="display: flex; gap: 8px; align-items: center"><div style="width: 20px; height: 8px; background: #FFB547; border: 2px solid #1B2A4A"></div>Fast ring</div>
</div>
</div>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":2000,"height":1500}}}}'>
class Component extends DCLogic {{
renderVals() {{ return {{}}; }}
}}
</script>
</body>
</html>
"""
with open(sys.argv[1], "w", encoding="utf-8", newline="\n") as f:
    f.write(page)
print("wrote", sys.argv[1])

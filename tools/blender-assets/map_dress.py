"""Map dressing meshes (2026-10-21): the eight ore fields' rocks, street lamps and the outer tree belt.

Run inside Blender 5.2 with tools/blender-assets on sys.path. Each builder makes one asset through assetlib; BUILDERS
maps asset ids to builders. Rocks keep the DebrisService contract: the `Root` mesh is the rock (it collides and takes
hits) and every `OreFleck` is a separate tinted Neon crystal the server recolours by tier.
"""
import bmesh, math, random
from math import pi, cos, sin, tau
from mathutils import Vector, Matrix
import assetlib
from assetlib import Asset

# extra three-tone ramps (top, side, underside) for the field stones
assetlib.RAMPS.update({
    'rust_stone': ['E0875A', 'B35A3A', '6E3324'],
    'rust_band': ['F2A66B', 'CF7442', '8A4128'],
    'frost_stone': ['F4FCFF', '9FD6F2', '4F8DC0'],
    'violet_stone': ['5A5D8C', '3A3D66', '1F2240'],
    'sulfur_stone': ['E8E2C4', 'B8B39A', '7A7766'],
    'sulfur_crust': ['FFF07A', 'E8C83A', 'A88A1E'],
    'ember_stone': ['4A3A3E', '2E2428', '18121A'],
    'glass_stone': ['B8FFF6', '5ED8CC', '2A8A88'],
    'star_stone': ['F4C8E8', 'B88AB8', '6A4A7A'],
    'halo_stone': ['FFFBF0', 'E8DCC4', 'B8A888'],
    'halo_gold': ['FFE680', 'F2B830', 'B07818'],
    'pebble': ['B4B8C4', '8A8E9C', '5A5E6C'],
    'iron': ['5A6478', '3A4256', '1E2434'],
    'leaf_a': ['9BE36A', '5CC045', '2F8A36'],
    'leaf_b': ['B4EC7A', '78CC4E', '3E9A3A'],
    'leaf_pine': ['6FCF7A', '3A9E58', '1F6A40'],
    'palm_leaf': ['A6E866', '6AC447', '3A8A34'],
    'bark': ['A8744A', '7A5034', '4A3022'],
    'palm_bark': ['D6B07A', 'B08A58', '7A5A38'],
})


def chisel(seed, size, cuts=9, subdiv=2, wobble=.06):
    """A cartoon boulder: a lumpy icosphere sliced by random planes, so it reads as hand-chiselled facets."""
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1)
    for v in bm.verts:
        v.co *= 1 + rng.uniform(-wobble, wobble)
    for _ in range(cuts):
        n = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-.55, 1))).normalized()
        d = rng.uniform(.72, .9)
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=n * d, plane_no=n, clear_outer=True)
        edges = [e for e in res['geom_cut'] if isinstance(e, bmesh.types.BMEdge)]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    # flat bottom so it sits on the ground
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, -.55), plane_no=(0, 0, -1), clear_outer=True)
    edges = [e for e in res['geom_cut'] if isinstance(e, bmesh.types.BMEdge)]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(4), verts=bm.verts[:], edges=bm.edges[:])
    lo = Vector([min(v.co[i] for v in bm.verts) for i in range(3)])
    hi = Vector([max(v.co[i] for v in bm.verts) for i in range(3)])
    for v in bm.verts:
        v.co = Vector(((v.co.x - (lo.x + hi.x) / 2) / (hi.x - lo.x) * size[0],
                       (v.co.y - (lo.y + hi.y) / 2) / (hi.y - lo.y) * size[1],
                       (v.co.z - lo.z) / (hi.z - lo.z) * size[2]))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    verts = [tuple(v.co) for v in bm.verts]
    index = {v: i for i, v in enumerate(bm.verts)}
    faces = [tuple(index[v] for v in f.verts) for f in bm.faces]
    bm.free()
    return verts, faces


def place(a, group, verts, faces, loc, color, mode='palette', rot_z=0.0, tilt=(0, 0)):
    m = Matrix.Translation(loc) @ Matrix.Rotation(rot_z, 4, 'Z') @ Matrix.Rotation(tilt[0], 4, 'X') @ Matrix.Rotation(tilt[1], 4, 'Y')
    return a.mesh(group, [tuple(m @ Vector(v)) for v in verts], faces, color, mode)


def boulder(a, group, seed, loc, size, color, rot_z=0.0, cuts=9, subdiv=2, tilt=(0, 0)):
    v, f = chisel(seed, size, cuts, subdiv)
    return place(a, group, v, f, Vector(loc), color, rot_z=rot_z, tilt=tilt)


def surface(objs, x, y, z_from=30.0):
    """Highest point of the given meshes straight above (x, y), and its normal."""
    best = None
    for o in objs:
        inv = o.matrix_world.inverted()
        origin = inv @ Vector((x, y, z_from))
        hit, loc, normal, _ = o.ray_cast(origin, inv.to_3x3() @ Vector((0, 0, -1)))
        if hit:
            w = o.matrix_world @ loc
            if best is None or w.z > best[0].z:
                best = (w, (o.matrix_world.to_3x3() @ normal).normalized())
    return best


def crystal(a, group, base, axis, length, radius, color, mode, sides=6, rng=None):
    """A hexagonal crystal: prism with a pointed, slightly off-centre tip, sunk a little into its base."""
    axis = Vector(axis).normalized()
    q = axis.to_track_quat('Z', 'Y')
    tip_shift = Vector(((rng.uniform(-.12, .12) if rng else 0) * radius, (rng.uniform(-.12, .12) if rng else 0) * radius, 0))
    body = length * .68
    verts, faces = [], []
    for ring, (z, r) in enumerate(((-radius * .6, radius * .92), (body, radius))):
        for i in range(sides):
            t = tau * i / sides
            verts.append(Vector(base) + q @ Vector((r * cos(t), r * sin(t), z)))
    verts.append(Vector(base) + q @ (Vector((0, 0, length)) + tip_shift))
    tip = len(verts) - 1
    faces.append(tuple(reversed(range(sides))))
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((i, j, sides + j, sides + i))
        faces.append((sides + i, sides + j, tip))
    return a.mesh(group, [tuple(v) for v in verts], faces, color, mode)


def cluster(a, group, base, normal, scale, rng, color='white', mode='neon', count=(3, 5)):
    """A spray of crystals fanning out of one spot along `normal`."""
    n = Vector(normal).normalized()
    side = n.cross(Vector((0, 0, 1)) if abs(n.z) < .9 else Vector((1, 0, 0))).normalized()
    up = n.cross(side).normalized()
    k = rng.randint(*count)
    for i in range(k):
        t = tau * i / k + rng.uniform(-.3, .3)
        spread = 0 if i == 0 else rng.uniform(.35, .6)
        axis = (n + (side * cos(t) + up * sin(t)) * spread).normalized()
        length = scale * (1.25 if i == 0 else rng.uniform(.55, .9))
        offset = (side * cos(t) + up * sin(t)) * (0 if i == 0 else scale * .2)
        crystal(a, group, Vector(base) + offset - n * scale * .1, axis, length, scale * (.26 if i == 0 else .18), color, mode, rng=rng)


def pebbles(a, rng, centre_r, count, color='pebble', size=(.5, .9)):
    for i in range(count):
        t = rng.uniform(0, tau)
        r = centre_r * rng.uniform(.95, 1.25)
        s = rng.uniform(*size)
        boulder(a, 'Root', rng.randint(0, 9999), (r * cos(t), r * sin(t), -.05), (s * 1.2, s, s * .7), color, rot_z=rng.uniform(0, tau), cuts=5, subdiv=1)


def finish_rock(a, objs, rng, spots, scale, color='white'):
    for x, y in spots:
        hit = surface(objs, x, y)
        if hit:
            point, normal = hit
            cluster(a, 'OreFleck', point, (normal + Vector((0, 0, 1.2))).normalized(), scale * 1.3 * rng.uniform(.9, 1.15), rng, color)
    return a.finish()


# ---- the eight fields' rocks: three shapes each, ~5.5 x 5.5 footprint, 4-6 tall --------------------------------------------

def rock_rust(n):
    """Rust Works: layered iron-red sandstone ledges, an old bolted strap, rust-orange ore."""
    a = Asset(f'rocks/v2/rust_{n}', budget=1500); rng = random.Random(100 + n)
    a.meta['field'] = 'RustWorks'
    objs = [boulder(a, 'Root', 11 + n, (-.4, .2, 0), (4.6, 4.4, 4.2), 'rust_stone', rot_z=rng.uniform(0, tau), cuts=10)]
    # a banded slab leaning on its flank
    objs.append(boulder(a, 'Root', 21 + n, (1.5, -.5, -.2), (2.4, 3.8, 3.2), 'rust_band', rot_z=rng.uniform(-.4, .4), cuts=8, tilt=(0, .35)))
    objs.append(boulder(a, 'Root', 31 + n, (-1.6, -1.2, 0), (2.0, 1.8, 1.4), 'rust_band', rot_z=rng.uniform(0, tau), cuts=7))
    pebbles(a, rng, 2.9, 4, 'rust_stone')
    return finish_rock(a, objs, rng, [(-.6, .3), (1.3, -.4), (-1.6, -1.2)][: 2 + n % 2], 1.1)


def rock_frost(n):
    """Frost Yard: pale-blue glacier stone under a thick snow cap with icicles, ice-blue ore."""
    a = Asset(f'rocks/v2/frost_{n}', budget=1500); rng = random.Random(200 + n)
    a.meta['field'] = 'FrostYard'
    objs = [boulder(a, 'Root', 41 + n, (0, 0, 0), (5.4, 5.0, 3.6), 'frost_stone', rot_z=rng.uniform(0, tau), cuts=10)]
    objs.append(boulder(a, 'Root', 51 + n, (rng.uniform(-1.2, 1.2), rng.uniform(-.6, .6), 2.4), (3.0, 2.8, 1.9), 'frost_stone', rot_z=rng.uniform(0, tau), cuts=8))
    # snow cap: a flattened white boulder draped over the top
    cap = boulder(a, 'Root', 61 + n, (0, 0, 2.9), (4.6, 4.3, .75), 'white', rot_z=rng.uniform(0, tau), cuts=6)
    objs.append(cap)
    for i in range(6):
        t = -pi / 2 + rng.uniform(-1.1, 1.1)
        hit = surface(objs[:1], 2.4 * cos(t), 2.2 * sin(t), 6)
        if hit:
            p = hit[0] + Vector((0, 0, -.05))
            a.between('Root', tuple(p), tuple(p + Vector((0, 0, -rng.uniform(.5, 1.0)))), .14, 'frost', vertices=5, radius2=.01)
    pebbles(a, rng, 2.8, 3, 'frost_stone')
    return finish_rock(a, objs, rng, [(-.8, .3), (.9, -.2), (0, .9)][: 2 + n % 2], 1.0)


def rock_violet(n):
    """Violet Quarry: dark basalt split open on a geode of amethyst, with violet veins."""
    a = Asset(f'rocks/v2/violet_{n}', budget=1500); rng = random.Random(300 + n)
    a.meta['field'] = 'VioletQuarry'
    left = boulder(a, 'Root', 71 + n, (-1.2, 0, 0), (3.4, 4.6, 4.4), 'violet_stone', rot_z=.3 + rng.uniform(-.2, .2), cuts=9, tilt=(0, -.18))
    right = boulder(a, 'Root', 81 + n, (1.3, .2, 0), (3.2, 4.2, 3.7), 'violet_stone', rot_z=-.4 + rng.uniform(-.2, .2), cuts=9, tilt=(0, .2))
    back = boulder(a, 'Root', 91 + n, (0, 1.2, 0), (3.6, 2.4, 2.6), 'violet_stone', rot_z=rng.uniform(0, tau), cuts=7)
    # fixed amethyst lining the split (palette violet), the tinted ore grows from it
    for i in range(5):
        x = -.6 + i * .3; y = -1.0 + rng.uniform(-.2, .2)
        crystal(a, 'Root', (x, y, .4 + i * .35), ((x) * .8, -1, .5), rng.uniform(1.4, 2.1), .36, 'violet', 'palette', rng=rng)
    pebbles(a, rng, 2.9, 4, 'violet_stone')
    objs = [left, right, back]
    return finish_rock(a, objs, rng, [(-1.3, -.2), (1.3, .1), (0, 1.1)][: 2 + n % 2], 1.1)


def rock_sulfur(n):
    """Sulfur Ridge: porous pale stone with a yellow sulfur crust and smoking vent holes."""
    a = Asset(f'rocks/v2/sulfur_{n}', budget=1500); rng = random.Random(400 + n)
    a.meta['field'] = 'SulfurRidge'
    objs = [boulder(a, 'Root', 101 + n, (0, 0, 0), (5.6, 5.2, 3.2), 'sulfur_stone', rot_z=rng.uniform(0, tau), cuts=10)]
    objs.append(boulder(a, 'Root', 111 + n, (rng.uniform(-.8, .8), rng.uniform(-.4, .4), 2.2), (3.4, 3.0, 2.0), 'sulfur_stone', rot_z=rng.uniform(0, tau), cuts=8))
    objs.append(boulder(a, 'Root', 121 + n, (rng.uniform(-.6, .6), 0, 3.6), (2.6, 2.4, .6), 'sulfur_crust', rot_z=rng.uniform(0, tau), cuts=6))
    # crusty sulfur blooms spilling down the flanks
    for i in range(3):
        t = rng.uniform(0, tau)
        hit = surface(objs[:2], 1.8 * cos(t), 1.8 * sin(t), 6)
        if hit:
            p, nrm = hit
            boulder(a, 'Root', rng.randint(0, 9999), tuple(p - nrm * .25 - Vector((0, 0, .2))), (1.4, 1.2, .55), 'sulfur_crust', rot_z=rng.uniform(0, tau), cuts=5, subdiv=1, tilt=(nrm.y * -.9, nrm.x * .9))
    pebbles(a, rng, 2.9, 3, 'sulfur_crust')
    return finish_rock(a, objs, rng, [(-.9, .4), (.8, -.3), (0, .8)][: 2 + n % 2], 1.0)


def rock_ember(n):
    """Ember Shelf: black volcanic rock with fixed glowing magma seams and a cooled crust."""
    a = Asset(f'rocks/v2/ember_{n}', budget=1500); rng = random.Random(500 + n)
    a.meta['field'] = 'EmberShelf'
    objs = [boulder(a, 'Root', 131 + n, (0, 0, 0), (5.8, 5.2, 3.0), 'ember_stone', rot_z=rng.uniform(0, tau), cuts=11)]
    objs.append(boulder(a, 'Root', 141 + n, (rng.uniform(-.8, .8), rng.uniform(-.5, .5), 2.0), (3.6, 3.2, 2.6), 'ember_stone', rot_z=rng.uniform(0, tau), cuts=9))
    # magma seams: a zig-zag tube draped over the faces, fixed orange Neon (not tier-tinted)
    for k in range(2):
        pts = []
        x0 = rng.uniform(-1.5, 1.5)
        for i in range(7):
            y = -2.6 + i * .45
            hit = surface(objs, x0 + rng.uniform(-.35, .35), y)
            if hit:
                pts.append(tuple(hit[0] + hit[1] * .04))
        if len(pts) >= 3:
            a.tube('Glow', pts, .1, 'FF7A2E', mode='neon', sides=4)
    pebbles(a, rng, 3.0, 4, 'ember_stone')
    return finish_rock(a, objs, rng, [(-.8, .5), (.9, 0), (0, -.6)][: 2 + n % 2], 1.05)


def rock_glass(n):
    """Glass Scar: a heap of fused teal glass shards around a darker core."""
    a = Asset(f'rocks/v2/glass_{n}', budget=1500); rng = random.Random(600 + n)
    a.meta['field'] = 'GlassScar'
    objs = [boulder(a, 'Root', 151 + n, (0, 0, 0), (5.0, 4.6, 2.6), 'violet_stone', rot_z=rng.uniform(0, tau), cuts=9)]
    for i in range(7):
        t = tau * i / 7 + rng.uniform(-.25, .25)
        r = rng.uniform(.8, 1.9)
        axis = (Vector((cos(t), sin(t), 0)) * rng.uniform(.3, .7) + Vector((0, 0, 1))).normalized()
        objs.append(crystal(a, 'Root', (r * cos(t), r * sin(t), .4), axis, rng.uniform(2.2, 3.8), rng.uniform(.45, .7), 'glass_stone', 'palette', sides=4, rng=rng))
    pebbles(a, rng, 2.8, 4, 'glass_stone', size=(.4, .7))
    return finish_rock(a, objs[:1], rng, [(-.5, .3), (.6, -.4), (0, .9)][: 2 + n % 2], 1.0)


def rock_star(n):
    """Starfall: a pink-violet meteorite, pocked with craters, with a scorched skirt around it."""
    a = Asset(f'rocks/v2/star_{n}', budget=1500); rng = random.Random(700 + n)
    a.meta['field'] = 'Starfall'
    body = boulder(a, 'Root', 161 + n, (0, 0, -.2), (5.4, 5.0, 4.4), 'star_stone', rot_z=rng.uniform(0, tau), cuts=6, subdiv=2)
    lobe = boulder(a, 'Root', 191 + n, (1.6, -.9, 0), (2.6, 2.4, 2.4), 'star_stone', rot_z=rng.uniform(0, tau), cuts=7)
    for i in range(3):
        t = rng.uniform(0, tau)
        crystal(a, 'Root', (2.4 * cos(t), 2.4 * sin(t), .1), (cos(t) * .5, sin(t) * .5, 1), rng.uniform(.9, 1.4), .22, 'pink', 'palette', sides=5, rng=rng)
    # scorched skirt: a ring of dark chips around the base
    pebbles(a, rng, 2.9, 6, 'ember_stone', size=(.35, .6))
    return finish_rock(a, [body, lobe], rng, [(-.7, .2), (.7, -.3), (0, .8)][: 2 + n % 2], 1.1)


def rock_halo(n):
    """Halo Ledge: white marble with gold veins and a gilded crown ledge."""
    a = Asset(f'rocks/v2/halo_{n}', budget=1500); rng = random.Random(800 + n)
    a.meta['field'] = 'HaloLedge'
    objs = [boulder(a, 'Root', 171 + n, (0, 0, 0), (5.2, 5.0, 3.4), 'halo_stone', rot_z=rng.uniform(0, tau), cuts=12)]
    objs.append(boulder(a, 'Root', 181 + n, (rng.uniform(-.6, .6), 0, 2.6), (3.2, 3.0, 1.6), 'halo_stone', rot_z=rng.uniform(0, tau), cuts=10))
    for k in range(3):
        pts = []
        y0 = rng.uniform(-1.6, 1.6)
        for i in range(8):
            x = -2.6 + i * .7
            hit = surface(objs, x, y0 + rng.uniform(-.3, .3))
            if hit:
                pts.append(tuple(hit[0] + hit[1] * .03))
        if len(pts) >= 3:
            a.tube('Root', pts, .07, 'halo_gold', mode='palette', sides=4)
    pebbles(a, rng, 2.8, 3, 'halo_stone')
    return finish_rock(a, objs, rng, [(-.6, .2), (.7, -.2), (0, .8)][: 2 + n % 2], 1.05)


ROCKS = {'rust': rock_rust, 'frost': rock_frost, 'violet': rock_violet, 'sulfur': rock_sulfur,
         'ember': rock_ember, 'glass': rock_glass, 'star': rock_star, 'halo': rock_halo}

BUILDERS = {f'rocks/v2/{k}_{n}': (lambda f=f, n=n: f(n)) for k, f in ROCKS.items() for n in range(3)}


# ---- lamps -------------------------------------------------------------------------------------------------------------

def lathe(a, group, profile, color, segments=12, mode='palette'):
    """Revolve (radius, z) points round Z."""
    verts, faces = [], []
    n = len(profile)
    for i in range(segments):
        t = tau * i / segments
        for r, z in profile:
            verts.append((r * cos(t), r * sin(t), z))
    for i in range(segments):
        j = (i + 1) % segments
        for k in range(n - 1):
            faces.append((i * n + k, j * n + k, j * n + k + 1, i * n + k + 1))
    if profile[0][0] > 0:
        faces.append(tuple(i * n for i in reversed(range(segments))))
    if profile[-1][0] > 0:
        faces.append(tuple(i * n + n - 1 for i in range(segments)))
    return a.mesh(group, verts, faces, color, mode)


def lantern(a, z, s=1.0):
    """A four-sided carriage lantern: base tray, glowing panes between corner posts, peaked cap and finial."""
    a.box('Root', (0, 0, z), (1.5 * s, 1.5 * s, .22 * s), 'navy', bevel=.05)
    a.box('Glow', (0, 0, z + .95 * s), (1.1 * s, 1.1 * s, 1.6 * s), 'warm_glow', bevel=0, mode='neon')
    for x in (-.62, .62):
        for y in (-.62, .62):
            a.box('Root', (x * s, y * s, z + .95 * s), (.16 * s, .16 * s, 1.75 * s), 'navy', bevel=.03)
    a.box('Root', (0, 0, z + 1.85 * s), (1.65 * s, 1.65 * s, .2 * s), 'gold', bevel=.05)
    a.cylinder('Root', (0, 0, z + 2.35 * s), 1.05 * s, .8 * s, 'navy', vertices=4, radius2=.12 * s, rot=(0, 0, pi / 4))
    a.cylinder('Root', (0, 0, z + 2.85 * s), .16 * s, .3 * s, 'gold', vertices=8)
    a.ellipsoid('Root', (0, 0, z + 3.08 * s), (.3 * s, .3 * s, .3 * s), 'gold', segments=8, rings=5)


def street_lamp():
    """Map street lamp, 10 studs: fluted cast-iron post on a stepped plinth, gold collars, carriage lantern."""
    a = Asset('props/v2/street_lamp', budget=2500)
    lathe(a, 'Root', [(.95, 0), (.95, .35), (.75, .45), (.75, .8), (.5, .95), (.42, 1.4), (.3, 1.6)], 'navy', segments=8)
    for i in range(8):  # flutes
        t = tau * i / 8 + tau / 16
        a.between('Root', (.36 * cos(t), .36 * sin(t), 1.5), (.24 * cos(t), .24 * sin(t), 6.4), .07, 'navy', vertices=4)
    a.cylinder('Root', (0, 0, 4.0), .28, 4.8, 'navy', vertices=8, radius2=.22)
    for z in (1.55, 6.45):
        a.cylinder('Root', (0, 0, z), .42, .2, 'gold', vertices=8)
    lathe(a, 'Root', [(.22, 6.5), (.4, 6.75), (.62, 6.85), (.62, 6.95), (0, 6.98)], 'navy', segments=8)
    # curled brackets under the lantern
    for t in (0, pi / 2, pi, 3 * pi / 2):
        d = Vector((cos(t), sin(t), 0))
        pts = [tuple(d * (.25 + .3 * k / 5) + Vector((0, 0, 6.0 + .9 * (k / 5) ** .7))) for k in range(6)]
        a.tube('Root', pts, .06, 'gold', mode='palette', sides=4)
    lantern(a, 6.98, .95)
    return a.finish()


def wall_lantern():
    """Rampart lantern, 6.5 studs: a stone pier with a gold band carrying a small carriage lantern."""
    a = Asset('props/v2/wall_lantern', budget=2000)
    a.box('Root', (0, 0, .9), (1.8, 1.8, 1.8), 'stone', bevel=.12)
    a.box('Root', (0, 0, 2.6), (1.35, 1.35, 1.8), 'stone', bevel=.1)
    a.box('Root', (0, 0, 3.6), (1.6, 1.6, .25), 'gold', bevel=.05)
    lantern(a, 3.72, .8)
    return a.finish()


# ---- outer tree belt ---------------------------------------------------------------------------------------------------

def trunk(a, rng, height, radius, lean=.0, branches=3):
    pts = []
    for k in range(7):
        f = k / 6
        pts.append((lean * f * f * height * .3 + rng.uniform(-.1, .1) * f, rng.uniform(-.1, .1) * f, f * height))
    for k in range(6):
        a.between('Root', pts[k], pts[k + 1], radius * (1 - .45 * k / 6), 'bark', vertices=7, radius2=radius * (1 - .45 * (k + 1) / 6))
    # root flare
    for i in range(5):
        t = tau * i / 5 + rng.uniform(-.2, .2)
        a.between('Root', (radius * .3 * cos(t), radius * .3 * sin(t), radius * 1.2), (radius * 1.6 * cos(t), radius * 1.6 * sin(t), -.1), radius * .35, 'bark', vertices=5, radius2=radius * .12)
    tips = []
    for i in range(branches):
        t = tau * i / branches + rng.uniform(-.4, .4)
        z0 = height * rng.uniform(.6, .8)
        start = Vector((pts[4][0], pts[4][1], z0))
        end = start + Vector((cos(t), sin(t), 0)) * height * .32 + Vector((0, 0, height * .25))
        a.between('Root', tuple(start), tuple(end), radius * .38, 'bark', vertices=5, radius2=radius * .2)
        tips.append(end)
    return Vector(pts[-1]), tips


def round_tree(n):
    """Broadleaf for the outer belt (~30 studs): curving trunk with branches, canopy of chiselled leaf clumps."""
    a = Asset(f'trees/v2/round_{n}', budget=3000); rng = random.Random(900 + n)
    top, tips = trunk(a, rng, 14 + n * 2, 1.3, lean=rng.uniform(-.3, .3))
    leaf = 'leaf_a' if n % 2 == 0 else 'leaf_b'
    boulder(a, 'Canopy', 1000 + n, tuple(top + Vector((0, 0, -1.5))), (13, 12, 10), leaf, rot_z=rng.uniform(0, tau), cuts=10, subdiv=2)
    for i, tip in enumerate(tips):
        s = rng.uniform(7, 9)
        boulder(a, 'Canopy', 1010 + n * 10 + i, tuple(tip + Vector((0, 0, -2))), (s, s * .95, s * .8), leaf, rot_z=rng.uniform(0, tau), cuts=8, subdiv=2)
    s = rng.uniform(6, 7.5)
    boulder(a, 'Canopy', 1050 + n, tuple(top + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 5))), (s, s, s * .85), leaf, rot_z=rng.uniform(0, tau), cuts=8, subdiv=2)
    return a.finish()


def pine_tree(n):
    """Pine for the outer belt (~32 studs): straight trunk, four drooping tiers with ragged hems and a spire."""
    a = Asset(f'trees/v2/pine_{n}', budget=3000); rng = random.Random(950 + n)
    a.cylinder('Root', (0, 0, 4), 1.0, 8, 'bark', vertices=7, radius2=.6)
    z, r = 6.0, 7.5 - n * .5
    for i in range(4):
        h = 8.5 - i * 1.3
        verts, faces = [], []
        k = 10
        for j in range(k):
            t = tau * j / k + rng.uniform(-.08, .08)
            rr = r * rng.uniform(.88, 1.06)
            verts.append((rr * cos(t), rr * sin(t), z + rng.uniform(-.5, .3)))
        verts.append((0, 0, z + h)); top = k
        verts.append((0, 0, z + 1.0)); bottom = k + 1
        for j in range(k):
            faces.append((j, (j + 1) % k, top))
            faces.append(((j + 1) % k, j, bottom))
        a.mesh('Canopy', verts, faces, 'leaf_pine')
        z += h * .55; r *= .74
    a.cylinder('Canopy', (0, 0, z + 1.5), 1.2, 3.5, 'leaf_pine', vertices=6, radius2=.05)
    return a.finish()


def palm_tree(n):
    """Palm for the lagoon islands (~24 studs): ringed, curving trunk, coconuts and eight arched fronds."""
    a = Asset(f'trees/v2/palm_{n}', budget=3000); rng = random.Random(980 + n)
    lean = .35 + .15 * n
    pts = [Vector((lean * (k / 9) ** 2 * 8, 0, k * 2.2)) for k in range(10)]
    for k in range(9):
        a.between('Root', tuple(pts[k]), tuple(pts[k + 1] + Vector((0, 0, .1))), .95 - .04 * k, 'palm_bark', vertices=7, radius2=.85 - .04 * k)
        a.cylinder('Root', tuple(pts[k + 1]), .98 - .04 * k, .3, 'palm_bark', vertices=7)
    top = pts[-1]
    for i in range(3):
        t = tau * i / 3
        a.ellipsoid('Root', tuple(top + Vector((.6 * cos(t), .6 * sin(t), -.6))), (.9, .9, 1.0), 'wood', segments=7, rings=5)
    for i in range(8):
        t = tau * i / 8 + rng.uniform(-.15, .15)
        d = Vector((cos(t), sin(t), 0)); side = Vector((-sin(t), cos(t), 0))
        length = rng.uniform(8, 10)
        spine = [top + d * length * f + Vector((0, 0, 2.2 * sin(pi * f * .8) - 3.2 * f * f)) for f in (0, .2, .4, .6, .8, 1)]
        verts, faces = [], []
        for k, p in enumerate(spine):
            w = 1.5 * sin(pi * min(1, (k + .4) / len(spine)))
            droop = Vector((0, 0, -.35 * w))
            verts += [tuple(p + side * w + droop), tuple(p + Vector((0, 0, .18))), tuple(p - side * w + droop)]
        m = len(verts)
        verts += [(x, y, z - .15) for x, y, z in verts]  # underside: Roblox MeshParts are single-sided
        for k in range(len(spine) - 1):
            b = k * 3
            faces += [(b, b + 3, b + 4, b + 1), (b + 1, b + 4, b + 5, b + 2)]
            faces += [(m + b + 1, m + b + 4, m + b + 3, m + b), (m + b + 2, m + b + 5, m + b + 4, m + b + 1)]
        for k in range(len(spine) - 1):  # close the two long edges
            b = k * 3
            faces += [(b + 3, b, m + b, m + b + 3), (b + 2, b + 5, m + b + 5, m + b + 2)]
        bm_obj = a.mesh('Canopy', verts, faces, 'palm_leaf')
    return a.finish()


BUILDERS.update({
    'props/v2/street_lamp': street_lamp,
    'props/v2/wall_lantern': wall_lantern,
    **{f'trees/v2/round_{n}': (lambda n=n: round_tree(n)) for n in range(3)},
    **{f'trees/v2/pine_{n}': (lambda n=n: pine_tree(n)) for n in range(2)},
    **{f'trees/v2/palm_{n}': (lambda n=n: palm_tree(n)) for n in range(2)},
})

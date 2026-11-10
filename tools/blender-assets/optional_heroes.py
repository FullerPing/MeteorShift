"""Optional map landmarks. Import only; execute individual BUILDERS entries."""
from assetlib import *
from math import sin, cos, pi
from mathutils import Vector, Matrix


def hero(name):
    a = Asset('map/' + name, budget=8000, pivot=(0, 0, 0))
    a.meta.update({'Optional': True, 'Front': '-Y', 'Pivot': 'BottomCentre'})
    return a


def silhouette(a, group, points, depth, color, y=0, mode='palette', bevel=.08):
    ob = a.poly(group, points, depth, color, mode, bevel)
    ob.location.y = y
    return ob


def lathe(a, group, profile, color, n=20, mode='palette'):
    """Closed radial profile, including hollow openings when specified."""
    verts = [(r*cos(i*2*pi/n), r*sin(i*2*pi/n), z)
             for r, z in profile for i in range(n)]
    faces = []
    for j in range(len(profile)):
        k = (j+1) % len(profile)
        for i in range(n):
            ni = (i+1) % n
            faces.append((j*n+i, j*n+ni, k*n+ni, k*n+i))
    return a.mesh(group, verts, faces, color, mode, bevel=.055)


def fit(a, size):
    """Fit whole landmark to supplied XYZ extent, preserving bottom origin.

    Used only for roof ornaments whose diagonals make bounds nontrivial.
    Object rotations are baked around their proper local origins first.
    """
    bpy.context.view_layer.update()
    objects = [o for parts in a.groups.values() for o in parts]
    pts = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    lo = Vector([min(p[k] for p in pts) for k in range(3)])
    hi = Vector([max(p[k] for p in pts) for k in range(3)])
    scale = Vector([size[k]/(hi[k]-lo[k]) for k in range(3)])
    center = Vector(((hi.x+lo.x)/2, (hi.y+lo.y)/2, lo.z))
    for ob in objects:
        ob.data.transform(ob.matrix_world)
        ob.matrix_world = Matrix.Identity(4)
        for v in ob.data.vertices:
            v.co = Vector([(v.co[k]-center[k])*scale[k] for k in range(3)])


def crossed_pickaxes():
    a = hero('CrossedPickaxes')
    for s in [-1, 1]:
        # Transform full pickaxe in the XZ plane, including every band and head.
        parts_before = len(a.groups['CrossedPickaxes'])
        a.cylinder('CrossedPickaxes', (0, 0, 4.5), .3, 9, 'wood', vertices=10)
        for z in [.4, .8, 1.2, 7.3]:
            a.cylinder('CrossedPickaxes', (0, 0, z), .35, .16, 'equipment_dark', vertices=10)
        outline = [(-3.2, 7.6), (-2.3, 9.05), (-.55, 9.5),
                   (.55, 9.5), (2.4, 9.02), (3.3, 7.65),
                   (1.85, 8.26), (.35, 8.53), (-.45, 8.53), (-1.9, 8.25)]
        silhouette(a, 'CrossedPickaxes', outline, .48, 'steel', bevel=.12)
        # Contrasting face plates: ice-blue front and gold reverse.
        for y, col in [(-.32, 'frost'), (.32, 'gold')]:
            silhouette(a, 'CrossedPickaxes',
                       [(-3.13, 7.66), (-1.9, 8.25), (-.45, 8.53),
                        (.35, 8.53), (1.85, 8.26), (3.2, 7.71),
                        (2.15, 8.68), (.4, 9.05), (-.45, 9.05), (-2.2, 8.68)],
                       .17, col, y=y, bevel=.055)
        a.box('CrossedPickaxes', (0, 0, 8.83), (.8, .98, 1.1), 'equipment_dark', bevel=.12)
        angle = s*.58
        transform = Matrix.Translation((s*.55, s*.35, .4)) @ Matrix.Rotation(angle, 4, 'Y')
        bpy.context.view_layer.update()
        for ob in a.groups['CrossedPickaxes'][parts_before:]:
            ob.matrix_world = transform @ ob.matrix_world
    fit(a, (14, 2, 12))
    return a.finish()


def gold_coin_sign():
    a = hero('GoldCoinSign')
    a.cylinder('GoldCoinSign', (0, 0, 4.8), 4.8, .9, 'gold', vertices=32, rot=(pi/2, 0, 0))
    for y in [-.5, .5]:
        a.ring('GoldCoinSign', (0, y, 4.8), 4.29, .16, 'equipment_gold', segments=32, sides=6)
        points = []
        for i in range(10):
            theta = pi/2+i*pi/5
            r = 2.6 if i % 2 == 0 else 1.25
            points.append((cos(theta)*r, 4.8+sin(theta)*r))
        silhouette(a, 'GoldCoinSign', points, .12, 'cream', y=y*1.13, bevel=.05)
    for i in range(24):
        theta = i*2*pi/24
        a.box('GoldCoinSign', (4.64*cos(theta), 0, 4.8+4.64*sin(theta)),
              (.14, .69, .31), 'equipment_gold', bevel=.04,
              rot=(0, pi/2-theta, 0))
    return a.finish()


def rebirth_portal():
    a = hero('RebirthPortal')
    a.meta['InnerDisc'] = 'Keep existing Roblox glowing part; opening is empty'
    a.box('RebirthPortal', (0, 0, .8), (11, 5.4, 1.6), 'gold', bevel=.45)
    a.box('RebirthPortal', (0, 0, 1.65), (7.7, 3.6, .6), 'equipment_gold', bevel=.2)
    a.ring('RebirthPortal', (0, 0, 12), 10, 1, 'gold', segments=40, sides=8)
    a.ring('RebirthPortal', (0, -.86, 12), 9.97, .13, 'equipment_gold', segments=40, sides=5)
    # Five white collars wrap across the gold ring, leaving the aperture clear.
    for i in range(5):
        t = pi/2+i*2*pi/5
        a.box('RebirthPortal', (10*cos(t), 0, 12+10*sin(t)),
              (.61, 2.08, 2.12), 'white', bevel=.12,
              rot=(0, pi/2-t, 0))
    return a.finish()


def meteor_statue():
    a = hero('MeteorStatue')
    lathe(a, 'MeteorStatue', [(8.8, 0), (9.5, .6), (9.05, 1.5),
                             (7.7, 2.05), (6.65, 1.3), (4.7, .6), (0, .4)], 'stone', 24)
    a.ico('MeteorStatue', (0, .2, 6.5), (15, 13, 11.3), 'navy', subdivisions=2, seed=72)
    # The base obscures the underside: the meteor reads as half embedded.
    fissures = [[(-5.6, -3.9, 7.5), (-3.9, -5.6, 6.4), (-2.7, -6.1, 7.7), (-.9, -6.2, 6.2), (1.1, -6.1, 5.8)],
                [(1.1, -6.1, 5.8), (2.6, -5.8, 7.1), (4.8, -4.3, 7.9)],
                [(-.9, -6.2, 6.2), (-1.8, -5.7, 3.7), (-.5, -5.1, 2.5)],
                [(2.6, -5.8, 7.1), (1.7, -4.9, 9.2), (3.1, -3.3, 10.1)]]
    for points in fissures:
        a.tube('Glow', points, .16, 'orange', mode='neon', sides=5)
    # Broad sweeping flames behind the rock, rather than smoke particles.
    silhouette(a, 'MeteorStatue', [(-4, 8), (-3.3, 12), (-.8, 15.2), (4.2, 19.6),
                                  (3.1, 15.5), (5.3, 16.5), (3.8, 12.1),
                                  (6, 12.8), (4.5, 8)], 2.2, 'orange', y=4.4, bevel=.18)
    silhouette(a, 'Glow', [(-2.2, 10), (-.9, 13.6), (2.9, 17.7),
                           (1.6, 13.6), (3, 13.8), (2.1, 10)],
               .2, 'warm_glow', y=3.2, mode='neon', bevel=.08)
    a.box('MeteorStatue', (0, -7.15, 1.25), (6, 1.1, 1.3), 'navy', bevel=.15)
    # Emblem plaque is deliberately text-free; map supplies the landmark label.
    silhouette(a, 'MeteorStatue', [(0, 1.85), (.65, 1.25), (0, .7), (-.65, 1.25)],
               .1, 'equipment_gold', y=-7.76, bevel=.045)
    return a.finish()


def telescope():
    a = hero('Telescope')
    a.cylinder('Telescope', (0, 0, .35), 2.6, .7, 'navy', vertices=16)
    for theta in [pi/6, 5*pi/6, 3*pi/2]:
        end = (2.1*cos(theta), 2.1*sin(theta), .7)
        a.between('Telescope', (0, 0, 4), end, .23, 'equipment_gold', vertices=8)
    a.cylinder('Telescope', (0, 0, 3.5), .44, 2.1, 'gold', vertices=12)
    a.box('Telescope', (0, 0, 4.5), (2.2, 1.3, 1.1), 'gold', bevel=.18)
    rear = Vector((3.7, 0, 4.55)); direction = Vector((-1, 0, .29)).normalized()
    front = rear+direction*11
    a.between('Telescope', rear, rear+direction*1.5, .42, 'equipment_dark', vertices=16)
    a.between('Telescope', rear+direction*1.3, front, .85, 'gold', vertices=20, radius2=1.38)
    for distance, radius in [(1.5, .91), (4.4, 1.08), (8.4, 1.33), (10.7, 1.5)]:
        point = rear+direction*distance
        a.between('Telescope', point-direction*.17, point+direction*.17,
                  radius, 'equipment_gold', vertices=20)
    # Dark inset objective with a pale blue glass disc at the very front.
    a.between('Telescope', front-direction*.23, front, 1.3, 'equipment_dark', vertices=20)
    a.between('Telescope', front+direction*.01, front+direction*.035, 1.08, 'glass', vertices=20)
    for s in [-1, 1]:
        a.cylinder('Telescope', (0, s*.88, 4.95), .48, .35, 'equipment_gold',
                   vertices=12, rot=(pi/2, 0, 0))
    return a.finish()


def refinery_chimney():
    a = hero('RefineryChimney')
    a.meta['Smoke'] = 'Particle effect supplied by Roblox; no smoke geometry'
    a.box('RefineryChimney', (0, 0, .5), (4, 4, 1), 'navy', bevel=.18)
    for i in range(6):
        radius = 1.7-i*.065
        a.cylinder('RefineryChimney', (0, 0, 1.9+i*1.8), radius, 1.8,
                   'red' if i % 2 == 0 else 'white', vertices=16, radius2=radius-.065)
    # An open soot-dark throat under a suspended rain/smoke cap.
    lathe(a, 'RefineryChimney', [(1.42, 11.8), (1.56, 12), (1.56, 12.3),
                               (1.05, 12.3), (1.05, 11.8)], 'navy', 16)
    for x in [-1.04, 1.04]:
        a.between('RefineryChimney', (x, 0, 12.1), (x, 0, 13.3), .1, 'steel', vertices=8)
    a.cylinder('RefineryChimney', (0, 0, 13.55), 1.95, .9, 'steel', vertices=16, radius2=.55)
    return a.finish()


def crane():
    a = hero('Crane')
    for s in [-1, 1]:
        a.box('Crane', (s*23.6, 0, .65), (4.8, 5, 1.3), 'navy', bevel=.2)
        a.box('Crane', (s*23.6, 0, 13.4), (1.45, 3.1, 24.6), 'orange', bevel=.14)
        a.between('Crane', (s*23.6, 0, 18.3), (s*17.2, 0, 25.4),
                  .4, 'orange', vertices=8)
        for z in [3.2, 7.3, 11.4, 15.5]:
            a.box('Crane', (s*23.6, -1.62, z), (1.7, .15, .6), 'equipment_dark', bevel=.035)
    # Open truss web provides a strong gantry silhouette at low triangle cost.
    for z in [24.8, 27.4]:
        a.box('Crane', (0, 0, z), (52, 3.5, 1.2), 'orange', bevel=.16)
    for i in range(12):
        x = -25.2+i*4.2
        a.between('Crane', (x, 0, 25.35), (x+4.2, 0, 26.85), .18, 'equipment_gold', vertices=6)
        a.between('Crane', (x, 0, 26.85), (x+4.2, 0, 25.35), .18, 'orange', vertices=6)
    a.box('Trolley', (5, 0, 23.75), (4.5, 3.9, 1.4), 'navy', bevel=.2)
    for x in [3.5, 6.5]:
        for y in [-1.75, 1.75]:
            a.cylinder('Trolley', (x, y, 24.4), .47, .36, 'steel', vertices=10, rot=(pi/2, 0, 0))
    a.box('Trolley', (5, 0, 22.9), (2.1, 2.1, .7), 'orange', bevel=.12)
    a.joint('Trolley', (5, 0, 23.75))
    for x in [4.4, 5.6]:
        a.between('Bucket', (x, 0, 22.55), (x, 0, 11.1), .085, 'equipment_dark', vertices=6)
    a.ring('Bucket', (5, 0, 10.8), .65, .15, 'steel', segments=16, sides=5)
    for x in [2.9, 7.1]:
        a.between('Bucket', (5, 0, 10.6), (x, 0, 8.4), .16, 'steel', vertices=8)
    a.box('Bucket', (5, 0, 5.1), (4.7, 3.5, .45), 'rust', bevel=.12)
    for x in [2.65, 7.35]:
        a.box('Bucket', (x, 0, 6.7), (.32, 3.5, 3.2), 'orange', bevel=.1)
    for y in [-1.65, 1.65]:
        a.box('Bucket', (5, y, 6.7), (4.9, .28, 3.2), 'orange', bevel=.1)
        a.box('Bucket', (5, y*1.1, 6.3), (4.65, .1, .4), 'equipment_dark', bevel=.025)
    for i, (x, y, z) in enumerate([(3.6, -.4, 8), (5, .45, 8.2), (6.4, -.4, 8.1)]):
        a.ico('Bucket', (x, y, z), (1.8, 1.7, 1.7), 'stone', seed=90+i)
    a.joint('Bucket', (5, 0, 22.55))
    return a.finish()


def ice_cave():
    a = hero('IceCave')
    # One continuous irregular arch with a genuinely open entrance.
    outline = [(-18, 0), (-17.5, 9), (-15, 16), (-10, 21), (-4, 24),
               (3, 24), (10, 21.5), (15.5, 16), (18, 8), (18, 0),
               (10.5, 0), (10.2, 8), (7.6, 13), (3.5, 16.5),
               (-2.5, 17), (-7.2, 14), (-10, 8), (-10.5, 0)]
    silhouette(a, 'IceCave', outline, 9, 'frost', bevel=.28)
    # Snow only caps the ridge, preserving the walk-through aperture.
    silhouette(a, 'IceCave', [(-15.1, 16.4), (-10, 22), (-4, 25),
                              (3.1, 25), (10.2, 22.2), (15.7, 16.3),
                              (12, 17.8), (8, 20.3), (1, 22.4),
                              (-5, 22.2), (-10, 19.5)], 8.6, 'white', bevel=.22)
    for x, top, length, radius in [(-9, 12.3, 3.4, .67), (-6.1, 15.9, 4.7, .75),
                                   (-2.6, 17, 2.9, .65), (1, 17, 4.1, .8),
                                   (4.5, 16, 3.1, .68), (7.5, 13, 4.4, .73)]:
        a.between('IceCave', (x, -3.9, top), (x, -4.1, top-length), radius,
                  'glass', vertices=6, radius2=0)
    for s in [-1, 1]:
        silhouette(a, 'IceCave', [(s*12, 2), (s*16, 4), (s*15.4, 12),
                                  (s*12.8, 15), (s*12.1, 8)],
                   .18, 'glass', y=-4.58, bevel=.09)
    return a.finish()


def crystal(a, x, y, height, radius, tilt):
    base = Vector((x, y, 1.7)); n = 6
    top = base+Vector((tilt, 0, height))
    shoulder = base+Vector((tilt*.78, 0, height*.77))
    verts = []
    for center in [base, shoulder]:
        verts.extend([tuple(center+Vector((radius*cos(i*2*pi/n), radius*sin(i*2*pi/n), 0))) for i in range(n)])
    faces = [tuple(reversed(range(n)))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    a.mesh('CrystalCluster', verts, faces, 'violet', bevel=.09)
    tipverts = verts[n:] + [tuple(top)]
    a.mesh('Glow', tipverts, [tuple(reversed(range(n)))] + [(i, (i+1)%n, n) for i in range(n)],
           'pink', mode='neon', bevel=.06)
    # Crisp long pale edge facet conveys stylised glass, without PBR transparency.
    a.between('CrystalCluster', base+Vector((-.4, -radius*.89, .8)),
              shoulder+Vector((-.4, -radius*.89, -.5)), .14, 'glass', vertices=5)


def crystal_cluster():
    a = hero('CrystalCluster')
    a.cylinder('CrystalCluster', (0, 0, .7), 1, 1.4, 'navy', vertices=12)
    # An irregular flat 30-by-12 plinth anchors five distinct-height spires.
    silhouette(a, 'CrystalCluster', [(-15, 0), (15, 0), (14.6, 1.8),
                                     (10, 2.4), (-9, 2.2), (-14.5, 1.4)],
               12, 'navy', bevel=.2)
    for args in [(-10.8, 0, 17.5, 2.6, -1.3), (-5.9, 1.5, 25, 3.2, -1.5),
                 (0, 0, 32.3, 3.8, .4), (6, 1, 23.8, 3.15, 1.1), (10.7, -.6, 16, 2.5, 1.6)]:
        crystal(a, *args)
    return a.finish()


def sulfur_vent():
    a = hero('SulfurVent')
    lathe(a, 'SulfurVent', [(5.3, 0), (6, 1), (5.1, 3), (4.3, 5.5),
                          (3.35, 9), (2.7, 12.1), (1.6, 12.1),
                          (1.4, 10.9), (0, 10.4)], 'rust', 16)
    # Broken yellow mineral crust sits over the upper rim and cascades down ribs.
    lathe(a, 'SulfurVent', [(2.84, 11.4), (2.8, 12.6), (2.1, 13),
                          (1.45, 12.45), (1.48, 11.8)], 'sulfur', 16)
    a.cylinder('Glow', (0, 0, 11.85), 1.46, .1, 'warm_glow', mode='neon', vertices=16)
    for i in range(7):
        t = i*2*pi/7
        a.tube('SulfurVent', [(2.65*cos(t), 2.65*sin(t), 11.8),
                              (3.1*cos(t+.04), 3.1*sin(t+.04), 9.5),
                              (4.15*cos(t-.03), 4.15*sin(t-.03), 6.2)],
               .24, 'sulfur', mode='palette', sides=5)
    for i in range(8):
        t = i*2*pi/8
        a.ico('SulfurVent', (4.7*cos(t), 4.7*sin(t), .8), (1.9, 1.65, 1.6),
              'sulfur' if i % 3 == 0 else 'stone', seed=110+i)
    return a.finish()


def snowman():
    a = hero('Snowman')
    a.ellipsoid('Snowman', (0, 0, 3.45), (7, 7, 6.9), 'white', segments=16, rings=10)
    a.ellipsoid('Snowman', (0, 0, 8.2), (5.5, 5.4, 5.6), 'white', segments=16, rings=10)
    a.ellipsoid('Snowman', (0, 0, 12), (4.4, 4.3, 4.4), 'white', segments=16, rings=10)
    # Hat, scarf, carrot, eyes, grin and three coal buttons read at map scale.
    a.cylinder('Snowman', (0, 0, 14.15), 2.95, .36, 'ink', vertices=16)
    a.cylinder('Snowman', (0, 0, 15.54), 1.97, 2.56, 'navy', vertices=16, radius2=2.05)
    a.cylinder('Snowman', (0, 0, 14.73), 2.01, .55, 'red', vertices=16)
    a.ring('Snowman', (0, 0, 10.15), 2.05, .35, 'red', axis='Z', segments=20, sides=6)
    a.box('Snowman', (.9, -2.47, 8.74), (.79, .31, 2.8), 'red', bevel=.15, rot=(0, -.12, 0))
    for z in [7.6, 7.88]:
        a.box('Snowman', (1.02, -2.66, z), (.78, .05, .14), 'cream', bevel=.025)
    for x in [-.73, .73]:
        a.ellipsoid('Snowman', (x, -1.92, 12.53), (.4, .35, .44), 'ink', segments=8, rings=4)
    a.between('Snowman', (0, -2.04, 12), (0, -3.36, 11.86), .33, 'orange', vertices=8, radius2=.025)
    for x, z in [(-.83, 11.58), (-.43, 11.37), (0, 11.3), (.43, 11.37), (.83, 11.58)]:
        a.ellipsoid('Snowman', (x, -1.91, z), (.23, .25, .23), 'ink', segments=8, rings=4)
    for z, y in [(9, -2.56), (7.9, -2.69), (6.9, -2.5)]:
        a.ellipsoid('Snowman', (0, y, z), (.42, .31, .43), 'ink', segments=8, rings=4)
    # Short bent twigs stay within the specified seven-stud silhouette.
    for s in [-1, 1]:
        a.between('Snowman', (s*2.3, 0, 8.5), (s*3.22, -.25, 9.35), .15, 'wood', vertices=7)
        a.between('Snowman', (s*3.22, -.25, 9.35), (s*3.25, -.2, 10.25), .12, 'wood', vertices=7)
        a.between('Snowman', (s*3.22, -.25, 9.35), (s*3.35, -.75, 9.85), .1, 'wood', vertices=7)
    return a.finish()


BUILDERS = {
    'map/CrossedPickaxes': crossed_pickaxes,
    'map/GoldCoinSign': gold_coin_sign,
    'map/RebirthPortal': rebirth_portal,
    'map/MeteorStatue': meteor_statue,
    'map/Telescope': telescope,
    'map/RefineryChimney': refinery_chimney,
    'map/Crane': crane,
    'map/IceCave': ice_cave,
    'map/CrystalCluster': crystal_cluster,
    'map/SulfurVent': sulfur_vent,
    'map/Snowman': snowman,
}

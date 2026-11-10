"""Sixteen equipment meshes, authored in studs and relative to equip pivots.

Run individual BUILDERS entries through the asset pipeline; importing is inert.
"""
from assetlib import *
from math import sin, cos, pi
from mathutils import Vector


TIER = ['#96969B', '#BECDDC', '#FFB030', '#50DCFF',
        '#FF6028', '#BA6CFF', '#281E3C', '#FF78DC']


def plate(a, group, points, depth, color, y=0, mode='palette', bevel=.025):
    ob = a.poly(group, points, depth, color=color, mode=mode, bevel=bevel)
    ob.location.y += y
    return ob


def diamond(a, group, x, y, z, w, h, depth, color, mode='palette'):
    return plate(a, group, [(x, z+h/2), (x+w/2, z),
                           (x, z-h/2), (x-w/2, z)], depth, color, y, mode)


def tilt_at_center(ob, center, rotation):
    """Asset.ring stores world coordinates; tilt around its own center."""
    center = Vector(center)
    for vertex in ob.data.vertices:
        vertex.co -= center
    ob.location = center
    ob.rotation_euler = rotation
    return ob


def star(a, group, x, y, z, radius, inner, points, color, mode='palette'):
    outline = []
    for i in range(points * 2):
        t = pi/2 + i*pi/points
        r = radius if i % 2 == 0 else inner
        outline.append((x + cos(t)*r, z + sin(t)*r))
    return plate(a, group, outline, .15, color, y, mode, .015)


def shaft(a, tier):
    """Bottom -1.4; origin is the hand grip, exactly 1.4 above bottom."""
    color = 'wood' if tier == 1 else 'equipment_dark'
    a.cylinder('Shaft', (0, 0, .6), .135, 3.9, color, vertices=10)
    a.cylinder('Shaft', (0, 0, -1.28), .19, .24, 'equipment_dark', vertices=10)
    a.cylinder('Shaft', (0, 0, 0), .175, .88, 'equipment_dark', vertices=10)
    for z in [-.38, -.12, .14, .4]:
        a.cylinder('Shaft', (0, 0, z), .183, .055,
                   'wood' if tier == 1 else 'steel', vertices=10)
    a.cylinder('Accent', (0, 0, 1.76), .174, .23, TIER[tier-1],
               mode='tint', vertices=10)
    a.cylinder('Accent', (0, 0, -1.1), .163, .1, TIER[tier-1],
               mode='tint', vertices=10)


def pick(tier):
    a = Asset('equipment/pickaxe_t%d' % tier, budget=3000, pivot=(0, 0, 0))
    a.meta.update({'Tier': tier, 'EquipmentPivot': 'Grip',
                   'GripHeightAboveBottom': 1.4, 'TintColor': TIER[tier-1]})
    shaft(a, tier)
    return a


def pickaxe_t1():
    a = pick(1)
    # Asymmetric hooked point and compact hammer give the starter its own shape.
    plate(a, 'Head', [(-1.92, 1.96), (-1.58, 2.72), (-.83, 3.03),
                     (.27, 2.98), (.38, 2.52), (-.76, 2.6), (-1.43, 2.36)],
          .4, 'stone', bevel=.045)
    a.box('Head', (.78, 0, 2.75), (1.2, .51, .5), 'steel', bevel=.075)
    a.box('Head', (1.38, 0, 2.75), (.3, .65, .66), 'stone', bevel=.07)
    a.box('Head', (0, 0, 2.68), (.48, .62, .65), 'equipment_dark', bevel=.07)
    diamond(a, 'Accent', 0, -.335, 2.75, .27, .34, .07, TIER[0], 'tint')
    return a.finish()


def pickaxe_t2():
    a = pick(2)
    for s in [-1, 1]:
        plate(a, 'Head', [(s*.15, 2.92), (s*.94, 3.13), (s*1.55, 2.93),
                         (s*1.92, 2.28), (s*1.12, 2.65), (s*.18, 2.53)],
              .34, 'steel', bevel=.035)
        plate(a, 'Head', [(s*.5, 2.7), (s*1.12, 2.65), (s*1.92, 2.28),
                         (s*1.6, 2.79), (s*.66, 2.86)],
              .36, 'light_steel', bevel=.018)
        diamond(a, 'Accent', s*.72, -.2, 2.94, .3, .15, .06, TIER[1], 'tint')
    a.box('Head', (0, 0, 2.75), (.5, .6, .67), 'equipment_dark', bevel=.075)
    diamond(a, 'Head', 0, -.34, 2.78, .28, .36, .09, 'equipment_gold')
    return a.finish()


def pickaxe_t3():
    a = pick(3)
    a.cylinder('Head', (-.65, 0, 2.56), .49, 1.35, 'equipment_dark',
               vertices=12, rot=(0, pi/2, 0))
    a.cylinder('Accent', (-.62, 0, 2.56), .5, .85, TIER[2], mode='tint',
               vertices=12, rot=(0, pi/2, 0))
    a.cylinder('Head', (-1.36, 0, 2.56), .39, .16, 'steel',
               vertices=12, rot=(0, pi/2, 0))
    for x in [-.89, -.63, -.37]:
        a.box('Head', (x, -.493, 2.59), (.105, .06, .43),
              'equipment_dark', bevel=.025)
    a.cylinder('Head', (.12, 0, 2.56), .34, .34, 'steel',
               vertices=10, rot=(0, pi/2, 0))
    # Five taper steps with offset helical ridges; visually reads as a drill.
    for i in range(5):
        x = .4 + i*.28
        r = .35 - i*.058
        a.cylinder('Head', (x, 0, 2.56), r, .34,
                   'light_steel' if i % 2 == 0 else 'steel',
                   vertices=8, radius2=max(.035, r-.064), rot=(0, pi/2, 0))
        theta = i*.95
        a.between('Head', (x-.12, cos(theta)*r, 2.56+sin(theta)*r),
                  (x+.13, cos(theta+.8)*(r-.04), 2.56+sin(theta+.8)*(r-.04)),
                  .045, 'light_steel', vertices=5)
    a.between('Head', (1.65, 0, 2.56), (1.93, 0, 2.56), .105,
              'light_steel', vertices=8, radius2=0)
    a.between('Accent', (0, 0, 1.35), (-1.12, 0, 2.27), .12,
              TIER[2], mode='tint', vertices=8)
    return a.finish()


def pickaxe_t4():
    a = pick(4)
    a.box('Head', (0, 0, 2.37), (.91, .7, .79), 'equipment_dark', bevel=.11)
    a.ring('Head', (0, -.39, 2.43), .29, .07, 'steel', segments=16, sides=5)
    a.cylinder('Glow', (0, -.405, 2.43), .23, .11, 'cyan', mode='neon',
               vertices=16, rot=(pi/2, 0, 0))
    for s in [-1, 1]:
        plate(a, 'Head', [(s*.3, 2.16), (s*1.22, 2.36), (s*1.66, 3.08),
                         (s*1.4, 3.2), (s*.99, 2.65), (s*.31, 2.59)],
              .32, 'steel', bevel=.035)
        a.tube('Glow', [(s*.49, -.19, 2.43), (s*1.1, -.19, 2.55),
                        (s*1.47, -.19, 3.08)], .045, 'cyan', sides=5)
        plate(a, 'Glow', [(s*1.35, 2.87), (s*1.59, 3.19),
                         (s*1.94, 3.02), (s*1.62, 2.81)],
              .22, 'cyan', mode='neon', bevel=.025)
        a.box('Accent', (s*.34, -.4, 2.14), (.16, .08, .23),
              TIER[3], mode='tint', bevel=.025)
    return a.finish()


def pickaxe_t5():
    a = pick(5)
    a.ico('Head', (0, 0, 2.5), (1.72, .81, 1.0), '#303039', seed=4)
    shards = [[(-.5, 2.25), (-1.82, 2.1), (-1.35, 2.7), (-.45, 2.81)],
              [(-.63, 2.69), (-1.65, 3.06), (-.96, 3.13), (-.14, 2.77)],
              [(.26, 2.64), (.87, 3.15), (1.49, 3.01), (.92, 2.63)],
              [(.54, 2.3), (1.84, 2.02), (1.52, 2.74), (.56, 2.85)]]
    for outline in shards:
        plate(a, 'Head', outline, .44, '#1D202A', bevel=.035)
    a.ico('Glow', (.06, -.42, 2.51), (.49, .19, .42), '#FFBA55',
          mode='neon', seed=5)
    a.tube('Glow', [(-1.41, -.28, 2.51), (-.81, -.4, 2.6),
                    (-.4, -.44, 2.39), (.03, -.49, 2.51)], .055, '#FF6028', sides=5)
    a.tube('Glow', [(.02, -.47, 2.54), (.45, -.41, 2.77),
                    (.78, -.32, 2.55), (1.47, -.25, 2.42)], .055, '#FF6028', sides=5)
    return a.finish()


def pickaxe_t6():
    a = pick(6)
    center = 2.15
    a.ring('Head', (0, .035, center), .69, .055, 'light_steel', segments=24, sides=5)
    for i in range(6):
        theta = i*pi/3
        ux, uz = cos(theta), sin(theta)
        # Gold spear spokes taper into elongated violet faceted crystals.
        a.between('Head', (ux*.35, 0, center+uz*.35),
                  (ux*1.32, 0, center+uz*1.0), .14,
                  'equipment_gold', vertices=6, radius2=.055)
        a.between('Glow', (ux*1.09, 0, center+uz*.84),
                  (ux*1.92, 0, center+uz*1.14), .16,
                  TIER[5], mode='neon', vertices=5, radius2=0)
    star(a, 'Glow', 0, -.18, center, .64, .25, 6, TIER[5], 'neon')
    diamond(a, 'Head', 0, -.3, center, .25, .35, .11, 'white')
    return a.finish()


def pickaxe_t7():
    a = pick(7)
    z = 2.34
    a.ring('Head', (0, 0, z), .71, .115, 'steel', segments=24, sides=6)
    a.ring('Glow', (0, -.055, z), .53, .045, '#9661FF', mode='neon',
           segments=24, sides=5)
    a.ellipsoid('Accent', (0, 0, z), (.87, .77, .87), TIER[6], mode='tint',
                segments=12, rings=8)
    for s in [-1, 1]:
        plate(a, 'Head', [(s*.62, z+.23), (s*1.07, z+.72),
                         (s*1.6, z+.77), (s*1.96, z+.39), (s*1.34, z+.41),
                         (s*1.15, z-.12), (s*1.46, z-.64),
                         (s*.95, z-.45), (s*.69, z-.13)], .25, 'light_steel', bevel=.03)
        a.ellipsoid('Glow', (s*.73, -.14, z), (.23, .18, .4), 'cyan',
                    mode='neon', segments=8, rings=4)
    return a.finish()


def pickaxe_t8():
    a = pick(8)
    # Broad concave crescent and a trailing comet create an ornate asymmetric silhouette.
    plate(a, 'Head', [(-.22, 3.16), (-1.05, 3.08), (-1.53, 2.69),
                     (-1.6, 2.11), (-1.19, 1.65), (-.44, 1.52),
                     (-.87, 1.95), (-.96, 2.38), (-.73, 2.83)],
          .29, 'light_steel', bevel=.05)
    a.tube('Glow', [(-.28, -.18, 3.1), (-.78, -.18, 2.83),
                    (-1.01, -.18, 2.39), (-.91, -.18, 1.94),
                    (-.5, -.18, 1.58)], .045, TIER[7], sides=5)
    plate(a, 'Glow', [(.04, 2.44), (.76, 2.77), (1.55, 2.84),
                     (2.06, 3.12), (1.79, 2.59), (.99, 2.25), (.27, 2.12)],
          .19, TIER[7], mode='neon', bevel=.03)
    halo = a.ring('Head', (0, .06, 2.33), .79, .045, 'equipment_gold',
                  segments=24, sides=5)
    tilt_at_center(halo, (0, .06, 2.33), (.45, 0, .23))
    a.ellipsoid('Glow', (0, -.11, 2.34), (.68, .48, .68), TIER[7], mode='neon',
                segments=12, rings=6)
    star(a, 'Glow', 0, -.4, 2.39, .47, .13, 4, 'white', 'neon')
    diamond(a, 'Head', .08, -.2, 1.72, .25, .38, .14, 'equipment_gold')
    return a.finish()


def pack(tier):
    """The strap face is Y=0; the outward face projects toward negative Y."""
    a = Asset('equipment/backpack_t%d' % tier, budget=3000, pivot=(0, 0, 0))
    a.meta.update({'Tier': tier, 'EquipmentPivot': 'StrapFaceCentre',
                   'TintColor': TIER[tier-1]})
    # Open strap loops provide a recognisable worn silhouette in three-quarter view.
    for x in [-.57, .57]:
        a.tube('Body', [(x, -.11, .89), (x, .055, .69),
                        (x, .08, -.67), (x, -.11, -.94)],
               .095, 'equipment_dark', mode='palette', sides=6)
    return a


def backpack_t1():
    a = pack(1)
    a.ellipsoid('Body', (0, -.56, -.07), (1.91, 1.04, 2.43), '#A0865D',
                segments=12, rings=8)
    a.box('Body', (0, -.71, .83), (1.7, .75, .58), '#C2A978', bevel=.17)
    a.box('Body', (0, -1.04, -.57), (1.02, .22, .65), '#A0865D', bevel=.13)
    a.box('Body', (0, -1.16, -.3), (1.06, .09, .16), '#C2A978', bevel=.04)
    a.box('Body', (0, -1.105, .45), (.14, .09, .97), 'wood', bevel=.03)
    diamond(a, 'Accent', 0, -1.18, .06, .26, .28, .055, TIER[0], 'tint')
    # A few large stitches remain readable; avoid realistic fine noise.
    for s in [-1, 1]:
        for z in [-.77, -.41, -.05, .31]:
            a.between('Body', (s*.77, -.83, z-.05), (s*.85, -.79, z+.05),
                      .023, '#C2A978', vertices=5)
    return a.finish()


def backpack_t2():
    a = pack(2)
    a.box('Body', (0, -.55, -.04), (1.86, .99, 2.39), '#754229', bevel=.2)
    a.box('Body', (0, -.68, .77), (1.9, .93, .72), '#9F6337', bevel=.16)
    for x in [-.49, .49]:
        a.box('Body', (x, -1.145, .01), (.18, .11, 1.66), '#432B27', bevel=.035)
        a.box('Body', (x, -1.23, .06), (.33, .1, .35), 'equipment_gold', bevel=.035)
        a.box('Body', (x, -1.288, .06), (.19, .025, .19), '#432B27', bevel=.018)
        a.between('Body', (x-.12, -1.312, .05), (x+.12, -1.312, .05),
                  .022, 'equipment_gold', vertices=5)
    diamond(a, 'Accent', 0, -1.17, .87, .33, .28, .055, TIER[1], 'tint')
    return a.finish()


def backpack_t3():
    a = pack(3)
    a.box('Body', (0, -.51, -.14), (1.76, .88, 2.17), '#4B5A5B', bevel=.18)
    a.box('Accent', (0, -1.0, -.54), (1.28, .4, .77), TIER[2], mode='tint', bevel=.13)
    a.box('Body', (0, -1.13, -.18), (1.25, .18, .14), 'equipment_dark', bevel=.03)
    a.box('Body', (0, -1.005, .44), (.75, .13, .75), 'equipment_dark', bevel=.08)
    a.ring('Body', (0, -1.105, .46), .26, .065, 'equipment_gold', segments=16, sides=5)
    a.cylinder('Glow', (0, -1.135, .46), .215, .075, 'warm_glow', mode='neon',
               vertices=16, rot=(pi/2, 0, 0))
    a.cylinder('Body', (0, -.54, 1.02), .31, 1.97, '#C2A978',
               vertices=12, rot=(0, pi/2, 0))
    for x in [-.59, .59]:
        a.cylinder('Body', (x, -.54, 1.02), .323, .11, 'wood',
                   vertices=12, rot=(0, pi/2, 0))
    a.ring('Body', (1.0, -.54, 1.02), .19, .035, 'wood', axis='X', segments=12, sides=4)
    a.box('Body', (-.96, -.59, -.27), (.35, .63, .92), 'equipment_dark', bevel=.09)
    return a.finish()


def backpack_t4():
    a = pack(4)
    a.box('Body', (0, -.55, 0), (1.89, 1.04, 2.45), 'equipment_dark', bevel=.16)
    a.box('Body', (0, -1.05, 0), (1.53, .2, 2.03), 'steel', bevel=.1)
    for x in [-.86, .86]:
        a.box('Body', (x, -1.075, 0), (.16, .22, 2.08), 'light_steel', bevel=.04)
    for z in [-.55, 0, .55]:
        a.box('Body', (0, -1.22, z), (1.5, .13, .14), 'equipment_dark', bevel=.035)
    a.box('Glow', (0, -1.2, .85), (.83, .08, .14), 'cyan', mode='neon', bevel=.025)
    for x in [-.5, .5]:
        a.box('Accent', (x, -1.18, -.84), (.25, .08, .19), TIER[3], mode='tint', bevel=.03)
    return a.finish()


def backpack_t5():
    a = pack(5)
    # Hollow open ore bin: four walls, floor, and a lowered front lip.
    a.box('Body', (0, -.56, -1.06), (1.7, 1.03, .22), '#624431', bevel=.06)
    a.box('Body', (0, -.08, -.13), (1.7, .18, 1.99), '#624431', bevel=.06)
    a.box('Body', (0, -1.04, -.34), (1.7, .15, 1.59), '#624431', bevel=.065)
    for s in [-1, 1]:
        a.box('Body', (s*.8, -.56, -.13), (.18, .92, 2.0), '#624431', bevel=.06)
        a.box('Body', (s*.92, -.58, -.46), (.31, .73, 1.11), 'equipment_dark', bevel=.08)
        a.between('Body', (s*.86, -1.12, -1.12), (s*.86, -1.12, .9),
                  .09, 'equipment_gold', vertices=8)
    for z in [-.87, -.39, .1]:
        a.box('Body', (0, -1.145, z), (1.72, .08, .11), 'steel', bevel=.025)
    for i, (x, y, z, scale) in enumerate([(-.5, -.56, .79, .63),
                                         (.11, -.49, .94, .69),
                                         (.57, -.5, .68, .58),
                                         (-.13, -.82, .59, .57)]):
        a.ico('Accent', (x, y, z), (scale, scale*.8, scale), TIER[4],
              mode='tint', seed=10+i)
    return a.finish()


def backpack_t6():
    a = pack(6)
    a.box('Body', (0, -.34, 0), (1.98, .55, 2.62), 'equipment_dark', bevel=.08)
    for x in [-.54, .54]:
        for z in [-.62, .62]:
            a.box('Body', (x, -.77, z), (.91, .77, 1.06), 'steel', bevel=.11)
            a.box('Body', (x, -1.175, z+.19), (.68, .075, .13), 'light_steel', bevel=.025)
            a.box('Glow', (x, -1.21, z-.19), (.38, .09, .13), TIER[5], mode='neon', bevel=.025)
    for s in [-1, 1]:
        a.between('Body', (s*1.13, -.52, 1.43), (s*1.13, -.58, -1.43),
                  .105, 'equipment_gold', vertices=8)
        a.box('Body', (s*1.13, -.63, -1.45), (.3, .45, .18), 'equipment_gold', bevel=.04)
    a.box('Accent', (0, -1.17, 0), (.12, .09, 2.4), TIER[5], mode='tint', bevel=.02)
    return a.finish()


def backpack_t7():
    a = pack(7)
    a.box('Body', (0, -.42, 0), (1.74, .76, 2.44), 'equipment_dark', bevel=.18)
    a.ring('Body', (0, -.95, .1), .77, .105, 'steel', segments=24, sides=6)
    a.ring('Glow', (0, -1.005, .1), .61, .055, '#9661FF', mode='neon', segments=24, sides=5)
    a.ellipsoid('Core', (0, -.91, .1), (.96, .66, .96), '#281E3C', segments=12, rings=8)
    # An offset metallic meridian gives visible motion when the core spins.
    meridian = a.ring('Core', (0, -.91, .1), .49, .024, 'steel', axis='Z', segments=20, sides=4)
    tilt_at_center(meridian, (0, -.91, .1), (.45, 0, 0))
    a.joint('Core', (0, -.91, .1))
    for s in [-1, 1]:
        a.cylinder('Body', (s*1.02, -.57, -.02), .245, 1.64, 'steel', vertices=12)
        a.cylinder('Body', (s*1.02, -.57, .81), .26, .13, 'equipment_dark', vertices=12)
        a.cylinder('Glow', (s*1.02, -.57, -.91), .22, .15, 'cyan', mode='neon', vertices=12)
        a.box('Accent', (s*.54, -.84, 1.0), (.28, .14, .2), TIER[6], mode='tint', bevel=.04)
    return a.finish()


def backpack_t8():
    a = pack(8)
    a.box('Body', (0, -.43, -.04), (1.55, .76, 2.49), 'equipment_dark', bevel=.17)
    diamond(a, 'Body', 0, -.88, .02, 1.28, 2.11, .27, '#4C2C6B')
    orbit = a.ring('Glow', (0, -1.22, .02), .73, .045, TIER[7], mode='neon',
                   segments=24, sides=5)
    tilt_at_center(orbit, (0, -1.22, .02), (.22, 0, .14))
    # A chunky extruded heart with clear lobes and pointed base.
    plate(a, 'Glow', [(0, .25), (-.16, .4), (-.34, .33), (-.37, .15),
                      (0, -.29), (.37, .15), (.34, .33), (.16, .4)],
          .18, 'cyan', y=-1.12, mode='neon', bevel=.035)
    for s in [-1, 1]:
        plate(a, 'Body', [(s*.58, .83), (s*1.37, 1.06), (s*1.12, .35),
                         (s*1.34, -.06), (s*.83, -.75), (s*.77, .17)],
              .2, 'light_steel', y=-.5, bevel=.04)
        a.tube('Glow', [(s*.73, -.635, .75), (s*1.14, -.635, .91),
                        (s*.96, -.635, .3), (s*1.12, -.635, -.07),
                        (s*.86, -.635, -.49)], .035, TIER[7], sides=5)
    diamond(a, 'Body', 0, -.43, 1.4, .37, .43, .24, 'equipment_gold')
    diamond(a, 'Accent', 0, -.94, -.93, .25, .3, .08, TIER[7], 'tint')
    return a.finish()


BUILDERS = {
    'equipment/pickaxe_t1': pickaxe_t1,
    'equipment/pickaxe_t2': pickaxe_t2,
    'equipment/pickaxe_t3': pickaxe_t3,
    'equipment/pickaxe_t4': pickaxe_t4,
    'equipment/pickaxe_t5': pickaxe_t5,
    'equipment/pickaxe_t6': pickaxe_t6,
    'equipment/pickaxe_t7': pickaxe_t7,
    'equipment/pickaxe_t8': pickaxe_t8,
    'equipment/backpack_t1': backpack_t1,
    'equipment/backpack_t2': backpack_t2,
    'equipment/backpack_t3': backpack_t3,
    'equipment/backpack_t4': backpack_t4,
    'equipment/backpack_t5': backpack_t5,
    'equipment/backpack_t6': backpack_t6,
    'equipment/backpack_t7': backpack_t7,
    'equipment/backpack_t8': backpack_t8,
}

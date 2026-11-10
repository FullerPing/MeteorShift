"""Required eggs, debris rocks and map landmarks; execute via the asset runner."""

from math import acos, cos, pi, sin, sqrt
from assetlib import *
from mathutils import Vector


def _egg_point(radius, height, z0, azimuth, fraction, offset=0):
    fraction = max(0.0001, min(0.9999, fraction))
    polar = acos(1 - 2 * fraction)
    r = radius * sin(polar) * (1 + 0.18 * cos(polar)) + offset
    return (r * cos(azimuth), r * sin(azimuth), z0 + height * fraction)


def _egg_shell(a, radius, height, z0, color, segments=20, levels=12):
    verts = [(0, 0, z0)]
    for j in range(1, levels):
        for i in range(segments):
            verts.append(_egg_point(radius, height, z0, 2 * pi * i / segments, j / levels))
    top = len(verts)
    verts.append((0, 0, z0 + height))
    faces = []
    for i in range(segments):
        faces.append((0, 1 + (i + 1) % segments, 1 + i))
    for j in range(levels - 2):
        for i in range(segments):
            k = 1 + j * segments + i
            n = 1 + j * segments + (i + 1) % segments
            faces.append((k, n, n + segments, k + segments))
    last = 1 + (levels - 2) * segments
    for i in range(segments):
        faces.append((last + i, last + (i + 1) % segments, top))
    a.mesh('Shell', verts, faces, color=color)


def _egg_spot(a, group, radius, height, z0, angle, fraction, width, tall, color, mode='palette'):
    verts = [_egg_point(radius, height, z0, angle, fraction, 0.025 * radius)]
    for i in range(12):
        t = 2 * pi * i / 12
        verts.append(_egg_point(radius, height, z0, angle + width * cos(t),
                                fraction + tall * sin(t), 0.026 * radius))
    a.mesh(group, verts, [(0, 1 + i, 1 + (i + 1) % 12) for i in range(12)], color=color, mode=mode)


def _egg_band(a, group, radius, height, z0, fraction, width, color,
              mode='palette', wave=0.0, zigzag=False, phase=0, segments=40, offset=0.02):
    verts = []
    for i in range(segments):
        angle = 2 * pi * i / segments
        wobble = wave * ((1 if i % 2 else -1) if zigzag else sin(2 * angle + phase))
        for edge in (-1, 1):
            verts.append(_egg_point(radius, height, z0, angle,
                                   fraction + wobble + edge * width / 2, offset))
    faces = [(2*i, 2*((i+1) % segments), 2*((i+1) % segments)+1, 2*i+1)
             for i in range(segments)]
    a.mesh(group, verts, faces, color=color, mode=mode)


def _crystal(a, group, base, tip, radius, color, mode='palette', sides=6):
    # A broad faceted shoulder and pointed termination; arbitrary growth direction.
    dx, dy, dz = (tip[i] - base[i] for i in range(3))
    length = sqrt(dx*dx + dy*dy + dz*dz)
    direction = (dx/length, dy/length, dz/length)
    u = (-direction[1], direction[0], 0)
    ul = sqrt(sum(v*v for v in u))
    u = (1, 0, 0) if ul < 0.001 else tuple(v/ul for v in u)
    v = (direction[1]*u[2]-direction[2]*u[1],
         direction[2]*u[0]-direction[0]*u[2],
         direction[0]*u[1]-direction[1]*u[0])
    verts = []
    for along, scale in ((0, 0.7), (0.65, 1)):
        for i in range(sides):
            ang = 2*pi*i/sides
            verts.append(tuple(base[k] + along*(tip[k]-base[k]) +
                               radius*scale*(u[k]*cos(ang)+v[k]*sin(ang)) for k in range(3)))
    verts.append(tip)
    faces = [tuple(reversed(range(sides)))]
    for i in range(sides):
        nxt = (i+1) % sides
        faces.extend([(i, nxt, sides+nxt, sides+i), (sides+i, sides+nxt, 2*sides)])
    return a.mesh(group, verts, faces, color=color, mode=mode)


def egg_meteor():
    a = Asset('eggs/egg_meteor', budget=2000)
    _egg_shell(a, 1.17, 3, 0, 'orange')
    for angle, z, w, h in [(-1.9,.32,.29,.075),(-.8,.49,.21,.06),(-1.35,.71,.24,.07),
                           (-2.7,.6,.3,.055),(.3,.3,.22,.05),(1.6,.52,.3,.08),(2.6,.22,.2,.04)]:
        _egg_spot(a,'Pattern',1.17,3,0,angle,z,w,h,'#703626')
    for angle, z in [(-1.45,.23),(-2.25,.5),(-.5,.66),(.4,.66),(2.2,.72)]:
        _egg_spot(a,'Pattern',1.17,3,0,angle,z,.065,.025,'#A02228')
    _egg_band(a,'Pattern',1.17,3,0,.59,.021,'#703626',wave=.026,zigzag=True,segments=24,offset=.034)
    _egg_band(a,'Glow',1.17,3,0,.59,.008,'#FF963C',mode='neon',wave=.026,zigzag=True,segments=24,offset=.041)
    a.meta['preview_neon'] = '#FF963C'
    return a.finish()


def egg_crystal():
    a = Asset('eggs/egg_crystal', budget=2000)
    _egg_shell(a, 1.13, 2.85, 0, 'blue', segments=16, levels=10)
    for angle, fraction, length in [(-2.3,.58,.64),(-.7,.66,.65),(.5,.45,.55),(2.2,.64,.6),(-1.5,.82,.6)]:
        base = _egg_point(1.13,2.85,0,angle,fraction,-.06)
        tip = (base[0]+.28*cos(angle),base[1]+.28*sin(angle),base[2]+length)
        _crystal(a,'Pattern',base,tip,.21,'frost')
    _egg_band(a,'Pattern',1.13,2.85,0,.39,.037,'#1C4AA8',wave=.04,zigzag=True,segments=20)
    _egg_band(a,'Glow',1.13,2.85,0,.39,.014,'cyan',mode='neon',wave=.04,zigzag=True,segments=20,offset=.035)
    pts = [_egg_point(1.13,2.85,0,-1.52+d,z,.04) for d,z in [(0,.4),(.06,.51),(-.12,.59),(.01,.7)]]
    a.tube('Glow',pts,.025,color='cyan',mode='neon',sides=5)
    return a.finish()


def egg_aurora():
    a = Asset('eggs/egg_aurora', budget=2000)
    _egg_shell(a,1.15,2.65,0,'green')
    for f,w,c,phase in [(.28,.063,'teal',0),(.49,.072,'#78ECDE',.5),(.69,.043,'pink',1.1)]:
        _egg_band(a,'Pattern',1.15,2.65,0,f,w,c,wave=.07,phase=phase,segments=32,offset=.036)
    _egg_band(a,'Glow',1.15,2.65,0,.73,.01,'#78FFD2',mode='neon',wave=.022,zigzag=True,segments=24,offset=.047)
    a.ring('Pattern',(0,0,2.51),.29,.07,color='gold',axis='Z',segments=12,sides=5)
    for i in range(5):
        t=2*pi*i/5
        _crystal(a,'Pattern',(.28*cos(t),.28*sin(t),2.5),(.38*cos(t),.38*sin(t),2.97),.085,'gold',sides=5)
    return a.finish()


def _flecks(a, positions, color):
    for i,(x,y,z) in enumerate(positions):
        _crystal(a,'OreFleck',(x,y,z),(x+.2*(-1 if i%2 else 1),y-.12,z+.9+.13*i),.37,color,mode='neon')


def _ledge(a, group, centre, size, color, variant=0, bevel=.16):
    """A deliberately asymmetric, chamfered quarry block, with sloping sides."""
    outline=[(-.5,-.28),(-.30,-.5),(.22,-.5),(.5,-.26),
             (.46,.27),(.22,.5),(-.29,.46),(-.5,.2)]
    verts=[]
    for z,scale in ((-.5,1),(.5,.88)):
        for i,(x,y) in enumerate(outline):
            dx=(.035 if (i+variant)%3==0 else -.018)*size[0]
            verts.append((centre[0]+x*size[0]*scale+dx,
                          centre[1]+y*size[1]*scale,centre[2]+z*size[2]))
    faces=[tuple(reversed(range(8))),tuple(range(8,16))]
    faces.extend((i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8))
    return a.mesh(group,verts,faces,color=color,bevel=bevel)


def _front_point(objects,x,z,outset=.03):
    """Attach detail to actual rock facets, including overlaps between masses."""
    hits=[]
    for obj in objects:
        hit,loc,normal,index=obj.ray_cast(Vector((x,-20,z))-obj.location,Vector((0,1,0)))
        if hit:
            point=loc+obj.location
            hits.append((point.y,point+normal*outset))
    if not hits:
        return (x,-1.8,z)
    return tuple(min(hits,key=lambda item:item[0])[1])


def _vein(a,objects,points,radius):
    projected=[]
    for j in range(len(points)-1):
        x1,z1=points[j]; x2,z2=points[j+1]
        steps=max(2,int(sqrt((x2-x1)**2+(z2-z1)**2)/.25))
        for i in range(steps):
            t=i/steps
            projected.append(_front_point(objects,x1+(x2-x1)*t,z1+(z2-z1)*t,.025))
    projected.append(_front_point(objects,*points[-1],.025))
    a.tube('Root',projected,radius,'violet',mode='palette',sides=5)


def _rock(biome, variant):
    n='abc'.index(variant)
    a=Asset('rocks/rock_'+biome+'_'+variant,budget=1500)
    a.meta['footprint_limit'] = [8,8]
    a.meta['preview_ore_color'] = {'rust':'#FF963C','frost':'#78ECFF','violet':'#BE78FF','sulfur':'#FFC428'}[biome]
    # Each profile has a different major mass distribution and mining silhouette.
    profiles=[[(0,0,2.3),(5.9,5.1,4.6)],[(.35,.1,2.5),(5.3,5.4,5.0)],[(-.4,.2,2.05),(6.6,5.8,4.1)]]
    centre,size=profiles[n]
    if biome=='rust':
        root=_ledge(a,'Root',centre,size,'rust',n,bevel=.25)
        cap=(-.65+.4*n,.2,4.05+.2*n)
        upper=_ledge(a,'Root',cap,(3.9-n*.4,3.6,1.7),'rust',n+1,bevel=.2)
        a.box('RockChunk',(2.3 if n!=1 else -2.15,.35,1.1),(1.5,3.4,2.15),'#703626',bevel=.24)
        for x,z,angle in [(-1.3,2.3,.14),(1.2,3.55,-.14)]:
            _,front,_=_front_point([root,upper],x,z,.065)
            a.box('Root',(x,front,z),(1.45,.15,.82),'equipment_dark',bevel=.06,rot=(0,angle,0))
            for bx in (-.43,.43):
                a.cylinder('Root',(x+bx,front-.11,z),.11,.13,'steel',vertices=6,rot=(pi/2,0,0))
        flecks=[(-1.25,0,4.85+.2*n),(.65,.55,4.85+.2*n),(1.5,-.75,4.3)]
    elif biome=='frost':
        _ledge(a,'Root',centre,size,'frost',n,bevel=.2)
        _ledge(a,'Root',(-.9+.65*n,.3,4.25),(3.3,3.3,1.65),'frost',n+1,bevel=.18)
        _ledge(a,'RockChunk',(centre[0],centre[1],size[2]-.07),(size[0]*.91,size[1]*.92,.36),'white',n,bevel=.12)
        _ledge(a,'RockChunk',(-.9+.65*n,.3,5.1),(3.15,3.12,.38),'white',n+1,bevel=.12)
        for i in range(4):
            x=-2.0+i*1.12
            a.between('RockChunk',(x,-size[1]*.435,4.15+(n==1)*.55),(x+.06,-size[1]*.435,3.45+(n==1)*.55-.18*(i%2)),.16,'frost',vertices=6,radius2=.015)
        flecks=[(-1+.55*n,.2,5.22),(.5+.25*n,.85,5.2)]
    elif biome=='violet':
        bodies=[a.ico('Root',centre,size,'navy',subdivisions=1,seed=30+n),
                a.ico('Root',(-1.3+.55*n,.2,3.9),(3.8,3.7,3.2),'navy',subdivisions=1,seed=40+n),
                a.ico('RockChunk',(2.05,-.2,1.5),(2.55,3.5,3),'navy',subdivisions=1,seed=50+n)]
        # Inlaid violet veins are fixed palette rock detail, separate from tinted ore.
        _vein(a,bodies,[(-1.5,1.4),(-.8,2.2),(-1,3),(.1,4),(-.15,4.8)],.085)
        _vein(a,bodies,[(-.8,2.2),(.35,2.65),(1.3,2.45)],.06)
        for x,y,z,h in [(-1.55,.1,4.65,1.3),(.0,.55,4.8,1.0)]:
            _crystal(a,'Root',(x,y,z),(x-.25,y+.1,z+h),.44,'violet')
        flecks=[(-.75+.3*n,-.45,5.05),(.7,.15,4.75),(1.5,.2,3.45)]
    else:
        bodies=[a.ico('Root',centre,size,'stone',subdivisions=2,seed=70+n),
                a.ico('Root',(-.8+.6*n,.3,4.1),(3.9,3.7,2.9),'stone',subdivisions=1,seed=80+n)]
        a.ico('RockChunk',(-.8+.6*n,.3,5.08),(3.8,3.4,.65),'sulfur',subdivisions=1,seed=90+n)
        a.ico('RockChunk',(1.9,-1.2,1.05),(2.0,2.0,.75),'sulfur',subdivisions=1,seed=95+n)
        for x,z,r in [(-1.3,2.0,.38),(.7,2.9,.31),(-.55,4.45,.29)]:
            # Conforming dark sockets and yellow rims imply shallow porous vent holes.
            centre_point=_front_point(bodies,x,z,.035)
            verts=[centre_point]
            rim=[]
            for i in range(12):
                t=2*pi*i/12
                point=_front_point(bodies,x+r*cos(t),z+r*sin(t),.045)
                verts.append(point); rim.append(point)
            a.mesh('Root',verts,[(0,i+1,(i+1)%12+1) for i in range(12)],'ink')
            a.tube('Root',rim+[rim[0]],.075,'sulfur',mode='palette',sides=4)
        flecks=[(-.95+.4*n,.4,5.25),(.5+.25*n,.25,5.0)]
    _flecks(a,flecks,a.meta['preview_ore_color'])
    return a.finish()


def anvil():
    a=Asset('map/Anvil',budget=8000)
    a.cylinder('Stump',(0,0,.47),1.24,.94,'wood',vertices=16,radius2=1.12)
    a.cylinder('Stump',(0,0,.945),1.11,.04,'#D6985C',vertices=16)
    for radius in (.48,.77,.99):
        a.ring('Stump',(0,0,.971),radius,.018,'#A86C3E',axis='Z',segments=20,sides=4)
    for i in range(12):
        t=2*pi*i/12
        a.between('Stump',(1.22*cos(t),1.22*sin(t),.08),(1.115*cos(t+.035),1.115*sin(t+.035),.84),.027,'#70462A',vertices=5)
    a.box('Anvil',(0,0,1.12),(3.15,2.12,.36),'navy',bevel=.12)
    a.box('Anvil',(0,0,1.43),(2.62,1.8,.3),'navy',bevel=.09)
    a.poly('Anvil',[(-1.17,1.47),(1.17,1.47),(.72,1.9),(.77,2.25),(1.32,2.51),(-1.32,2.51),(-.77,2.25),(-.72,1.9)],1.35,'navy',bevel=.08)
    a.box('Anvil',(.62,0,2.7),(3.63,1.88,.56),'navy',bevel=.1)
    a.box('Anvil',(.62,0,3.01),(3.65,1.9,.12),'steel',bevel=.045)
    # Taper the horn in both depth and height so it reads correctly from every side.
    verts=[]
    for x,cy,cz,ry,rz in [(-.95,0,2.75,.77,.29),(-1.63,0,2.72,.52,.24),(-2.2,0,2.66,.25,.14),(-2.5,0,2.66,.025,.025)]:
        for i in range(10):
            t=2*pi*i/10
            verts.append((x,cy+ry*cos(t),cz+rz*sin(t)))
    faces=[tuple(reversed(range(10))),tuple(range(30,40))]
    for j in range(3):
        for i in range(10):
            faces.append((j*10+i,j*10+(i+1)%10,(j+1)*10+(i+1)%10,(j+1)*10+i))
    a.mesh('Anvil',verts,faces,'navy',bevel=.035)
    # Small hardy hole and front face emblem are merged into the iron.
    a.box('Anvil',(1.83,0,3.078),(.28,.32,.015),'ink',bevel=.015)
    emblem=a.poly('Anvil',[(-.15,2.5),(.04,2.71),(.2,2.5),(.02,2.34)],.026,'steel')
    emblem.location.y=-.958
    ingot_verts=[(-.67,-.42,3.09),(.67,-.42,3.09),(.67,.42,3.09),(-.67,.42,3.09),
                 (-.52,-.3,3.5),(.52,-.3,3.5),(.52,.3,3.5),(-.52,.3,3.5)]
    a.mesh('HotIngot',ingot_verts,[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)],'orange',mode='neon',bevel=.06)
    return a.finish()


def giant_egg():
    a=Asset('map/GiantEgg',budget=8000)
    _egg_shell(a,7.57,20.4,1.6,'cream',segments=32,levels=20)
    for i,(ang,z,w,h) in enumerate([(-1.8,.24,.24,.047),(-.76,.39,.21,.048),(-1.45,.55,.22,.051),
                                   (-2.7,.46,.24,.053),(-2.0,.7,.18,.041),(.2,.62,.24,.05),(1.5,.4,.21,.054),
                                   (2.7,.24,.23,.05),(.6,.21,.2,.05),(2.3,.72,.18,.042)]):
        _egg_spot(a,'Spots',7.57,20.4,1.6,ang,z,w,h,'#FFB0E2' if i%2==0 else '#78ECDE')
    _egg_band(a,'Shell',7.57,20.4,1.6,.79,.022,'#DEC496',wave=.022,zigzag=True,segments=32,offset=.06)
    _egg_band(a,'CrackGlow',7.57,20.4,1.6,.79,.01,'warm_glow',mode='neon',wave=.022,zigzag=True,segments=32,offset=.09)
    # A woven bed supports the bottom of the egg and closes the hollow ring.
    _lathe(a,'Nest',[(.025,.25),(6.15,.28),(7.05,.8),(6.65,1.32),
                     (5.3,1.17),(3.8,1.22),(2.0,1.5),(.025,1.61)],'#D6985C',segments=32)
    a.ring('Nest',(0,0,.8),6.63,.79,'wood',axis='Z',segments=36,sides=8)
    a.ring('Nest',(0,0,1.45),6.78,.56,'#D6985C',axis='Z',segments=36,sides=6)
    for i in range(24):
        t=2*pi*i/24
        a.between('Nest',(3.1*cos(t),3.1*sin(t),1.36),
                  (6.5*cos(t+.3),6.5*sin(t+.3),1.48),.13,
                  '#DEC496' if i%2 else '#D6985C',vertices=5,radius2=.065)
    # Staggered straw lengths make a woven nest silhouette rather than a plain torus.
    for i in range(36):
        t=2*pi*i/36
        r=6.5+(i%3)*.2
        dt=.19
        a.between('Nest',(r*cos(t-dt),r*sin(t-dt),.52+(i%4)*.22),
                  ((r+.34)*cos(t+dt),(r+.34)*sin(t+dt),1.1+(i%3)*.24),
                  .14,'#D6985C' if i%2 else '#A86C3E',vertices=5,radius2=.075)
    return a.finish()


def _lathe(a,group,profile,color,segments=24):
    verts=[(radius*cos(2*pi*i/segments),radius*sin(2*pi*i/segments),z)
           for radius,z in profile for i in range(segments)]
    faces=[]
    for j in range(len(profile)):
        nj=(j+1)%len(profile)
        for i in range(segments):
            ni=(i+1)%segments
            faces.append((j*segments+i,j*segments+ni,nj*segments+ni,nj*segments+i))
    a.mesh(group,verts,faces,color=color)


def trophy():
    a=Asset('map/Trophy',budget=8000)
    a.box('Base',(0,0,.25),(4.5,4.5,.5),'navy',bevel=.12)
    a.box('Base',(0,0,.65),(3.9,3.9,.42),'ink',bevel=.09)
    a.box('Base',(0,0,.91),(4.06,4.06,.13),'gold',bevel=.045)
    a.box('Base',(0,-1.979,.62),(1.05,.08,.55),'#CE8C14',bevel=.04)
    star=[]
    for i in range(10):
        t=pi/2+i*pi/5
        r=.235 if i%2==0 else .105
        star.append((r*cos(t),.63+r*sin(t)))
    emblem=a.poly('Base',star,.055,'#FFE66E',bevel=.012)
    emblem.location.y=-2.038
    _lathe(a,'Cup',[(.78,.99),(.82,1.12),(.63,1.34),(.29,1.6),(.24,2.55),(.45,2.88),(.63,3.02),(.55,3.12),(.18,2.78),(.12,1.3)],'gold')
    _lathe(a,'Cup',[(.54,2.92),(.86,3.13),(1.2,3.6),(1.39,4.35),(1.46,5.16),
                    (1.39,5.31),(1.27,5.23),(1.2,4.35),(.99,3.65),(.64,3.33),(.37,3.26)],'gold')
    a.ring('Cup',(0,0,5.24),1.38,.115,'#FFE66E',axis='Z',segments=28,sides=6)
    a.ring('Cup',(0,0,3.07),.57,.095,'#CE8C14',axis='Z',segments=20,sides=6)
    for sign in (-1,1):
        # C-shaped handles join into the bowl at two obvious gold collars.
        pts=[(sign*1.28,0,4.91),(sign*1.74,0,5.12),(sign*2.04,0,4.88),
             (sign*2.1,0,4.38),(sign*1.98,0,3.97),(sign*1.63,0,3.69),(sign*1.13,0,3.7)]
        a.tube('Cup',pts,.145,'gold',mode='palette',sides=8)
        for z in (4.89,3.78):
            a.ellipsoid('Cup',(sign*1.24,0,z),(.43,.38,.37),'#FFE66E',segments=10,rings=6)
    # Diagonal miniature mining pick displayed against the front of the cup.
    a.between('Cup',(-.66,-1.44,3.53),(.84,-1.44,6.19),.105,'wood',vertices=10)
    for t in (.1,.2,.3):
        x=-.66+1.5*t
        z=3.53+2.66*t
        a.between('Cup',(x,-1.44,z),(x+.045,-1.44,z+.08),.135,'#70462A',vertices=10)
    head=a.poly('Cup',[(-.4,6.27),(.15,6.69),(.74,6.8),(1.21,6.6),(1.75,6.0),(1.87,5.64),
                       (1.49,5.98),(.95,6.28),(.65,6.35),(.11,6.32)],.22,'light_steel',bevel=.045)
    head.location.y=-1.44
    a.box('Cup',(.75,-1.44,6.37),(.32,.33,.38),'equipment_gold',bevel=.055,rot=(0,-.48,0))
    return a.finish()


def egg_magma():
    a = Asset('eggs/egg_magma', budget=2000)
    _egg_shell(a, 1.17, 3, 0, '#703626')
    for angle, z, w, h in [(-1.9,.30,.30,.07),(-.7,.50,.24,.06),(-1.3,.74,.22,.06),(-2.6,.58,.28,.06),
                           (.4,.32,.24,.05),(1.5,.55,.30,.07),(2.6,.24,.22,.05),(.9,.78,.2,.05)]:
        _egg_spot(a,'Pattern',1.17,3,0,angle,z,w,h,'#1D2533')
    # glowing magma cracks running up from a zigzag seam
    _egg_band(a,'Glow',1.17,3,0,.47,.03,'#FFB030',mode='neon',wave=.05,zigzag=True,segments=18,offset=.045)
    for base, steps in [(-1.5,[(0,.22),(.12,.31),(.02,.40),(.14,.47)]),(.9,[(0,.47),(-.12,.56),(.02,.66),(-.10,.76)]),
                        (2.4,[(0,.12),(.1,.22),(-.04,.33),(.08,.47)]),(-.4,[(0,.47),(.1,.6),(-.04,.7),(.12,.84)])]:
        pts = [_egg_point(1.17,3,0,base+d,f,.04) for d,f in steps]
        a.tube('Glow',pts,.055,color='#FFB030',mode='neon',sides=5)
    a.meta['preview_neon'] = '#FFB030'
    return a.finish()


def egg_void():
    a = Asset('eggs/egg_void', budget=2000)
    _egg_shell(a, 1.13, 2.9, 0, '#161E36', segments=18, levels=12)
    _egg_band(a,'Pattern',1.13,2.9,0,.52,.09,'#283456',wave=.03,segments=24,offset=.03)
    _egg_band(a,'Glow',1.13,2.9,0,.52,.04,'cyan',mode='neon',wave=.03,segments=24,offset=.05)
    for angle, f in [(-1.6,.30),(-.6,.74),(.5,.36),(1.4,.82),(2.3,.60),(-2.5,.68),(3.0,.25),(-1.1,.88),(.9,.66),(-2.0,.18),(-1.2,.62),(-2.2,.40),(0,.22),(.2,.85)]:
        _egg_spot(a,'Stars',1.13,2.9,0,angle,f,.085,.03,'white','neon')
    a.meta['preview_neon'] = '#6DEFFF'
    return a.finish()


BUILDERS = {
    'eggs/egg_meteor': egg_meteor,
    'eggs/egg_crystal': egg_crystal,
    'eggs/egg_aurora': egg_aurora,
    'eggs/egg_magma': egg_magma,
    'eggs/egg_void': egg_void,
    **{'rocks/rock_'+biome+'_'+variant: (lambda b=biome,v=variant: _rock(b,v))
       for biome in ('rust','frost','violet','sulfur') for variant in 'abc'},
    'map/Anvil': anvil,
    'map/GiantEgg': giant_egg,
    'map/Trophy': trophy,
}

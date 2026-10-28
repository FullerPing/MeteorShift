"""Optional repeated scenery, authored at stud scale with bottom-centre pivots."""
from math import sin, cos, pi
from assetlib import *


def _asset(name, large=False):
    a=Asset('props/'+name,budget=8000 if large else 800)
    a.meta['Optional']=True
    a.meta['optional']=True
    a.meta['target_dimensions_blender']={
        'tree_round':[11,8,16],'tree_pine':[12,12,18],'bush':[7,4.4,5],
        'lamp_post':[3,3,13.5],'bench':[8,3,4.5],'crate':[4.6,4.6,4.6],
        'barrel':[4.2,4.2,5],'planter':[10,4.5,4],'banner':[5,1,18],
        'sack':[3.4,3.4,3.4],'mine_cart':[6,4.4,4.5],
        'fountain':[40,40,20],'turret':[24,24,50]}[name]
    if large:
        a.meta['budget_rationale']='Landmark-scale scenery: section 9 specifies a large town centrepiece or boundary tower; uses the 8000-triangle map-hero allowance.'
    return a


def _lathe(a,profile,color,segments=12,group='Body',mode='palette'):
    verts=[(r*cos(2*pi*i/segments),r*sin(2*pi*i/segments),z) for r,z in profile for i in range(segments)]
    faces=[]
    for j in range(len(profile)):
        for i in range(segments):
            nj=(j+1)%len(profile); ni=(i+1)%segments
            faces.append((j*segments+i,j*segments+ni,nj*segments+ni,nj*segments+i))
    return a.mesh(group,verts,faces,color,mode=mode)


def _panel(a,loc,size,color,group='Body',mode='palette'):
    # Explicit chamfer rings keep trim pieces light while rounding every corner.
    x,y,z=loc; w,d,h=size; c=min(w,d,h)*.16
    verts=[]
    for zz,inset in ((-h/2,c),(-h/2+c,0),(h/2-c,0),(h/2,c)):
        ww=w/2-inset; dd=d/2-inset
        for xx,yy in [(-ww+c,-dd),(ww-c,-dd),(ww,-dd+c),(ww,dd-c),
                      (ww-c,dd),(-ww+c,dd),(-ww,dd-c),(-ww,-dd+c)]:
            verts.append((x+xx,y+yy,z+zz))
    faces=[tuple(reversed(range(8))),tuple(range(24,32))]
    faces.extend((j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i) for j in range(3) for i in range(8))
    return a.mesh(group,verts,faces,color,mode=mode)


def tree_round():
    a=_asset('tree_round')
    a.cylinder('Body',(0,0,3.7),1.05,7.4,'wood',vertices=10,radius2=.72)
    for end in [(-2.5,0,8.1),(2.3,.2,8.7)]:
        a.between('Body',(0,0,5),end,.49,'wood',vertices=7,radius2=.3)
    a.ellipsoid('Body',(-2.4,0,10.6),(6.2,6.1,7.1),'#308C34',segments=10,rings=7)
    a.ellipsoid('Body',(2.15,.2,11.15),(6.7,6.9,7.8),'green',segments=10,rings=7)
    a.ellipsoid('Body',(-.15,-.25,12.75),(7.8,7.2,6.5),'#8CE262',segments=10,rings=7)
    for t in (0,2*pi/3,4*pi/3):
        a.between('Body',(1.5*cos(t),1.5*sin(t),.26),(.3*cos(t),.3*sin(t),1.1),.23,'wood',vertices=6,radius2=.36)
    return a.finish()


def tree_pine():
    a=_asset('tree_pine')
    a.cylinder('Body',(0,0,2.5),.72,5,'wood',vertices=10,radius2=.54)
    for base,r,top,color in [(3.7,6,11,'#308C34'),(7.6,4.7,14.9,'green'),(11.7,3.2,17.4,'#8CE262')]:
        _lathe(a,[(.05,base),(r-.35,base),(r,base+.28),(r-.15,base+.7),(.13,top)],color,segments=12)
    a.ellipsoid('Body',(0,0,17.45),(1.1,1.1,1.1),'green',segments=8,rings=5)
    return a.finish()


def bush():
    a=_asset('bush')
    a.ellipsoid('Body',(-1.35,0,2.1),(4.3,4.1,4.2),'green',segments=10,rings=7)
    a.ellipsoid('Body',(1.3,.2,2.5),(4.4,4.2,5),'#8CE262',segments=10,rings=7)
    for x,y,z in [(-1.8,-1.63,2.7),(.1,-1.7,3.4),(1.9,-1.54,2.7)]:
        for i in range(5):
            t=2*pi*i/5
            a.ellipsoid('Body',(x+.22*cos(t),y,z+.22*sin(t)),(.38,.22,.38),'pink',segments=5,rings=3)
        a.ellipsoid('Body',(x,y-.1,z),(.23,.17,.23),'gold',segments=5,rings=3)
    return a.finish()


def lamp_post():
    a=_asset('lamp_post')
    _lathe(a,[(.02,0),(.95,0),(1.02,.18),(.96,.43),(.64,.58),(.39,1.12),(.02,1.12)],'ink')
    a.cylinder('Body',(0,0,5.75),.2,9.8,'ink',vertices=10)
    a.cylinder('Body',(0,0,10.56),.63,.26,'gold',vertices=12,radius2=.8)
    a.ellipsoid('Lantern',(0,0,11.65),(2.64,2.64,2.55),'warm_glow',mode='neon',segments=12,rings=7)
    a.cylinder('Body',(0,0,12.93),1.5,.38,'ink',vertices=12,radius2=.74)
    a.ellipsoid('Body',(0,0,13.25),(.5,.5,.5),'gold',segments=8,rings=5)
    for i in range(4):
        t=2*pi*i/4
        a.between('Body',(.56*cos(t),.56*sin(t),10.62),(1.08*cos(t),1.08*sin(t),12.84),.075,'ink',vertices=5)
    return a.finish()


def bench():
    a=_asset('bench')
    for x in (-2.65,2.65):
        for y in (-.85,.88):
            a.between('Body',(x,y,0),(x,y,2.15),.16,'ink',vertices=8)
        a.between('Body',(x,.95,1.8),(x,1.08,4.3),.15,'ink',vertices=8)
        a.between('Body',(x,-1.3,1.9),(x,1.2,1.9),.17,'ink',vertices=8)
    for y in (-.75,.25):
        _panel(a,(0,y,2.17),(8,.96,.32),'red',group='SeatBack',mode='tint')
    for z in (3.12,4.12):
        _panel(a,(0,1.27,z),(8,.46,.76),'red',group='SeatBack',mode='tint')
    return a.finish()


def crate():
    a=_asset('crate')
    a.box('Body',(0,0,2.3),(4.6,4.6,4.6),'wood',bevel=.18)
    for z in (.55,4.05):
        # One continuous horizontal band each, with side grain under it.
        _lathe_square(a,z,.34,2.34,'#70462A')
    for y in (-2.32,2.32):
        bar=a.box('Body',(0,y,2.3),(.37,.14,4.7),'#70462A',bevel=.055,rot=(0,.72,0))
    for x in (-1.2,0,1.2):
        a.between('Body',(x,-2.306,.8),(x,-2.306,3.8),.026,'#D6985C',vertices=4)
    return a.finish()


def _lathe_square(a,z,height,r,color):
    verts=[]
    for zz,rr in ((z-height/2,r),(z+height/2,r),(z+height/2,r-.13),(z-height/2,r-.13)):
        verts.extend([(-rr,-rr,zz),(rr,-rr,zz),(rr,rr,zz),(-rr,rr,zz)])
    faces=[(j*4+i,j*4+(i+1)%4,((j+1)%4)*4+(i+1)%4,((j+1)%4)*4+i) for j in range(4) for i in range(4)]
    a.mesh('Body',verts,faces,color)


def barrel():
    a=_asset('barrel')
    _lathe(a,[(.02,0),(1.62,0),(1.83,.25),(2.1,1.8),(2.1,3.15),(1.84,4.75),(1.65,5),(.02,5)],'wood',segments=12)
    for z,r in ((.98,1.99),(4.03,1.98)):
        _lathe(a,[(r-.04,z-.17),(r+.045,z-.17),(r+.045,z+.17),(r-.04,z+.17)],'ink',segments=12)
    a.cylinder('Body',(0,0,5.005),1.61,.03,'#D6985C',vertices=12)
    for x in (-.8,0,.8):
        a.between('Body',(x,-1.35,5.03),(x,1.35,5.03),.025,'#70462A',vertices=4)
    a.cylinder('Body',(.65,-.3,5.055),.2,.08,'#70462A',vertices=8)
    return a.finish()


def planter():
    a=_asset('planter')
    a.box('Body',(0,0,1.12),(9.65,4.1,2.24),'cream',bevel=.22)
    _panel(a,(0,0,2.3),(10,4.5,.37),'white')
    _panel(a,(0,0,2.51),(9.15,3.67,.1),'#70462A')
    for i,x in enumerate((-3.4,-1.15,1.15,3.4)):
        z=3.24+(i%2)*.16
        a.between('Body',(x,0,2.45),(x,0,z),.09,'green',vertices=5)
        a.ellipsoid('Body',(x,0,z),(1.65,1.65,1.35),['pink','gold','red','white'][i],segments=8,rings=5)
    return a.finish()


def banner():
    a=_asset('banner')
    a.cylinder('Body',(-2.1,0,.25),.55,.5,'ink',vertices=10,radius2=.44)
    a.cylinder('Body',(-2.1,0,8.8),.14,17,'ink',vertices=10)
    a.ellipsoid('Body',(-2.1,0,17.6),(.8,.8,.8),'gold',segments=8,rings=5)
    a.between('Body',(-2.25,0,16.75),(2.55,0,16.75),.12,'gold',vertices=8)
    verts=[]
    for z in (16.55,13.5,10.6,7.8):
        for i in range(7):
            x=-1.95+i*.73
            zz=z+(abs(i-3)*.3 if z==7.8 else 0)
            verts.append((x,.13+sin(i*pi/3)*.22,zz))
    faces=[(j*7+i,j*7+i+1,(j+1)*7+i+1,(j+1)*7+i) for j in range(3) for i in range(6)]
    a.mesh('Cloth',verts,faces,'red',mode='tint')
    return a.finish()


def sack():
    a=_asset('sack')
    a.ellipsoid('Body',(0,0,1.42),(2.95,2.65,2.84),'cream',segments=12,rings=8)
    _lathe(a,[(.57,2.55),(.4,2.86),(.45,3.08),(.65,3.35),(.34,3.4)],'cream',segments=10)
    a.ring('Body',(0,0,2.91),.43,.075,'wood',axis='Z',segments=12,sides=5)
    a.tube('Body',[(.3,-.37,2.9),(.6,-.5,2.74),(.7,-.51,2.5)],.052,'wood',mode='palette',sides=5)
    for i in range(5):
        z=.72+i*.24
        a.between('Body',(-.11,-1.28,z),(.12,-1.3,z+.12),.022,'#DEC496',vertices=4)
    return a.finish()


def mine_cart():
    a=_asset('mine_cart')
    # Hollow tapered bin, bottom tucked above its independent-looking wheels.
    verts=[]
    for w,d,z in [(2.4,1.62,.9),(3,2,3.63),(2.78,1.78,3.63),(2.19,1.39,1.2)]:
        verts.extend([(-w,-d,z),(w,-d,z),(w,d,z),(-w,d,z)])
    faces=[(12,13,14,15)]
    faces.extend((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i) for j in range(3) for i in range(4))
    a.mesh('Body',verts,faces,'stone',bevel=.04)
    for x in (-1.95,1.95):
        for y in (-1.89,1.89):
            a.cylinder('Body',(x,y,.57),.57,.56,'ink',vertices=10,rot=(pi/2,0,0))
            a.cylinder('Body',(x,y+(.3 if y>0 else -.3),.57),.18,.045,'steel',vertices=8,rot=(pi/2,0,0))
    for y in (-2,2):
        _panel(a,(0,y,3.67),(6,.22,.28),'orange')
    for x in (-2.9,2.9):
        a.between('Body',(x,-1.95,3.67),(x,1.95,3.67),.14,'orange',vertices=6)
    for i,(x,y,z,size) in enumerate([(-1.55,0,3.51,(2,2,1.65)),(.3,.45,3.64,(2.4,2.1,1.72)),(1.75,-.4,3.5,(1.85,1.8,1.5))]):
        a.ico('Body',(x,y,z),size,'rust',subdivisions=1,seed=220+i)
    return a.finish()


def fountain():
    a=_asset('fountain',True)
    a.meta['RobloxWater']='Retain the native Roblox pool surface inside the rim; no water mesh exported.'
    _lathe(a,[(.025,0),(18.6,0),(19.5,.5),(19.5,1.2),(18.8,1.65),(.025,1.65)],'cream',segments=40)
    _lathe(a,[(18.5,1.5),(19.2,1.5),(19.3,3.65),(18.95,4.15),(18.15,4.15),(18.1,2)],'blue',segments=40)
    a.ring('Body',(0,0,4.1),19,.99,'white',axis='Z',segments=40,sides=8)
    _lathe(a,[(.025,1.6),(3.9,1.6),(4.25,2.2),(3.7,2.9),(1.8,3.4),(1.15,7.5),(2.4,8.35),(.025,8.35)],'gold',segments=24)
    _lathe(a,[(.15,7.85),(3,8),(6.4,9.15),(7.5,10.45),(7.45,10.8),(6.95,10.9),(5.9,9.65),(2.65,8.55),(.15,8.45)],'gold',segments=32)
    a.ring('Body',(0,0,10.7),7.24,.3,'#FFE66E',axis='Z',segments=32,sides=6)
    _lathe(a,[(.05,8.4),(1.7,8.4),(1.25,9.4),(.8,12.8),(1.5,13.5),(.05,13.5)],'gold',segments=20)
    _lathe(a,[(.1,13.2),(1.9,13.25),(3.7,14.2),(4.55,15.35),(4.35,15.7),(3.9,15.6),(3.3,14.6),(1.65,13.8),(.1,13.65)],'gold',segments=28)
    a.ring('Body',(0,0,15.5),4.25,.3,'#FFE66E',axis='Z',segments=28,sides=6)
    a.cylinder('Body',(0,0,15.55),.44,3.5,'gold',vertices=12,radius2=.26)
    a.ellipsoid('Glow',(0,0,18.1),(1.4,1.4,3.8),'cyan',mode='neon',segments=12,rings=8)
    for i in range(6):
        t=2*pi*i/6
        pts=[(.35*cos(t),.35*sin(t),18.1),(1.3*cos(t),1.3*sin(t),18.65),
             (2.35*cos(t),2.35*sin(t),18.2),(3*cos(t),3*sin(t),16.1)]
        a.tube('Glow',pts,.12,'cyan',mode='neon',sides=5)
    return a.finish()


def turret():
    a=_asset('turret',True)
    _lathe(a,[(.01,0),(10.6,0),(11.2,.8),(11.2,2.4),(10.3,3),(9.7,3.3),(9.7,29.5),(.01,29.5)],'red',segments=32)
    _lathe(a,[(9.69,23),(10,23),(10,25.5),(9.69,25.5)],'white',segments=32)
    _lathe(a,[(9.4,29),(11.65,29),(12,29.55),(12,31.5),(11.5,32),(9.4,32)],'stone',segments=32)
    for base,r,top in [(31.6,11.55,36.6),(35.9,8.9,40.8),(40.15,6.05,44.3),(43.8,3.48,46.4)]:
        _lathe(a,[(.01,base),(r-.25,base),(r,base+.22),(r-.06,base+.65),(.2,top)],'navy',segments=24)
    a.ellipsoid('Body',(0,0,46.7),(1.8,1.8,1.8),'gold',segments=12,rings=8)
    a.cylinder('Body',(0,0,48),.13,3.7,'gold',vertices=10)
    pennant=a.poly('Body',[(.12,49.9),(5,49.35),(3.15,48.65),(5,47.95),(.12,48.2)],.16,'gold',bevel=.05)
    for x,z in [(-3.4,12),(3.4,12),(0,20)]:
        # Thin front arrow slits remain fixed details in the merged tower mesh.
        a.box('Body',(x,-(9.7**2-x*x)**.5-.025,z),(.57,.07,2.65),'ink',bevel=.025)
    return a.finish()


BUILDERS={'props/'+name:globals()[name] for name in (
    'tree_round','tree_pine','bush','lamp_post','bench','crate','barrel','planter',
    'banner','sack','mine_cart','fountain','turret')}

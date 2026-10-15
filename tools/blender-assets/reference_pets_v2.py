"""Second sculpt pass: reference proportions and solid, connected forms.

No automatic generations, no stock animal meshes. All surfaces are authored here.
The reference look is retained for BOTH level variants, with no invented ornaments.
"""
import sys, math, json, shutil, struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import reference_pets as old
import assetlib as lib
from assetlib import Asset,Vector,bpy
from mathutils import Matrix

OUT=old.BASE/'blender/pets/reference-v2'
OUT.mkdir(parents=True,exist_ok=True)
old.OUT=OUT;lib.ROOT=OUT;lib.SWATCHFILE=OUT/'palette-swatches.json'
REFS=old.REFS
COL={'solarPhoenix':'#EB4B0B','auroraOwl':'#216369','coinMagpie':'#F6BD15',
 'meteorDrake':'#34303A','pebblePup':'#84898D','cargoMole':'#A36B47',
 'crystalStag':'#9660CE','lodeWyrm':'#D58628','sparkHare':'#F5C616'}

def pet(name,lv=False,flying=False):
 a=Asset('models/'+name+('_lv10' if lv else ''),budget=8000)
 a.meta.update(PetColor=COL[name],Level10=lv,PrimaryPart='Body',FrontAxis='-Y',
  Flying=flying,PivotType='BodyCenter' if flying else 'BottomCenter',Reference=REFS[name],
  ReferencePriority='pictured form and color override historical pet art descriptions',
  Level10Approach='Identical reference replica; no invented accessories',Revision=2)
 return a

def ell(a,g,p,s,c,mode='palette',seg=18,rings=10):
 return a.ellipsoid(g,p,s,c,mode,segments=seg,rings=rings)

def box(a,g,p,s,c,b=.12,mode='palette',rot=None):
 ob=a.box(g,p,s,c,b,mode,rot)
 if b:ob.modifiers[-1].segments=3
 return ob

def loft(a,g,rings,c,mode='palette',sides=18,square=2):
 """Sculpted horizontal rings (z,rx,ry,cx,cy), avoiding stacked primitive seams."""
 vs=[];fs=[]
 for i,(z,rx,ry,cx,cy) in enumerate(rings):
  for j in range(sides):
   t=math.tau*j/sides
   x=math.copysign(abs(math.cos(t))**(2/square),math.cos(t))*rx
   y=math.copysign(abs(math.sin(t))**(2/square),math.sin(t))*ry
   offset=0
   if 0<i<len(rings)-1:
    offset=min(z-rings[i-1][0],rings[i+1][0]-z)*0.18*math.sin(j*2.39+i*1.17)
   vs.append((cx+x*(1+0.014*math.sin(j*1.83+i)),cy+y,z+offset))
 for i in range(len(rings)-1):
  for j in range(sides):
   n=(j+1)%sides;v=i*sides+j;w=i*sides+n
   # alternating diagonals produce natural faceted planes instead of stripes.
   if (i+j)%2:fs.extend([(v,w,v+sides),(w,w+sides,v+sides)])
   else:fs.extend([(v,w,w+sides),(v,w+sides,v+sides)])
 fs.extend([tuple(reversed(range(sides))),tuple(range((len(rings)-1)*sides,len(rings)*sides))])
 return a.mesh(g,vs,fs,c,mode)

def curve_point(points,t):
 # Catmull-Rom through supplied silhouette landmarks.
 x=t*(len(points)-1);i=min(int(x),len(points)-2);u=x-i
 p0=Vector(points[max(0,i-1)]);p1=Vector(points[i]);p2=Vector(points[i+1]);p3=Vector(points[min(len(points)-1,i+2)])
 return .5*((2*p1)+(-p0+p2)*u+(2*p0-5*p1+4*p2-p3)*u*u+(-p0+3*p1-3*p2+p3)*u*u*u)

def sweep(a,g,points,widths,depths,c,mode='palette',sides=8,steps=None):
 """Solid curved feather/limb/horn: variable elliptical cross-section, closed ends."""
 if steps is None:steps=len(points)*2
 vs=[];fs=[]
 for i in range(steps):
  t=i/(steps-1);p=curve_point(points,t)
  tangent=curve_point(points,min(1,t+.005))-curve_point(points,max(0,t-.005))
  # For silhouette strokes in XZ, thickness is along Y.
  lateral=Vector((-tangent.z,0,tangent.x)).normalized()
  if lateral.length<.1:lateral=Vector((1,0,0))
  n=t*(len(widths)-1);k=min(int(n),len(widths)-2);u=n-k
  w=widths[k]*(1-u)+widths[k+1]*u;d=depths[k]*(1-u)+depths[k+1]*u
  for j in range(sides):
   q=j*math.tau/sides
   vs.append(p+lateral*(w*math.cos(q))+Vector((0,d*math.sin(q),0)))
 for i in range(steps-1):
  for j in range(sides):fs.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
 fs.extend([tuple(reversed(range(sides))),tuple(range((steps-1)*sides,steps*sides))])
 return a.mesh(g,vs,fs,c,mode)

def face(a,g,p,size,c,angle=0,mode='palette',segments=16):
 # Facial detail normal follows the curved head flank rather than floating frontally.
 o=ell(a,g,p,size,c,mode,seg=segments,rings=8);o.rotation_euler.z=angle
 return o

def eyes(a,p,x=.40,size=.19,c='#211913',angle=.48):
 y,z=p
 for s in (-1,1):
  an=s*angle
  face(a,'Eyes',(s*x,y,z),(size,.075,size*1.12),c,an)
  offset=Vector((-.025,-.05,.04));off=Matrix.Rotation(an,4,'Z')@offset
  face(a,'EyeHighlight',Vector((s*x,y,z))+off,(size*.25,.025,size*.28),'#FFFAED',an,segments=10)

def legjoint(a,g,p):a.joint(g,p)

def done(a):
 a.meta['Level10Variant']='Identical reference replica; no invented accessories'
 return old.finish(a,False)

def pup(lv=False):
 a=pet('pebblePup',lv);gray='#84898D';dark='#70777D'
 box(a,'Body',(0,.28,1.00),(1.48,1.85,1.27),gray,.23,'tint')
 box(a,'Head',(0,-.48,1.95),(1.97,1.46,1.78),gray,.30)
 # Head occupies the majority of the silhouette, with a small broad muzzle.
 box(a,'Muzzle',(0,-1.218,1.62),(.90,.31,.54),'#90979B',.11)
 a.mesh('Nose',[(-.15,-1.426,1.87),(.15,-1.426,1.87),(.14,-1.49,1.76),(-.12,-1.49,1.76),(-.10,-1.44,1.65),(.10,-1.44,1.65)],[(0,1,2,3),(3,2,5,4),(0,3,4),(1,5,2),(0,4,5,1)],'#5B6064',bevel=.025)
 eyes(a,(-1.235,2.06),.43,.14,'#222326',angle=.05)
 for s in (-1,1):
  sweep(a,'Ears',[(s*.83,-.44,2.57),(s*1.00,-.44,2.36),(s*.99,-.49,1.77)],[.16,.23,.18],[.12,.15,.13],dark,sides=8,steps=6)
  for g,y in [('FrontLeg',-.50),('BackLeg',.81)]:
   n=g+('.L' if s<0 else '.R');box(a,n,(s*.51,y,.29),(.46,.53,.58),dark,.085);legjoint(a,n,(s*.51,y,.57))
 # Collar follows the round neck, with a broad red front and unobtrusive buckle.
 box(a,'Collar',(0,-0.63,0.96),(1.64,1.02,0.19),'#DD3B32',0.075)
 box(a,'Buckle',(0,-1.17,0.97),(0.17,0.045,0.20),'#ADB4B7',0.015)
 a.between('Tag',(0,-1.20,0.90),(0,-1.23,0.78),0.022,'#33373B',vertices=6)
 box(a,'Tag',(0,-1.26,0.63),(0.075,0.045,0.37),'#B4A98E',0.01)
 o=a.poly('Tag',[(-.24,.86),(-.14,.93),(.17,.90),(.25,.82),(.04,.85),(-.10,.84)],.045,'#45494D',bevel=.015);o.location.y=-1.275
 sweep(a,'Tail',[(0,1.08,1.13),(0,1.36,1.38),(0,1.45,1.71)], [.13,.14,.11],[.13,.14,.10],dark,sides=6,steps=5)
 a.joint('Head',(0,-.36,1.53));a.joint('Ears',(0,-.36,1.53));a.meta.setdefault('animation_groups',{})['Ears']='Head';a.joint('Tail',(0,1.07,1.14))
 return done(a)

def magpie(lv=False):
 a=pet('coinMagpie',lv);black='#333842';gold='#F6BD15'
 loft(a,'Body',[(.25,.32,.40,0,.08),(.45,.59,.62,0,.09),(.85,.79,.75,0,.06),(1.20,.80,.69,0,.07),(1.50,.59,.54,0,.13),(1.65,.28,.27,0,.15)],gold,'tint',sides=20)
 ell(a,'Back',(0,.35,1.40),(1.45,1.10,1.43),black,seg=18)
 loft(a,'Head',[(1.26,.34,.34,0,-.33),(1.42,.57,.53,0,-.37),(1.77,.73,.65,0,-.42),(2.10,.70,.61,0,-.45),(2.36,.55,.47,0,-.45),(2.48,.29,.24,0,-.45)],black,sides=20,square=2.2)
 for s in (-1,1):
  an=s*.75
  face(a,'Eyes',(s*.49,-.913,2.01),(.19,.09,.22),'#271E1D',an)
  face(a,'EyeHighlight',(s*.49-.027,-.960,2.075),(.063,.026,.070),'#FFF7EE',an,segments=10)
  g='WingsLeft' if s<0 else 'WingsRight'
  ell(a,g,(s*.72,.00,1.35),(.59,1.02,.88),gold,seg=14,rings=8)
  for j in range(3):
   sweep(a,g,[(s*.74,.02,1.38),(s*.88,.31,1.15),(s*.81,.71,.86+j*.11)], [.14,.19,.04],[.12,.12,.025],black,sides=6,steps=5)
   sweep(a,g,[(s*.86,.45,1.02+j*.10),(s*.86,.69,.94+j*.10)],[.13,.05],[.07,.025],gold,sides=6,steps=3)
  a.joint(g,(s*.61,0,1.61))
  n='Feet'+('.L' if s<0 else '.R')
  a.between(n,(s*.35,-.08,.44),(s*.35,-.18,.12),.048,'#BC861C',vertices=8)
  for j in range(3):a.between(n,(s*.35,-.18,.13),(s*.35+(j-1)*.11,-.43,.055),.036,'#BC861C',vertices=6,radius2=.024)
  a.joint(n,(s*.35,-.08,.40))
 for j in range(3):
  x=(j-1)*.22
  sweep(a,'Tail',[(x*.4,.72,1.20),(x,1.26,1.69),(x*1.50,1.86,2.53-abs(j-1)*.22)], [.09,.16,.12],[.095,.14,.10],black,sides=6,steps=6)
 # Broad triangular beak grips the near rim of the flat coin.
 a.mesh('Beak',[(-.29,-.92,1.90),(.29,-.92,1.90),(-.22,-1.17,1.83),(.22,-1.17,1.83),(0,-1.54,1.78),(0,-1.00,1.68)],[(0,1,3,2),(2,3,4),(0,2,4,5),(1,5,4,3),(0,5,1)],'#414751')
 a.cylinder('Coin',(0,-1.47,1.75),.44,.095,'#FFD043',vertices=24)
 a.ring('Coin',(0,-1.47,1.807),.402,.032,'#E8B521',axis='Z',segments=24,sides=4)
 a.joint('Head',(0,-.33,1.54));a.joint('Tail',(0,.73,1.23));a.joint('Coin',(0,-.33,1.54));a.meta.setdefault('animation_groups',{})['Coin']='Head'
 return done(a)

def mole(lv=False):
 a=pet('cargoMole',lv);brown='#A36B47';shadow='#845333'
 # One barrel-shaped torso, without the previous sphere/helmet seams.
 loft(a,'Body',[(.18,.48,.42,0,.03),(.35,.70,.59,0,.05),(.75,.89,.74,0,.09),(1.22,.96,.80,0,.08),(1.66,.93,.77,0,.06),(1.95,.84,.69,0,.00),(2.10,.65,.53,0,-.03)],brown,'tint',sides=20,square=2.3)
 loft(a,'Head',[(1.56,.82,.66,0,-.04),(1.83,.90,.71,0,-.04),(2.19,.93,.72,0,-.04),(2.36,.87,.64,0,-.04),(2.41,.72,.55,0,-.04)],brown,sides=20,square=2.7)
 a.ring('Headband',(0,-.02,2.20),.89,.055,'#4E3C31',axis='Z',segments=24,sides=4)
 # A broad flat top is the head surface, not an added construction helmet.
 a.cylinder('Head',(0,-.025,2.37),.88,.055,'#AC7655',vertices=20)
 a.cylinder('LampHousing',(0,-0.98,2.23),0.16,0.07,'#D8BF7A',vertices=8,rot=(math.pi/2,0,0))
 a.cylinder('Lamp',(0,-1.022,2.23),0.117,0.016,'#FFF08C','neon',vertices=8,rot=(math.pi/2,0,0))
 for s in (-1,1):
  box(a,'Eyes',(s*.39,-.771,1.94),(.09,.03,.045),'#6A462E',.012)
  g='FrontLeg'+('.L' if s<0 else '.R')
  sweep(a,g,[(s*.71,-.09,1.37),(s*1.05,-.40,1.12),(s*1.06,-.61,.98)],[.26,.33,.30],[.26,.30,.24],brown,sides=10,steps=6)
  for j in range(3):
   x=s*.84+s*j*.19
   sweep(a,g,[(x,-.68,1.01),(x,-.91,.83),(x,-1.08,.46)],[.085,.095,.025],[.08,.09,.025],'#3D3B33',sides=6,steps=5)
   sweep(a,g,[(x-.021,-.744,.99),(x-.021,-.965,.80),(x-.021,-1.10,.52)],[.03,.034,.009],[.012,.014,.006],'#B4B4A7',sides=4,steps=5)
  a.joint(g,(s*.74,-.07,1.35))
  g='BackLeg'+('.L' if s<0 else '.R')
  for j in range(3):box(a,g,(s*.48+(j-1)*.07,-.16,.075),(.09,.25,.15),'#6C452D',.025)
  a.joint(g,(s*.48,.0,.30))
 a.between('Snout',(0,-.70,1.91),(0,-1.04,1.71),.24,'#C49660',vertices=12,radius2=.13)
 face(a,'Nose',(0,-1.087,1.69),(.22,.16,.20),'#E799A2')
 a.joint('Head',(0,-.04,1.72))
 return done(a)

def owl(lv=False):
 a=pet('auroraOwl',lv,True);teal='#216369';mint='#92DEBC';dark='#13434C'
 loft(a,'Body',[(-.83,.28,.27,0,.02),(-.65,.46,.42,0,.02),(-.25,.61,.49,0,.02),(.22,.65,.51,0,.03),(.55,.54,.45,0,.01),(.71,.34,.29,0,.01)],teal,'tint',sides=20)
 ell(a,'Belly',(0,-.40,-.07),(1.02,.29,1.48),mint,seg=18,rings=10)
 loft(a,'Head',[(.45,.46,.40,0,-.03),(.69,.74,.52,0,-.04),(1.02,.88,.60,0,-.03),(1.39,.86,.59,0,-.01),(1.65,.67,.49,0,.01),(1.74,.40,.32,0,.01)],teal,sides=20,square=2.6)
 for s in (-1,1):
  # Facial discs lie close to the face, with large gold gemstone eyes.
  face(a,'Face',(s*.40,-.58,1.12),(.98,.18,1.15),mint,-s*.22,segments=16)
  face(a,'EyeRims',(s*.40,-.710,1.20),(.56,.15,.60),'#D6AC38',-s*.22,segments=10)
  gem=a.ico('Eyes',(s*.40,-.804,1.20),(.40,.16,.44),'#765112',subdivisions=2)
  for color in ['#DEA846','#886421','#AA7424','#553C16']:gem.data.materials.append(lib.mat(color,'palette'))
  for polygon in gem.data.polygons:polygon.material_index=(polygon.index*7)%5
  face(a,'EyeHighlight',(s*.40-.07,-.897,1.35),(.125,.017,.11),'#FFF0AD',-s*.22,segments=8)
  sweep(a,'Ears',[(s*.56,.01,1.58),(s*.82,.07,1.79),(s*.90,.09,2.20)],[.21,.20,.015],[.18,.15,.015],dark,sides=6,steps=7)
  g='WingsLeft' if s<0 else 'WingsRight'
  ell(a,g,(s*.62,.10,-.05),(.53,.73,1.0),dark,seg=12,rings=8)
  for j in range(3):
   start=(s*.55,.09,.37-j*.07);middle=(s*(.79+j*.065),-.04,-.18-j*.035);end=(s*(.93+j*.075),-.08,-.62+j*.09)
   sweep(a,g,[start,middle,end],[.13,.21,.025],[.10,.13,.015],teal,sides=6,steps=6)
   sweep(a,g+'Glow',[middle,end],[.16,.02],[.075,.01],'#28EAD1','neon',sides=6,steps=4)
  for group in [g,g+'Glow']:a.joint(group,(s*.53,.07,.39));a.meta.setdefault('animation_groups',{})[group]=g
  for j in range(3):a.between('Feet',(s*.30,-.10,-.68),(s*.30+(j-1)*.075,-.37,-.91),.035,'#C7A133',vertices=6,radius2=.018)
 a.between('Beak',(0,-.64,1.02),(0,-.86,.78),.13,'#BD982B',vertices=4,radius2=.02)
 a.ico('Perch',(0,.05,-1.35),(1.29,1.11,1.10),'#29313B',subdivisions=2,seed=8)
 # Pointed meteor underside rather than a round ball pedestal.
 a.between('Perch',(0,.05,-1.70),(.04,.08,-2.00),.32,'#29313B',vertices=5,radius2=0)
 for p,q,r in [((.49,-.30,-1.13),(.57,-.31,-.86),.065),((-.40,-.47,-1.51),(-.38,-.46,-1.30),.045),((.26,-.37,-1.12),(.33,-.40,-.99),.039)]:old.crystal(a,'PerchCrystals',p,q,r,'#88DACC')
 a.ico('PerchFragment',(.72,.07,-1.68),(.18,.18,.21),'#29313B',seed=9)
 for j in range(16):
  t=j*2.39;x=math.cos(t)*.43;z=-1.18-(j%4)*.13
  ell(a,'PerchFlecks',(x,-.46,z),(.014,.01,.020),'#50B3AC',seg=6,rings=4)
 for j in range(3):sweep(a,'Tail',[((j-1)*.16,.35,-.38),((j-1)*.23,.58,-.77)],[.12,.03],[.07,.018],'#35D8CA','neon',sides=6,steps=4)
 a.joint('Head',(0,0,.66));a.joint('Ears',(0,0,.66));a.meta.setdefault('animation_groups',{})['Ears']='Head';a.joint('Tail',(0,.35,-.38))
 for group,parts in a.groups.items():
  if group.endswith('Glow'):
   for o in parts:o.location.y-=0.25
 return done(a)

def drake(lv=False):
 a=pet('meteorDrake',lv);dark='#34303A';lava='#F26312';gold='#FFAE13'
 loft(a,'Body',[(.35,.29,.33,0,.18),(.53,.49,.60,0,.26),(.94,.61,.74,0,.28),(1.33,.57,.63,0,.16),(1.65,.38,.36,0,-.06),(1.84,.27,.26,0,-.19)],dark,'tint',sides=18,square=2.2)
 # Flush segmented orange belly under the short neck.
 loft(a,'Belly',[(.46,.24,.10,0,-.23),(.68,.39,.13,0,-.40),(1.04,.40,.13,0,-.46),(1.38,.32,.12,0,-.40),(1.65,.30,.13,0,-.38)],lava,sides=12,square=2.8)
 loft(a,'Head',[(1.57,.45,.42,0,-.43),(1.76,.69,.55,0,-.47),(2.11,.81,.64,0,-.47),(2.46,.78,.61,0,-.42),(2.73,.59,.44,0,-.34),(2.81,.34,.27,0,-.31)],dark,sides=18,square=2.7)
 box(a,'Muzzle',(0,-1.02,1.98),(1.19,.89,.67),dark,.20)
 box(a,'Jaw',(0,-1.07,1.70),(1.06,.72,.22),lava,.08)
 for s in (-1,1):
  an=s*.62
  # Eyes are recessed in the head flank, with a thick slanted upper brow.
  p=(s*.60,-.92,2.24)
  face(a,'EyeSocket',p,(.55,.11,.60),'#18131D',an)
  face(a,'Eyes',(s*.61,-.99,2.23),(.38,.10,.45),'#FF9617',an,'neon')
  face(a,'Pupils',(s*.61,-1.056,2.23),(.098,.025,.32),'#3D2013',an,segments=12)
  face(a,'EyeHighlight',(s*.61-.057,-1.087,2.36),(.08,.026,.09),'#FFF4C7',an,'neon',segments=10)
  sweep(a,'Brow',[(s*.35,-.86,2.55),(s*.58,-.87,2.56),(s*.80,-.80,2.40)],[.115,.12,.095],[.13,.13,.11],dark,sides=6,steps=5)
  # Horns bend outward, with orange bases and pointed yellow tips.
  sweep(a,'Horns',[(s*.48,-.15,2.69),(s*.70,-.10,2.95),(s*.77,-.11,3.35)],[.17,.15,.01],[.16,.14,.01],'#FB7816',sides=6,steps=6)
  sweep(a,'HornTips',[(s*.69,-.10,3.00),(s*.77,-.11,3.35)],[.12,.006],[.12,.005],gold,'neon',sides=6,steps=4)
  sweep(a,'CheekSpikes',[(s*.67,.00,2.12),(s*.91,.14,2.40)],[.14,.012],[.12,.01],lava,sides=6,steps=4)
  # Bent, thick legs with broad paws instead of straight poles.
  for g,y in [('FrontLeg',-.41),('BackLeg',.77)]:
   n=g+('.L' if s<0 else '.R')
   sweep(a,n,[(s*.47,y,1.07),(s*.55,y-.07,.72),(s*.52,y-.12,.25)], [.24,.20,.18],[.24,.22,.18],dark,sides=8,steps=7)
   box(a,n,(s*.53,y-.27,.17),(.48,.57,.34),dark,.095)
   for j in range(3):a.between(n,(s*.53+(j-1)*.12,y-.45,.15),(s*.53+(j-1)*.12,y-.59,.10),.051,lava,vertices=5,radius2=.011)
   a.joint(n,(s*.47,y,1.07))
  g='WingsLeft' if s<0 else 'WingsRight'
  # Closed membrane with three thick ribs and scalloped trailing silhouette.
  pts=[(s*.51,.45,1.72),(s*.98,.65,2.37),(s*1.64,.79,2.16),(s*1.25,.76,1.91),(s*1.21,.77,1.62),(s*.98,.67,1.80),(s*.77,.65,1.48),(s*.68,.52,1.66)]
  n=len(pts);verts=[(x,y+off,z) for off in (-.035,.035) for x,y,z in pts]
  faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
  a.mesh(g,verts,faces,'#FF8211')
  for end in [pts[2],pts[4],pts[6]]:a.between(g,pts[1],end,.045,dark,vertices=6,radius2=.028)
  a.between(g,pts[0],pts[1],.069,dark,vertices=6)
  a.joint(g,pts[0])
 for j in range(3):
  sweep(a,'Spines',[(0,.02+j*.30,2.72-j*.23),(0,.06+j*.30,3.05-j*.28)],[.13,.01],[.12,.01],'#FD8614',sides=6,steps=4)
 # Tail curves around the flank with a solid pointed ember cluster.
 path=[(0,.95,1.03),(-.50,1.38,.82),(-.91,1.65,.95),(-1.18,1.81,1.27),(-1.19,1.96,1.49)]
 sweep(a,'Tail',path,[.26,.20,.15,.08],[.23,.19,.14,.07],dark,sides=8,steps=12)
 a.tube('LavaCracks',[(-.04,.95,1.24),(-.51,1.36,1.01),(-.99,1.65,1.09),(-1.24,1.80,1.34),(-1.24,1.94,1.52)],.027,'#FF9910','neon',sides=4)
 for j in range(3):
  old.crystal(a,'TailEmber',(-1.19+(j-1)*.10,1.96,1.43),(-1.20+(j-1)*.18,2.05,1.90-abs(j-1)*.13),.12,'#FC8811')
 a.joint('Head',(0,-.29,1.83))
 for g in ['Horns','HornTips','Brow']:a.joint(g,a.joints['Head']);a.meta.setdefault('animation_groups',{})[g]='Head'
 for g in ['Tail','LavaCracks','TailEmber']:a.joint(g,(0,.95,1.03));a.meta.setdefault('animation_groups',{})[g]='Tail'
 # Reference has a dominant baby-dragon head and short, sturdy legs.
 pivot=Vector((0,-0.29,1.83))
 for group,parts in a.groups.items():
  if group in ['Head','Muzzle','Jaw','EyeSocket','Eyes','Pupils','EyeHighlight','Horns','HornTips','CheekSpikes','Brow','Spines']:
   for o in parts:
    o.location=pivot+(o.location-pivot)*1.18;o.scale*=1.18
    if group in ['Muzzle','Jaw']:o.scale.x*=0.87;o.scale.y*=0.82
  if group.startswith('FrontLeg') or group.startswith('BackLeg'):
   for o in parts:o.location.z*=0.87;o.scale.z*=0.87
 return done(a)

def phoenix(lv=False):
 a=pet('solarPhoenix',lv,True);red='#AF2018';orange='#F04C08';gold='#FFA112'
 loft(a,'Body',[(-.75,.22,.22,0,.08),(-.55,.36,.32,0,.04),(-.17,.48,.37,0,.01),(.24,.45,.35,0,.00),(.46,.31,.26,0,-.02),(.57,.24,.22,0,-.03)],orange,'tint',sides=18)
 ell(a,'Breast',(0,-.29,-.04),(.75,.20,1.04),'#FF7412',seg=16)
 loft(a,'Head',[(.40,.31,.30,0,-.13),(.54,.51,.42,0,-.16),(.85,.67,.50,0,-.15),(1.16,.64,.49,0,-.12),(1.41,.51,.40,0,-.09),(1.49,.31,.27,0,-.07)],orange,sides=18,square=2.6)
 for s in (-1,1):
  sweep(a,'Cheeks',[(s*.44,-.09,1.37),(s*.61,-.18,1.04),(s*.51,-.16,.57)],[.18,.20,.13],[.19,.19,.12],red,sides=6,steps=7)
  # Glowing slanted eye panel and dimensional brow mask.
  x=s*.34
  pts=[(x-s*.17,1.14),(x+s*.15,1.04),(x+s*.12,.89),(x-s*.12,.91)]
  o=a.poly('EyeSocket',pts,.085,'#BC390D',bevel=.025);o.location.y=-.60
  pts=[(x-s*.095,1.079),(x+s*.085,1.01),(x+s*.063,.941),(x-s*.068,.96)]
  o=a.poly('Eyes',pts,.022,'#FFF477','neon',bevel=.015);o.location.y=-.665
  sweep(a,'Brow',[(s*.19,-.51,1.25),(s*.39,-.52,1.20),(s*.54,-.40,1.07)],[.075,.105,.06],[.12,.13,.07],orange,sides=6,steps=5)
  g='WingsLeft' if s<0 else 'WingsRight';root=(s*.34,.05,.29)
  # Six broad flame-feathers fan from a curved wing shoulder. All have volume.
  sweep(a,g,[root,(s*.87,.07,.34),(s*1.34,.12,.67)],[.21,.22,.10],[.17,.15,.09],red,sides=8,steps=6)
  for j in range(5):
   start=(s*.53,.04,.33-j*.057)
   mid=(s*(1.24-j*.055),.10,.67-j*.23)
   end=(s*(1.99-j*.13),.10,1.03-j*.34)
   split=Vector(mid)*.75+Vector(end)*.25
   sweep(a,g,[start,mid,split],[.09,.22,.17],[.075,.13,.10],red,sides=6,steps=6)
   sweep(a,g+'Flames',[split,Vector(end)+Vector((s*.10,0,.05))],[.17,.008],[.10,.006],gold,'neon',sides=6,steps=4)
   # Small layered red coverts nest into the main wing.
   sweep(a,g,[root,(s*(.94-j*.04),-.11,.48-j*.15),(s*(1.30-j*.10),-.09,.61-j*.21)],[.09,.13,.012],[.07,.085,.012],'#DE311B',sides=6,steps=5)
  for group in [g,g+'Flames']:a.joint(group,root);a.meta.setdefault('animation_groups',{})[group]=g
  a.between('Feet',(s*.23,-.05,-.59),(s*.27,-.20,-.80),.085,red,vertices=6,radius2=.07)
  for j in range(3):
   sweep(a,'Feet',[(s*.27+(j-1)*.085,-.20,-.80),(s*.27+(j-1)*.10,-.40,-.86),(s*.27+(j-1)*.10,-.43,-.95)],[.065,.07,.025],[.065,.06,.023],orange,sides=6,steps=4)
 # Hooked, faceted beak rather than a long needle.
 loft(a,'Beak',[(.61,.11,.10,0,-.72),(.72,.18,.17,0,-.78),(.90,.20,.14,0,-.70),(1.00,.12,.08,0,-.65)],'#F5A01A',sides=6,square=2)
 # Swept, broad flame crest, with red recessed layers and bright square-ended tops.
 sweep(a,'Crest',[(0,.15,1.30),(-.14,.12,1.69),(-.40,.08,1.92),(-.56,-.02,1.94)],[.25,.22,.16,.10],[.25,.22,.14,.11],red,sides=8,steps=8)
 sweep(a,'Crest',[(-.20,-.06,1.46),(-.40,-.10,1.76),(-.53,-.16,1.82)],[.20,.19,.12],[.18,.16,.10],orange,sides=8,steps=6)
 box(a,'Crest',(-.34,.04,2.01),(.23,.28,.40),gold,.03,rot=(0,-.23,0))
 box(a,'Crest',(-.58,-.11,1.88),(.20,.25,.29),gold,.03,rot=(0,-.35,0))
 # Five broad, curved trailing flames. Root narrow, belly broad, tips curl upward.
 for j in range(5):
  side=-1 if j<2 else 1;x=(j-2)*.17
  path=[(x*.40,.25,-.50),(x,.41,-1.00),(x*1.65,.49,-1.64+abs(j-2)*.08),(x*1.95,.39,-1.68+abs(j-2)*.09),(x*2.08,.31,-1.26+abs(j-2)*.11)]
  sweep(a,'Tail',path,[.10,.18,.21,.16,.016],[.08,.13,.16,.11,.014],red,sides=8,steps=10)
  sweep(a,'TailOrange',[path[1],path[2],path[3]],[.09,.16,.065],[.085,.10,.05],orange,sides=6,steps=6)
  sweep(a,'TailFlames',[path[2],path[3],path[4]],[.14,.12,.012],[.10,.08,.009],gold,'neon',sides=6,steps=6)
 a.joint('Head',(0,-.09,.57))
 for g in ['Crest','Cheeks','Brow']:a.joint(g,a.joints['Head']);a.meta.setdefault('animation_groups',{})[g]='Head'
 for g in ['Tail','TailOrange','TailFlames']:a.joint(g,(0,.25,-.50));a.meta.setdefault('animation_groups',{})[g]='Tail'
 # Match the reference's large head, small chest and substantial trailing flames.
 headpivot=Vector((0,-0.09,0.57))
 for group,parts in a.groups.items():
  if group in ['Head','Cheeks','Eyes','EyeSocket','Brow','Beak','Crest']:
   for o in parts:
    o.location=headpivot+(o.location-headpivot)*Vector((1.06,1.06,1.15))
    o.scale*=Vector((1.06,1.06,1.15))
  if group in ['Body','Breast']:
   for o in parts:o.location.z=o.location.z*0.84+0.085;o.scale.z*=0.84
  if group=='TailFlames':
   for o in parts:o.location.y-=0.15
  if group=='Crest':
   for o in parts:o.location.z=1.40+(o.location.z-1.40)*0.78;o.scale.z*=0.78;o.scale.x*=1.22
 return done(a)

def crystal(a,g,p,q,r,c='#CB28EB'):
 # Six-sided amethyst prism, with distinct colored facet planes.
 p=Vector(p);q=Vector(q);d=q-p;rot=d.to_track_quat('Z','Y');vs=[]
 for t,rr in [(0,r*.65),(.72,r)]:
  for j in range(6):vs.append(p+d*t+rot@Vector((rr*math.cos(math.tau*j/6),rr*math.sin(math.tau*j/6),0)))
 vs.append(q);fs=[tuple(reversed(range(6)))]+[(j,(j+1)%6,(j+1)%6+6,j+6) for j in range(6)]+[(j+6,(j+1)%6+6,12) for j in range(6)]
 o=a.mesh(g,vs,fs,c,'neon')
 for color in ['#8D14B9','#F447F7','#BE23DE']:o.data.materials.append(lib.mat(color,'neon'))
 for poly in o.data.polygons:poly.material_index=(poly.index%4)
 return o

def stag(lv=False):
 a=pet('crystalStag',lv);purple='#9660CE';white='#D8D3E6';dark='#643D9D'
 ell(a,'Body',(0,.31,1.39),(1.01,1.62,1.12),purple,'tint',seg=16,rings=9)
 sweep(a,'Neck',[(0,-.34,1.29),(0,-.52,1.86),(0,-.57,2.48)], [.30,.25,.22],[.29,.24,.22],purple,sides=10,steps=9)
 sweep(a,'Chest',[(0,-.57,1.23),(0,-.72,1.79),(0,-.77,2.12)],[.19,.17,.10],[.065,.06,.045],white,sides=8,steps=7)
 ell(a,'Belly',(0,.22,1.03),(.61,1.23,.28),white,seg=14,rings=7)
 loft(a,'Head',[(2.23,.27,.28,0,-.60),(2.36,.41,.36,0,-.61),(2.60,.46,.40,0,-.64),(2.83,.33,.32,0,-.62),(2.91,.19,.22,0,-.59)],purple,sides=16,square=2.5)
 box(a,'Muzzle',(0,-1.025,2.48),(.66,.59,.39),white,.11)
 box(a,'Nose',(0,-1.337,2.54),(.27,.11,.17),dark,.025)
 for s in (-1,1):
  x=s*.34
  o=a.poly('Eyes',[(x,2.79),(x+.095,2.70),(x,2.62),(x-.09,2.70)],.025,'#C726EA','neon',bevel=0);o.location.y=-.985
  sweep(a,'Ears',[(s*.27,-.46,2.76),(s*.52,-.38,2.92),(s*.77,-.32,2.95)],[.10,.19,.005],[.09,.075,.005],purple,sides=6,steps=6)
  sweep(a,'EarInner',[(s*.36,-.50,2.82),(s*.54,-.45,2.92),(s*.67,-.40,2.94)],[.05,.08,.002],[.02,.018,.002],white,sides=6,steps=5)
  for g,y in [('FrontLeg',-.34),('BackLeg',.85)]:
   n=g+('.L' if s<0 else '.R')
   sweep(a,n,[(s*.34,y,1.35),(s*.35,y+.03,.70),(s*.34,y-.05,.17)],[.115,.083,.060],[.105,.08,.065],purple,sides=6,steps=7)
   box(a,n,(s*.34,y-.09,.10),(.19,.28,.20),dark,.02)
   a.joint(n,(s*.34,y,1.32))
  # The antlers are the dominant feature: broad forks and eighteen pointed crystals.
  crystal(a,'Antlers',(s*.25,-.43,2.83),(s*.74,-.25,4.11),.11)
  crystal(a,'Antlers',(s*.61,-.31,3.55),(s*.70,-.20,4.67),.175,'#D531ED')
  crystal(a,'Antlers',(s*.41,-.34,3.28),(s*1.18,-.19,4.02),.135)
  crystal(a,'Antlers',(s*.82,-.27,3.73),(s*1.27,-.12,4.34),.115)
  crystal(a,'Antlers',(s*.90,-.22,3.72),(s*1.41,-.11,3.98),.075)
  crystal(a,'Antlers',(s*.31,-.43,3.06),(s*.31,-.32,3.75),.10)
  crystal(a,'Antlers',(s*.39,-.43,3.10),(s*.55,-.37,3.54),.072)
  crystal(a,'Antlers',(s*.26,-.44,3.02),(s*.13,-.38,3.51),.067)
  crystal(a,'Antlers',(s*.40,-.43,3.10),(s*.70,-.33,3.31),.062)
 sweep(a,'Tail',[(0,1.04,1.58),(0,1.26,1.49)],[.10,.015],[.075,.01],purple,sides=6,steps=4)
 a.joint('Head',(0,-.57,2.35))
 for g in ['Ears','EarInner','Antlers']:a.joint(g,a.joints['Head']);a.meta.setdefault('animation_groups',{})[g]='Head'
 a.joint('Tail',(0,1.04,1.58))
 return done(a)

def hare(lv=False):
 a=pet('sparkHare',lv);yellow='#F5C616';light='#FFE356';inside='#D6A817'
 loft(a,'Body',[(.42,.32,.38,0,.16),(.66,.49,.72,0,.25),(1.02,.57,.80,0,.30),(1.29,.46,.68,0,.32),(1.45,.22,.35,0,.36)],yellow,'tint',sides=18)
 loft(a,'Head',[(0.95,0.30,0.30,0,-0.57),(1.12,0.47,0.43,0,-0.62),(1.40,0.57,0.50,0,-0.62),(1.67,0.50,0.44,0,-0.57),(1.82,0.32,0.28,0,-0.52)],yellow,sides=16,square=2.7)
 for s in (-1,1):
  x=s*.36
  o=a.poly('EyeSockets',[(x-s*0.16,1.60),(x+s*0.15,1.47),(x+s*0.13,1.28),(x-s*0.12,1.31)],0.025,'#B78310',bevel=0.02);o.location.y=-1.055
  o=a.poly('Eyes',[(x-s*0.09,1.48),(x+s*0.095,1.42),(x+s*0.075,1.35),(x-s*0.065,1.37)],0.018,'#FFF07F','neon',bevel=0.008);o.location.y=-1.083
  ell(a,'Muzzle',(s*0.15,-1.04,1.13),(0.32,0.25,0.31),light,seg=12,rings=7)
  g='FrontLeg'+('.L' if s<0 else '.R')
  sweep(a,g,[(s*0.34,-0.38,0.97),(s*0.30,-0.49,0.61),(s*0.38,-0.65,0.22)], [0.15,0.13,0.10],[0.13,0.12,0.10],yellow,sides=6,steps=6)
  box(a,g,(s*0.38,-0.72,0.13),(0.34,0.48,0.26),yellow,0.06)
  a.joint(g,(s*0.34,-0.38,0.97))
  g='BackLeg'+('.L' if s<0 else '.R')
  ell(a,g,(s*0.48,0.57,0.71),(0.62,0.83,0.94),yellow,seg=14,rings=8)
  sweep(a,g,[(s*0.45,0.70,0.53),(s*0.48,0.44,0.22),(s*0.44,0.09,0.15)],[0.20,0.16,0.13],[0.19,0.16,0.13],yellow,sides=6,steps=6)
  box(a,g,(s*0.45,0.08,0.13),(0.40,0.66,0.26),yellow,0.07)
  a.joint(g,(s*0.45,0.56,0.85))
  # Deep leaf-shaped ears, broad rim, recessed darker inside.
  x=s*0.28;lean=s*(0.17 if s<0 else 0.05)
  points=[(x-s*0.11,1.74),(x-s*0.19,2.04),(x+lean-s*0.10,2.73),(x+lean+s*0.04,3.05),(x+lean+s*0.28,2.85),(x+s*0.33,2.18),(x+s*0.13,1.78)]
  ob=a.poly('Ears',points,0.14,yellow,bevel=0.04);ob.location.y=-0.40
  points=[(x-s*0.03,1.95),(x-s*0.10,2.14),(x+lean-s*0.02,2.70),(x+lean+s*0.04,2.89),(x+lean+s*0.17,2.72),(x+s*0.20,2.19)]
  ob=a.poly('EarInner',points,0.025,inside,bevel=0.02);ob.location.y=-0.49
  x=x+lean
  points=[(x,3.01),(x+s*0.24,3.13),(x+s*0.12,3.32),(x+s*0.42,3.55),(x+s*0.15,3.45),(x-s*0.02,3.28),(x+s*0.08,3.15)]
  ob=a.poly('EarLightning',points,0.065,'#D5A511',bevel=0);ob.location.y=-0.40
 a.ico('Tail',(0,1.08,1.15),(0.60,0.59,0.62),'#EFE7BB',subdivisions=2,seed=6)
 for j in range(3):
  x=(j-1)*0.20
  a.tube('TailSparks',[(x,1.02,1.49),(x+0.07,1.02,1.70),(x-0.02,1.02,1.64),(x+0.04,1.02,1.82)],0.015,'#F9CC22','neon',sides=3)
 face(a,'Nose',(0,-1.207,1.23),(0.16,0.10,0.10),'#D39E16')
 a.joint('Head',(0,-0.49,1.30))
 for g in ['Ears','EarInner','EarLightning']:a.joint(g,(0,-0.39,1.80));a.meta.setdefault('animation_groups',{})[g]='Ears'
 a.joint('Tail',(0,0.98,1.14))
 return done(a)

def wyrm(lv=False):
 a=pet('lodeWyrm',lv,True);copper='#D58628';shadow='#B9651B';highlight='#E8A548'
 points=[(-0.59,-0.04,1.23),(0.02,0.07,1.35),(0.69,0.13,1.03),(0.86,0.11,0.43),(0.58,-0.07,0.06),(-0.11,-0.22,-0.09),(-0.70,-0.08,0.07),(-0.83,0.17,-0.23),(-0.32,0.31,-0.64),(0.39,0.23,-0.91),(0.65,0.03,-1.34),(0.31,-0.19,-1.61),(-0.28,-0.26,-1.62),(-0.63,-0.14,-1.52)]
 # Continuous curved armor: neighboring shells share endpoints and frames.
 count=18;cross=12
 for j in range(count):
  verts=[];faces=[]
  for k in range(5):
   t=(j+k/4)/count;p=curve_point(points,t)
   tangent=curve_point(points,min(1,t+0.002))-curve_point(points,max(0,t-0.002))
   frame=tangent.to_track_quat('Z','Y')
   radius=(0.32+0.055*math.sin(math.pi*k/4))*(1 if j<14 else 1-0.06*(j-14))
   for l in range(cross):
    q=math.tau*l/cross
    verts.append(p+frame@Vector((radius*math.cos(q),radius*math.sin(q),0)))
  for k in range(4):
   for l in range(cross):faces.append((k*cross+l,k*cross+(l+1)%cross,(k+1)*cross+(l+1)%cross,(k+1)*cross+l))
  faces.extend([tuple(reversed(range(cross))),tuple(range(4*cross,5*cross))])
  a.mesh('Body' if j==4 else 'Segments',verts,faces,copper,'tint' if j==4 else 'palette')
  # Narrow seam rings follow the same curve, with rounded corners.
  t=(j+0.025)/count;p=curve_point(points,t);d=curve_point(points,min(1,t+0.002))-curve_point(points,max(0,t-0.002))
  o=a.cylinder('Bands',p,0.326,0.033,shadow,vertices=12);o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
  if j in [2,4,6,8,11,13,16]:
   p=curve_point(points,(j+0.5)/count)
   o=box(a,'Fins',(p.x+0.33,p.y,p.z+0.06),(0.25,0.16,0.10),shadow,0.02);o.modifiers[-1].segments=2
  if 2<=j<=12:
   p=curve_point(points,(j+0.5)/count)
   o=box(a,'BellyGlow',(p.x,p.y-0.405,p.z),(0.28,0.052,0.19),'#FFD348',0.02,'neon');o.modifiers[-1].segments=1
 # Angular but rounded mechanical head shell.
 box(a,'Head',(-0.63,-0.30,1.27),(0.95,1.05,0.75),copper,0.19)
 box(a,'HeadTop',(-0.63,-0.29,1.64),(0.48,0.52,0.10),highlight,0.04)
 for s in (-1,1):
  x=-0.63+s*0.42
  box(a,'EyeSocket',(-0.63+s*0.49,-0.45,1.30),(0.08,0.25,0.14),shadow,0.025)
  for k in range(2):face(a,'Eyes',(-0.63+s*0.54,-0.53+k*0.10,1.30),(0.068,0.035,0.071),'#FFDD58',s*math.pi/2,'neon',segments=10)
  a.cylinder('CheekBolt',(-0.63+s*0.50,-0.28,1.17),0.13,0.075,shadow,vertices=6,rot=(0,math.pi/2,0))
  a.cylinder('CheekBolt',(-0.63+s*0.55,-0.28,1.17),0.068,0.010,copper,vertices=6,rot=(0,math.pi/2,0))
 # Long stepped conical drill; spiral ridge is actual geometry.
 start=Vector((-0.63,-0.79,1.24));end=Vector((-0.63,-1.80,1.13))
 a.between('Drill',start,end,0.31,copper,vertices=16,radius2=0.012)
 for k in range(6):
  t=k/7;pos=start.lerp(end,t);rad=0.30
  rad=0.31*(1-t)
  o=a.cylinder('DrillRings',pos,rad,0.042,shadow,vertices=16);o.rotation_euler=(end-start).to_track_quat('Z','Y').to_euler()
 curve=[];rot=(end-start).to_track_quat('Z','Y')
 for k in range(65):
  t=k/64;r=0.315*(1-t)+0.008;q=t*math.tau*5
  curve.append(start.lerp(end,t)+rot@Vector((r*math.cos(q),r*math.sin(q),0)))
 a.tube('DrillRidge',curve,0.016,highlight,'palette',sides=5)
 a.joint('Head',(-0.49,-0.04,1.26))
 for g in ['HeadTop','CheekBolt']:a.joint(g,a.joints['Head']);a.meta.setdefault('animation_groups',{})[g]='Head'
 for g in ['Drill','DrillRings','DrillRidge']:a.joint(g,start);a.meta.setdefault('animation_groups',{})[g]='Drill'
 return done(a)

BUILDERS={'solarPhoenix':phoenix,'auroraOwl':owl,'coinMagpie':magpie,'meteorDrake':drake,
 'pebblePup':pup,'cargoMole':mole,'crystalStag':stag,'lodeWyrm':wyrm,'sparkHare':hare}

def setup_pipeline():
 old.normalize_finish()
 original=Asset.setup_preview
 def setup(a,lo,hi):
  original(a,lo,hi)
  s=a.scene;center=(lo+hi)/2;size=max(hi-lo)
  camera=s.camera
  direction=(-1.35,-2.15,0.92)
  if a.meta['Reference']==REFS['lodeWyrm']:direction=(1.4,-2.4,0.72)
  camera.location=center+Vector(direction)*size
  camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
  camera.data.ortho_scale=size*1.12
  if a.meta['Reference']==REFS['meteorDrake']:
   camera.data.ortho_scale=size*1.38
  for m in bpy.data.materials:
   if not m.use_nodes:continue
   p=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
   if p:
    p.inputs['Roughness'].default_value=0.42
    p.inputs['Specular IOR Level'].default_value=0.38
   # Faceted emissive objects keep color variation in their individual materials.
   if m.get('Mode')=='neon':
    output=next(n for n in m.node_tree.nodes if n.type=='OUTPUT_MATERIAL')
    m.node_tree.links.new(p.outputs['BSDF'],output.inputs['Surface'])
    p.inputs['Roughness'].default_value=0.24
    p.inputs['Specular IOR Level'].default_value=0.5
    p.inputs['Emission Color'].default_value=lib.rgba(m['Ramp'][1])
    p.inputs['Emission Strength'].default_value=0.40
  # Shadow-catching preview floor is not exported or counted as a pet mesh.
  bpy.ops.mesh.primitive_plane_add(size=size*200,location=(0,0,lo.z-(0.38 if a.meta['Flying'] else 0.018)))
  floor=bpy.context.object;floor.name='PreviewShadowFloor';floor.is_shadow_catcher=True
  floor.data.materials.append(lib.mat('#F9F9F9','preview'))
  try:
   s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=32;s.cycles.use_denoising=True
  except TypeError:pass
  s.view_settings.exposure=-0.25
  try:s.view_settings.view_transform='Standard'
  except TypeError:pass
  for o in s.objects:
   if o.type=='LIGHT':o.data.energy*=0.70 if o.name=='Key' else 0.45
  background=next(n for n in s.world.node_tree.nodes if n.type=='BACKGROUND')
  background.inputs['Strength'].default_value=0.32
 Asset.setup_preview=setup

def validate(reports):
 checked=[];previous=bpy.context.window.scene
 for r in reports:
  path=OUT/r['id'];s=bpy.data.scenes.new('V2_FBX_Validation');bpy.context.window.scene=s
  try:
   bpy.ops.import_scene.fbx(filepath=str(path.with_suffix('.fbx')),use_custom_props=True)
   meshes=[o for o in s.objects if o.type=='MESH'];tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
   assert tris==r['triangles'] and tris<=8000
   assert len(meshes)==len(r['objects']) and any(o.get('RobloxName')=='Body' for o in meshes)
   bpy.context.view_layer.update();pts=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
   dim=[max(p[i] for p in pts)-min(p[i] for p in pts) for i in range(3)]
   assert max(abs(dim[i]-r['dimensions_blender'][i]) for i in range(3))<0.02
   for o in meshes:
    assert max(abs(v-1) for v in o.scale)<0.001
    tex=any(n.type=='TEX_IMAGE' for m in o.data.materials for n in m.node_tree.nodes)
    if o.get('RuntimeTint') or o.get('RobloxMaterial')=='Neon':assert not tex
    if o.get('RuntimeTint'):
     for m in o.data.materials:
      p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');assert min(p.inputs['Base Color'].default_value[:3])>0.90
    if tex:
     assert len(o.data.uv_layers)==1
     for p in o.data.polygons:
      uv=[o.data.uv_layers[0].data[i].uv for i in p.loop_indices];assert all((x-uv[0]).length<0.000001 for x in uv)
    if o.get('AnimationGroup'):assert o.get('AnimationPivot') is not None
   data=path.with_suffix('.png').read_bytes();assert struct.unpack('>IIBB',data[16:26])[0:2]==(512,512) and data[25]==6
   checked.append({'id':r['id'],'triangles':tris,'dimensions':dim,'mesh_count':len(meshes),'passed':True})
  finally:
   for o in list(s.objects):bpy.data.objects.remove(o,do_unlink=True)
   bpy.context.window.scene=previous;bpy.data.scenes.remove(s)
 (OUT/'validation.json').write_text(json.dumps(checked,indent=2));print('VALIDATION_PASSED',len(checked))

def main():
 setup_pipeline();reports=[]
 selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(BUILDERS)
 for name in selected:
  for lv in (False,True):reports.append(BUILDERS[name](lv))
 if len(selected)==9:(OUT/'manifest.json').write_text(json.dumps(reports,indent=2))
 (OUT/'previews').mkdir(exist_ok=True)
 for r in reports:shutil.copy2((OUT/r['id']).with_suffix('.png'),OUT/'previews'/((OUT/r['id']).name+'.png'))
 validate(reports)
 print('V2_COMPLETE',len(reports))

if __name__=='__main__':main()






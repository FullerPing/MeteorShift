"""Reference-led pet set, isolated from the original catalog.

Run with Blender --background --python this_file.py. Nine supplied unique images,
two looks each. No Studio changes. All shapes are editable authored geometry.
"""
import sys, json, math, shutil, struct
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import assetlib as lib
from assetlib import Asset, Vector, bpy

BASE = Path('Z:/final-final-actual-final/MeteorShift')
OUT = BASE / 'blender/pets/reference-set'
OUT.mkdir(parents=True, exist_ok=True)
lib.ROOT = OUT
lib.SWATCHFILE = OUT / 'palette-swatches.json'
lib.SWATCHES = list(dict.fromkeys(sum(lib.RAMPS.values(), []) + list(lib.SINGLES.values())))
REFS = {
 'solarPhoenix': 'Phoenix_bird_game_pass_icon_20261010224324.jpg',
 'auroraOwl': 'Horned_owl_toy_perched_20261010224724.jpg',
 'coinMagpie': 'Low-poly_magpie_carrying_gold_coin_20261010224732.jpg',
 'meteorDrake': 'Chunky_low-poly_baby_dragon_20261010224739.jpg',
 'pebblePup': 'Blocky_puppy_game_asset_20261010224749.jpg',
 'cargoMole': 'Low-poly_mole_pet_digging_20261010224803.jpg',
 'crystalStag': 'Miniature_deer_with_crystal_antlers_20261010224821.jpg',
 'lodeWyrm': 'Serpentine_wyrm_toy_floating_spiral_20261010224835.jpg',
 'sparkHare': 'Low-poly_bunny_pet_crouching_20261010224943.jpg',
}
# There are NINE unique images: phoenix, owl, magpie, dragon, pup, mole,
# stag, wyrm and hare. Clipboard images repeat the mole.
COLORS = {'solarPhoenix':'#E64215','auroraOwl':'#215C62','coinMagpie':'#F0B91B',
 'meteorDrake':'#38343F','pebblePup':'#80858A','cargoMole':'#98603E',
 'crystalStag':'#9362CE','lodeWyrm':'#C87721','sparkHare':'#F3C91C'}

def pet(ident,lv,flying=False):
 a=Asset('models/'+ident+('_lv10' if lv else ''),budget=7000)
 a.meta.update(PetColor=COLORS[ident],Level10=lv,PrimaryPart='Body',FrontAxis='-Y',
  Flying=flying,PivotType='BodyCenter' if flying else 'BottomCenter',
  Reference=REFS[ident],ReferencePriority='silhouette, proportions, palette, distinctive details',
  Level10Approach='Subtle enlargement of signature details; retain reference silhouette')
 return a

def orb(a,g,p,s,c,mode='palette'):
 return a.ellipsoid(g,p,s,c,mode,segments=12,rings=8)

def ico(a,g,p,s,c,mode='palette'):
 return a.ico(g,p,s,c,mode,subdivisions=2)

def eye(a,g,p,s=.18,c='#251A18',glow=False):
 orb(a,g,p,(s,.075,s*1.12),c,'neon' if glow else 'palette')
 if not glow: orb(a,g,(p[0]-.025,p[1]-.043,p[2]+s*.23),(s*.22,.025,s*.25),'white')

def joints(a):
 for g in list(a.groups):
  if g.startswith('FrontLeg') or g.startswith('BackLeg'):
   ps=a.groups[g]; p=ps[0].location.copy(); p.z+=.22; a.joint(g,p)

def blade(a,g,start,end,width,c,mode='palette',depth=.09):
 # Thick faceted tapered feather, visible from both sides.
 p=Vector(start); q=Vector(end); d=q-p
 side=Vector((-d.z,0,d.x)).normalized()*width
 mid=p+d*.48
 verts=[p+Vector((0,-depth,0)),p+Vector((0,depth,0)),
  mid+side,mid-side,q,mid+Vector((0,-depth*1.8,0)),mid+Vector((0,depth*1.8,0))]
 faces=[(0,2,5),(2,4,5),(4,3,5),(3,0,5),(1,6,2),(2,6,4),(4,6,3),(3,6,1),(0,1,2),(0,3,1)]
 return a.mesh(g,verts,faces,c,mode)

def crystal(a,g,start,end,r,c='#DA43F1'):
 # Hexagonal prism with pointed termination, rather than a cone spike.
 p=Vector(start); q=Vector(end); d=q-p; rot=d.to_track_quat('Z','Y')
 verts=[]
 for t,rr in [(0,r*.65),(.74,r)]:
  for j in range(6): verts.append(p+d*t+rot@Vector((rr*math.cos(j*math.tau/6),rr*math.sin(j*math.tau/6),0)))
 verts.append(q)
 faces=[tuple(reversed(range(6)))]+[(j,(j+1)%6,(j+1)%6+6,j+6) for j in range(6)]+[(j+6,(j+1)%6+6,12) for j in range(6)]
 return a.mesh(g,verts,faces,c,'neon')

def finish(a,lv):
 # Root origin is bottom center for ground pets, torso center for flyers.
 # Joint mesh origins are deliberately preserved and recorded in JSON.
 if lv:
  a.meta['Level10Variant']='Same reference design, enhanced signature accents only'
 # Separate material meshes still move together around the actual head joint.
 if 'Head' in a.joints:
  for group in ['Muzzle','Nose','Eyes','Headband','Cap','LampHousing','Lamp','LampTrim',
   'Snout','Beak','Face','EyeRims','EyeSocket','EyeSockets','Pupils','EyeHighlight',
   'Horns','CheekSpikes','Jaw','CrownAccent','HeadTrim']:
   if group in a.groups:
    a.joint(group,a.joints['Head'])
    a.meta.setdefault('animation_groups',{})[group]='Head'
 return a.finish()

def pup(lv=False):
 a=pet('pebblePup',lv)
 gray='#80858A'; pale='#989DA1'
 a.box('Body',(0,.18,1.05),(1.48,1.90,1.35),COLORS['pebblePup'],.20,'tint')
 a.box('Head',(0,-.58,1.94),(1.94,1.47,1.76),gray,.25)
 a.box('Muzzle',(0,-1.36,1.58),(.86,.27,.54),pale,.09)
 a.box('Nose',(0,-1.53,1.78),(.30,.17,.23),'#525659',.05)
 for s in (-1,1):
  eye(a,'Eyes',(s*.43,-1.331,2.09),.14,'#191A1C')
  a.box('Ears',(s*.94,-.31,2.03),(.40,.74,.85),'#6E7478',.11,rot=(0,s*.28,0))
  for g,y in [('FrontLeg',-.48),('BackLeg',.79)]:
   a.box(g+('.L' if s<0 else '.R'),(s*.53,y,.29),(.48,.55,.58),gray,.07)
 a.box('Collar',(0,-.67,1.00),(1.66,.83,.24),'#DA3B33',.065)
 a.box('Collar',(0,-1.13,1.02),(.23,.08,.26),'steel',.015)
 a.between('Tag',(0,-1.11,.98),(0,-1.14,.76),.035,'ink',vertices=6)
 a.box('Tag',(0,-1.17,.65),(.12,.07,.36),'steel',.01)
 blade(a,'Tag',(-.28,-1.18,.78),(.28,-1.18,.80),.09,'#45464A')
 a.tube('Tail',[(0,1.02,1.23),(.10,1.30,1.57),(.18,1.46,1.82)],.14,gray,'palette',sides=5)
 a.joint('Head',(0,-.35,1.51));a.joint('Ears',(0,-.35,2.40));a.joint('Tail',(0,1.02,1.23));joints(a)
 if lv:a.box('CollarBadge',(0,-1.26,1.36),(.12,.06,.13),'equipment_gold',.025)
 return finish(a,lv)

def mole(lv=False):
 a=pet('cargoMole',lv)
 orb(a,'Body',(0,.14,1.33),(1.98,1.70,2.26),COLORS['cargoMole'],'tint')
 orb(a,'Head',(0,-.59,1.95),(1.73,1.01,1.22),'#A36A44')
 a.cylinder('Cap',(0,-.07,2.50),.96,.14,'#9E694A',vertices=12)
 a.ring('Headband',(0,-.04,2.37),.91,.08,'#49392F',axis='Z',segments=16,sides=4)
 a.cylinder('LampHousing',(0,-.967,2.35),.20,.08,'#D6B773',vertices=8,rot=(math.pi/2,0,0))
 a.cylinder('Lamp',(0,-1.02,2.35),.14,.025,'#FFEE83','neon',vertices=8,rot=(math.pi/2,0,0))
 a.between('Snout',(0,-.87,1.94),(0,-1.32,1.79),.30,'#BE8B54',vertices=10,radius2=.12)
 orb(a,'Nose',(0,-1.34,1.78),(.22,.17,.20),'#E5979B')
 for s in (-1,1):
  a.box('Eyes',(s*.44,-1.017,2.00),(.10,.055,.055),'#5E412C',.015)
  g='FrontLeg'+('.L' if s<0 else '.R')
  orb(a,g,(s*.91,-.48,1.16),(.69,.73,.75),'#A46B43')
  for j in range(3):
   x=s*(.70+j*.21)
   blade(a,g,(x,-.85,1.10),(x,-1.28,.59),.09,'#414039',depth=.09)
   blade(a,g,(x-.024,-.925,1.04),(x-.024,-1.25,.65),.035,'#AFAD99',depth=.013)
  foot='BackLeg'+('.L' if s<0 else '.R')
  a.box(foot,(s*.48,-.08,.10),(.30,.35,.20),'#68452E',.04)
  for j in range(3):a.between(foot,(s*.48+(j-1)*.08,-.18,.08),(s*.48+(j-1)*.08,-.36,.035),.045,'#68452E',vertices=4,radius2=.014)
 a.joint('Head',(0,-.31,1.74));joints(a)
 if lv:a.ring('LampTrim',(0,-1.03,2.35),.18,.025,'equipment_gold',axis='Y',segments=12,sides=4)
 return finish(a,lv)

def magpie(lv=False):
 a=pet('coinMagpie',lv)
 dark='#363A44'; gold='#F0B91B'
 orb(a,'Body',(0,.10,1.07),(1.70,1.62,1.65),gold,'tint')
 ico(a,'Back',(0,.47,1.42),(1.50,1.18,1.36),dark)
 ico(a,'Head',(0,-.47,2.04),(1.48,1.37,1.45),dark)
 a.between('Beak',(0,-1.00,1.99),(0,-1.52,1.89),.25,'#474B55',vertices=4,radius2=0)
 for s in (-1,1):
  eye(a,'Eyes',(s*.48,-1.018,2.21),.18)
  wing='WingsLeft' if s<0 else 'WingsRight'
  ico(a,wing,(s*.76,.11,1.40),(.54,1.16,.87),gold)
  for j in range(3):blade(a,wing,(s*.76,-.06,1.33),(s*(.86+j*.03),.73+j*.09,.82+j*.12),.19,dark)
  a.joint(wing,(s*.57,-.02,1.66))
  g='Feet'+('.L' if s<0 else '.R')
  a.between(g,(s*.40,.03,.47),(s*.40,-.10,.14),.065,'#AC791C',vertices=5)
  for j in range(3):a.between(g,(s*.40,-.10,.13),(s*.40+(j-1)*.11,-.43,.08),.044,'#AC791C',vertices=5)
 for j in range(3):
  blade(a,'Tail',((j-1)*.17,.68,1.28),((j-1)*.35,1.83,2.72-abs(j-1)*.23),.20,dark,depth=.12)
 a.cylinder('Coin',(0,-1.51,1.83),.44,.09,'#F5CA37',vertices=16)
 a.ring('Coin',(0,-1.51,1.889),.39,.03,'#E9AC16',axis='Z',segments=16,sides=4)
 a.joint('Head',(0,-.25,1.68));a.joint('Tail',(0,.67,1.26));a.joint('Coin',(0,-1.15,1.94))
 if lv:a.ring('Coin',(0,-1.51,1.90),.25,.013,'#FFF083',axis='Z',segments=16,sides=4)
 return finish(a,lv)

def owl(lv=False):
 a=pet('auroraOwl',lv,True)
 teal='#24565E'; mint='#8DDEB9'
 orb(a,'Body',(0,.03,0),(1.51,1.28,1.74),teal,'tint')
 orb(a,'Belly',(0,-.52,-.07),(1.06,.31,1.52),mint)
 ico(a,'Head',(0,-.08,1.07),(1.91,1.30,1.57),teal)
 for s in (-1,1):
  orb(a,'Face',(s*.43,-.68,1.09),(.96,.23,1.16),mint)
  a.cylinder('EyeRims',(s*.43,-.825,1.19),.31,.10,'#CCA127',vertices=8,rot=(math.pi/2,0,0))
  ico(a,'Eyes',(s*.43,-.914,1.19),(.42,.14,.46),'#6D4A10')
  ico(a,'Eyes',(s*.43-.06,-1.00,1.32),(.13,.025,.12),'#FFF5BC')
  blade(a,'Ears',(s*.64,-.01,1.61),(s*.95,.12,2.27),.21,teal,depth=.14)
  wing='WingsLeft' if s<0 else 'WingsRight'
  ico(a,wing,(s*.68,.01,.03),(.54,.79,1.10),teal)
  for j in range(3):
   end=(s*(.96+j*.12),.03+j*.04,-.65+j*.12)
   blade(a,wing,(s*.59,-.02,.38-j*.10),end,.18,teal)
   blade(a,wing+'Glow',(s*(.82+j*.07),-.06,-.23+j*.05),end,.15,'#25F3DA','neon')
  a.joint(wing,(s*.58,0,.50));a.joint(wing+'Glow',(s*.58,0,.50));a.meta.setdefault('animation_groups',{})[wing+'Glow']=wing
  for j in range(3):a.between('Feet',(s*.34,-.17,-.69),(s*.34+(j-1)*.09,-.44,-.92),.045,'#D1A92C',vertices=5,radius2=.015)
 a.between('Beak',(0,-.73,.96),(0,-.98,.77),.14,'#BD9625',vertices=4,radius2=0)
 ico(a,'Perch',(0,.00,-1.38),(1.42,1.31,1.20),'#29313A')
 for p,q,r in [((.54,-.36,-1.06),(.64,-.41,-.77),.07),((-.49,-.51,-1.42),(-.42,-.54,-1.17),.06),((.38,.20,-1.84),(.52,.18,-1.69),.06)]:
  crystal(a,'PerchCrystals',p,q,r,'#75DAD0')
 ico(a,'PerchFragment',(.83,.10,-1.68),(.20,.21,.21),'#29313A')
 for j in range(9):orb(a,'PerchFlecks',((j%3-1)*.30,-.58,-1.08-(j//3)*.24),(.027,.02,.028),'#57BEB5')
 for j in range(3):blade(a,'Tail',((j-1)*.16,.46,-.35),((j-1)*.24,.80,-.90),.13,'#39DCC8','neon')
 a.joint('Head',(0,-.05,.73));a.joint('Tail',(0,.43,-.35));a.joint('Ears',(0,0,1.70))
 if lv:crystal(a,'PerchCrystals',(-.59,.05,-1.03),(-.77,.05,-.60),.09,'#75DAD0')
 return finish(a,lv)

def stag(lv=False):
 a=pet('crystalStag',lv)
 purple='#9362CE';white='#D5CEDF'
 ico(a,'Body',(0,.33,1.32),(1.02,1.67,1.09),purple,'tint')
 a.between('Neck',(0,-.39,1.45),(0,-.64,2.47),.30,purple,vertices=8,radius2=.24)
 ico(a,'Chest',(0,-.51,1.61),(.59,.29,.89),white)
 ico(a,'Head',(0,-.70,2.61),(.90,.93,.76),purple)
 ico(a,'Muzzle',(0,-1.22,2.48),(.61,.55,.40),white)
 ico(a,'Nose',(0,-1.46,2.55),(.27,.14,.19),'#634093')
 for s in (-1,1):
  x=s*.30
  o=a.poly('Eyes',[(x,2.81),(x+.09,2.74),(x,2.67),(x-.09,2.74)],.026,'#C22FEA','neon',bevel=0);o.location.y=-1.038
  blade(a,'Ears',(s*.27,-.53,2.83),(s*.74,-.41,3.03),.16,purple)
  blade(a,'EarInner',(s*.32,-.61,2.84),(s*.63,-.51,2.97),.085,white)
  for g,y in [('FrontLeg',-.34),('BackLeg',.86)]:
   n=g+('.L' if s<0 else '.R')
   a.between(n,(s*.34,y,1.30),(s*.34,y-.08,.20),.115,purple,vertices=6,radius2=.075)
   a.box(n,(s*.34,y-.12,.11),(.19,.29,.22),'#674294',.02)
  # Antlers spread broadly into distinct pointed amethyst clusters.
  extra=.10 if lv else 0
  crystal(a,'Antlers',(s*.29,-.47,2.87),(s*.82,-.31,4.15+extra),.12)
  crystal(a,'Antlers',(s*.60,-.38,3.56),(s*.72,-.26,4.64+extra),.17,'#DC40F1')
  crystal(a,'Antlers',(s*.50,-.38,3.30),(s*1.21,-.24,3.99+extra),.14,'#BF2ADB')
  crystal(a,'Antlers',(s*.81,-.33,3.79),(s*1.26,-.20,4.33+extra),.12,'#CF3BED')
  crystal(a,'Antlers',(s*.32,-.44,3.04),(s*.35,-.32,3.71),.105,'#B32BD0')
  crystal(a,'Antlers',(s*.94,-.30,3.72),(s*1.41,-.20,3.95),.09,'#CF3BED')
  crystal(a,'Antlers',(s*.30,-.52,3.03),(s*.67,-.58,3.28),.08,'#CA2DE5')
  crystal(a,'Antlers',(s*.31,-.54,3.07),(s*.15,-.58,3.53),.075,'#D342ED')
  crystal(a,'Antlers',(s*.40,-.53,3.14),(s*.54,-.56,3.50),.08,'#B826D6')
 a.tube('Tail',[(0,1.04,1.61),(0,1.33,1.52)],.10,purple,'palette')
 a.joint('Head',(0,-.58,2.39));a.joint('Antlers',(0,-.58,2.39));a.meta.setdefault('animation_groups',{})['Antlers']='Head';a.joint('Tail',(0,1.02,1.56));joints(a)
 # Reference antlers are oversized; preserve proportions, normalize whole pet to 3.5 studs.
 return finish(a,lv)

def hare(lv=False):
 a=pet('sparkHare',lv)
 yellow='#F3C91C'; cream='#F1E9BC'
 ico(a,'Body',(0,.25,.96),(1.12,1.61,1.10),yellow,'tint')
 ico(a,'Head',(0,-.57,1.30),(1.07,1.12,1.06),yellow)
 for s in (-1,1):
  x=s*.32
  o=a.poly('EyeSockets',[(x-s*.20,1.62),(x+s*.16,1.48),(x+s*.15,1.29),(x-s*.16,1.33)],.04,'#B97F08',bevel=.015);o.location.y=-1.061
  o=a.poly('Eyes',[(x-s*.09,1.49),(x+s*.10,1.42),(x+s*.08,1.35),(x-s*.08,1.37)],.022,'#FFF17E','neon',bevel=0);o.location.y=-1.091
  ico(a,'Muzzle',(s*.15,-1.084,1.11),(.31,.23,.29),'#F9DB55')
  g='FrontLeg'+('.L' if s<0 else '.R'); bg='BackLeg'+('.L' if s<0 else '.R')
  a.between(g,(s*.35,-.43,.89),(s*.38,-.68,.25),.14,yellow,vertices=6,radius2=.11)
  a.box(g,(s*.38,-.78,.13),(.33,.44,.26),yellow,.07)
  ico(a,bg,(s*.45,.62,.60),(.57,.79,.84),yellow)
  a.box(bg,(s*.43,.23,.13),(.40,.66,.26),yellow,.07)
  # Broad leaf ears, thick raised rim, darker recessed center.
  x=s*.30
  pts=[(x-s*.12,1.65),(x-s*.20,2.01),(x+s*.04,2.88),(x+s*.29,2.69),(x+s*.34,2.04),(x+s*.15,1.70)]
  ob=a.poly('Ears',pts,.16,yellow,bevel=.035);ob.location.y=-.45
  inner=[(x-s*.055,1.89),(x-s*.12,2.07),(x+s*.045,2.70),(x+s*.19,2.57),(x+s*.22,2.10)]
  ob=a.poly('EarInner',inner,.025,'#D6A71A',bevel=.01);ob.location.y=-.545
  # Angular lightning ornaments on both ear tips.
  pts=[(x+s*.04,2.90),(x+s*.26,3.00),(x+s*.15,3.18),(x+s*.45,3.42),(x+s*.16,3.33),(x-s*.01,3.14),(x+s*.09,3.01)]
  ob=a.poly('EarLightning',pts,.07,'#D2A30D',bevel=0);ob.location.y=-.44
 ico(a,'Tail',(0,1.08,1.10),(.55,.59,.60),cream)
 for j in range(3):
  x=(j-1)*.28
  a.tube('TailSparks',[(x,.98,1.48),(x+.07,1.00,1.68),(x-.03,1.00,1.63),(x+.04,1.00,1.83)],.017,'#F3C91C','neon',sides=3)
 ico(a,'Nose',(0,-1.229,1.20),(.17,.13,.11),'#C98C15')
 a.joint('Head',(0,-.40,1.15));a.joint('Ears',(0,-.44,1.77));a.joint('EarInner',(0,-.44,1.77));a.joint('EarLightning',(0,-.44,1.77));a.joint('Tail',(0,.98,1.10));joints(a)
 for g in ['EarInner','EarLightning']:a.meta.setdefault('animation_groups',{})[g]='Ears'
 if lv: a.tube('PawSparks',[(-.43,-.80,.20),(-.35,-.90,.34),(-.24,-.91,.25)],.023,'#FFE57A','neon',sides=3)
 return finish(a,lv)

def drake(lv=False):
 a=pet('meteorDrake',lv)
 dark='#38343F';orange='#EC6419'
 ico(a,'Body',(0,.24,1.15),(1.32,1.60,1.55),dark,'tint')
 ico(a,'Belly',(0,-.43,1.12),(.77,.35,1.22),orange)
 ico(a,'Head',(0,-.48,2.19),(1.67,1.37,1.39),dark)
 ico(a,'Muzzle',(0,-1.08,1.96),(1.25,.91,.70),dark)
 ico(a,'Jaw',(0,-1.10,1.70),(1.04,.72,.35),orange)
 for s in (-1,1):
  orb(a,'EyeSocket',(s*.58,-.98,2.28),(.47,.16,.53),'#17131B')
  orb(a,'Eyes',(s*.58,-1.084,2.28),(.34,.11,.41),'#FF911C','neon')
  orb(a,'Pupils',(s*.58,-1.149,2.29),(.095,.023,.28),'#482211')
  orb(a,'EyeHighlight',(s*.58-.045,-1.166,2.42),(.074,.019,.083),'#FFF5BC','neon')
  crystal(a,'Horns',(s*.57,-.22,2.64),(s*.78,-.12,3.31),.17,'#FFB326')
  blade(a,'CheekSpikes',(s*.63,-.01,2.11),(s*.94,.15,2.48),.14,orange)
  for g,y in [('FrontLeg',-.37),('BackLeg',.75)]:
   n=g+('.L' if s<0 else '.R')
   a.between(n,(s*.50,y,1.02),(s*.53,y-.05,.25),.21,dark,vertices=6,radius2=.18)
   ico(a,n,(s*.53,y-.16,.18),(.48,.56,.35),dark)
   for j in range(3):a.between(n,(s*.53+(j-1)*.11,y-.28,.18),(s*.53+(j-1)*.11,y-.45,.11),.065,orange,vertices=4,radius2=0)
  g='WingsLeft' if s<0 else 'WingsRight'
  root=(s*.49,.51,1.78); elbow=(s*1.04,.68,2.36)
  tips=[(s*1.75,.82,2.15),(s*1.41,.83,1.70),(s*.96,.82,1.48)]
  verts=[root,elbow]+tips+[(s*.65,.60,1.56)]
  a.mesh(g,verts,[(0,1,2),(0,2,3),(0,3,4),(0,4,5)],orange)
  for end in tips:a.between(g,elbow,end,.055,dark,vertices=5,radius2=.025)
  a.between(g,root,elbow,.075,dark,vertices=5)
  a.joint(g,root)
 for j in range(3):crystal(a,'Spines',(0,.07+j*.32,2.67-j*.27),(0,.12+j*.32,3.06-j*.31),.12,'#FF8D1A')
 tail=[(0,.87,1.01),(-.36,1.39,.83),(-.75,1.84,.89),(-1.05,2.15,1.18),(-1.12,2.35,1.44)]
 a.tube('Tail',tail,.20,dark,'palette',sides=6)
 a.tube('LavaCracks',[(-.04,1.02,1.18),(-.36,1.45,1.01),(-.76,1.87,1.07),(-1.07,2.13,1.24),(-1.16,2.30,1.47)],.035,'#FFA124','neon',sides=4)
 for j in range(3):crystal(a,'TailFlame',(-1.12,2.32,1.40),(-1.12+(j-1)*.18,2.38,1.85-abs(j-1)*.12),.10,'#FF9B1A')
 a.joint('Head',(0,-.21,1.79));a.joint('Tail',(0,.87,1.01));a.joint('LavaCracks',(0,.87,1.01));a.joint('TailFlame',(0,.87,1.01));joints(a)
 for g in ['LavaCracks','TailFlame']:a.meta.setdefault('animation_groups',{})[g]='Tail'
 if lv:crystal(a,'CrownAccent',(0,-.20,2.73),(0,-.13,3.29),.14,'#FFB326')
 return finish(a,lv)

def phoenix(lv=False):
 a=pet('solarPhoenix',lv,True)
 red='#B7241C';orange='#F35D18';yellow='#FFAA16'
 ico(a,'Body',(0,0,0),(1.15,1.03,1.46),orange,'tint')
 ico(a,'Breast',(0,-.45,.05),(.84,.24,1.12),'#FF7F18')
 ico(a,'Head',(0,-.19,1.00),(1.55,1.19,1.37),orange)
 for s in (-1,1):
  ico(a,'Cheeks',(s*.60,-.12,.99),(.40,.90,1.15),red)
  a.poly('EyeSocket',[(s*.14,.98),(s*.24,1.28),(s*.48,1.12),(s*.44,.95)],.10,'#B83912',bevel=0).location.y=-.75
  a.poly('Eyes',[(s*.21,1.02),(s*.25,1.19),(s*.42,1.10),(s*.39,.99)],.025,'#FFF482','neon',bevel=0).location.y=-.818
  g='WingsLeft' if s<0 else 'WingsRight'
  root=(s*.44,0,.35)
  for j in range(5):
   tip=(s*(2.09-j*.14),.08,.99-j*.37)
   blade(a,g,root,tip,.23,red,depth=.12)
   start=(s*(1.04-j*.035),.08,.66-j*.23)
   blade(a,g+'Tips',start,(tip[0]+s*.26,tip[1],tip[2]+.05),.18,yellow,'neon',depth=.10)
   blade(a,g+'Coverts',(s*.45,-.14,.36-j*.075),(s*(1.49-j*.15),-.14,.60-j*.29),.15,'#D32D22',depth=.10)
  for suffix in ['', 'Tips','Coverts']:
   a.joint(g+suffix,root);a.meta.setdefault('animation_groups',{})[g+suffix]=g
  a.between('Feet',(s*.25,-.10,-.64),(s*.31,-.28,-.91),.12,red,vertices=6,radius2=.09)
  for j in range(3): a.between('Feet',(s*.31+(j-1)*.10,-.28,-.88),(s*.31+(j-1)*.10,-.49,-.99),.068,orange,vertices=5,radius2=.04)
 a.between('Beak',(0,-.72,.83),(0,-1.08,.70),.23,'#EE961A',vertices=5,radius2=.055)
 # Swept, curled flame comb from the reference, rather than pointed crystal horns.
 comb=[(-.56,1.42),(-.68,1.80),(-.42,1.95),(-.23,2.20),(.12,2.19),(.43,2.00),(.55,1.75),(.25,1.64),(.02,1.85),(-.24,1.88),(-.33,1.64)]
 o=a.poly('Crest',comb,.42,red,bevel=.045);o.location.y=.06
 comb=[(-.52,1.46),(-.74,1.58),(-.74,1.80),(-.46,1.88),(-.34,2.15),(-.12,2.11),(-.03,1.89),(-.29,1.75),(-.31,1.54)]
 o=a.poly('Crest',comb,.27,orange,bevel=.03);o.location.y=-.17
 o=a.poly('Crest',[(-.41,1.90),(-.50,2.28),(-.29,2.27),(-.14,2.02)],.24,yellow,bevel=.025);o.location.y=-.03
 for j in range(5):
  x=(j-2)*.25
  pts=[(x*.35,.33,-.48),(x,.49,-1.03),(x*1.50,.61,-1.65+abs(j-2)*.10),(x*1.73,.52,-1.80+abs(j-2)*.12),(x*1.80,.37,-1.39+abs(j-2)*.10)]
  # Thick flame ribbon with an outward curled tip.
  side=-1 if j<2 else 1
  ribbon=[(x*.35-.10,-.48),(x*.35+.10,-.48),(x+side*.22,-1.02),
   (x*1.60+side*.24,-1.53+abs(j-2)*.10),(x*1.90+side*.20,-1.35+abs(j-2)*.08),
   (x*1.92+side*.28,-1.15+abs(j-2)*.08),(x*1.93+side*.32,-1.67+abs(j-2)*.10),
   (x*1.70,-1.93+abs(j-2)*.10),(x-side*.13,-1.60),(x-side*.18,-1.04)]
  ob=a.poly('Tail',ribbon,.22,red,bevel=.025);ob.location.y=.45+j*.04
  blade(a,'TailFlames',pts[-2],(pts[-1][0],pts[-1][1],pts[-1][2]+.29),.13,yellow,'neon',depth=.07)
  blade(a,'TailOrange',pts[1],pts[3],.13,orange,depth=.07)
 a.joint('Head',(0,-.05,.58));a.joint('Crest',(0,-.05,.58));a.meta.setdefault('animation_groups',{})['Crest']='Head'
 for g in ['Tail','TailFlames','TailOrange']:a.joint(g,(0,.32,-.48));a.meta.setdefault('animation_groups',{})[g]='Tail'
 if lv:
  a.ring('Halo',(0,.11,2.14),.44,.027,'#FFBB26','neon',axis='Z',segments=20,sides=4)
  a.joint('Halo',(0,.11,2.14))
 return finish(a,lv)

def wyrm(lv=False):
 a=pet('lodeWyrm',lv,True)
 copper='#C87721';light='#D78A28';dark='#B75B1C'
 # S-shaped floating double coil; segmented armor follows the full curve.
 pts=[(-.53,-.49,1.10),(-.20,.04,1.03),(.38,.30,.80),(.73,.39,.38),(.71,.22,-.02),(.36,-.17,-.30),(-.21,-.36,-.23),(-.64,-.18,-.02),(-.84,.23,-.18),(-.69,.56,-.56),(-.23,.64,-.88),(.36,.40,-1.03),(.67,-.03,-1.15),(.48,-.42,-1.39),(.02,-.59,-1.52),(-.43,-.48,-1.48)]
 for j,p in enumerate(pts):
  tangent=Vector(pts[min(j+1,len(pts)-1)])-Vector(pts[max(0,j-1)])
  g='Body' if j==3 else 'Segments'
  o=a.cylinder(g,p,.34 if j<12 else .28,.53,light if j%3==0 else copper,'tint' if g=='Body' else 'palette',vertices=10)
  o.rotation_euler=tangent.to_track_quat('Z','Y').to_euler()
  seam=a.cylinder('SegmentBands',p,.346 if j<12 else .291,.028,dark,vertices=10);seam.rotation_euler=o.rotation_euler
  if j<10:
   p=Vector(p);a.box('Fins',(p.x+.31,p.y,p.z+.04),(.22,.17,.10),dark,.015)
 ico(a,'Head',(-.56,-.78,1.12),(.98,1.13,.79),copper)
 a.box('Head',(-.56,-.66,1.48),(.56,.41,.11),light,.04)
 for s in (-1,1):
  x=-.56+s*.34
  a.box('EyeSocket',(x,-1.05,1.22),(.18,.08,.15),dark,.025)
  for j in range(2):orb(a,'Eyes',(x+s*.025,-1.102,1.20+j*.08),(.063,.026,.066),'#FFDB60','neon')
  a.cylinder('CheekBolt',(-.56+s*.47,-.68,1.03),.13,.08,dark,vertices=6,rot=(0,math.pi/2,0))
 # Conical drill with distinct stepped collars and a spiral ridge.
 a.between('Drill',(-.56,-1.20,1.07),(-.56,-1.96,.98),.29,copper,vertices=12,radius2=0)
 for j in range(5):
  t=j/6;r=.27*(1-t)
  a.cylinder('DrillBands',(-.56,-1.22-j*.12,1.07-j*.014),r,.045,dark,vertices=12,rot=(math.pi/2,0,0))
 helix=[]
 for j in range(48):
  t=j/47;ang=t*math.tau*4;r=.283*(1-t)+.01
  helix.append((-.56+r*math.cos(ang),-1.21-.73*t,1.07-.08*t+r*math.sin(ang)))
 a.tube('DrillRidge',helix,.018,light,'palette',sides=4)
 for j in range(2,12):
  p=Vector(pts[j]);a.box('BellyGlow',(p.x,p.y-.26,p.z-.11),(.28,.07,.20),'#FFCB44',.025,'neon')
 a.joint('Head',(-.38,-.28,1.02));a.joint('Drill',(-.56,-1.20,1.07));a.joint('DrillBands',(-.56,-1.20,1.07));a.joint('DrillRidge',(-.56,-1.20,1.07))
 for g in ['DrillBands','DrillRidge']:a.meta.setdefault('animation_groups',{})[g]='Drill'
 if lv:a.box('HeadTrim',(-.56,-.80,1.48),(.34,.16,.07),'equipment_gold',.02)
 return finish(a,lv)

BUILDERS={'solarPhoenix':phoenix,'auroraOwl':owl,'coinMagpie':magpie,'meteorDrake':drake,
 'pebblePup':pup,'cargoMole':mole,'crystalStag':stag,'lodeWyrm':wyrm,'sparkHare':hare}

def normalize_finish():
 old_setup=Asset.setup_preview
 def setup(a,lo,hi):
  old_setup(a,lo,hi)
  size=max(hi-lo); center=(lo+hi)/2; camera=a.scene.camera
  camera.location=center+Vector((-.95,-1.8,.75))*size
  if a.meta.get('Reference')==REFS['lodeWyrm']:camera.location=center+Vector((1.7,-1.6,.75))*size
  camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
  camera.data.ortho_scale=size*1.20
  # Pure colored emission avoids whitening the vivid neon reference accents.
  for obj in a.scene.objects:
   if obj.type!='MESH':continue
   for m in obj.data.materials:
    principled=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
    if principled:
     principled.inputs['Roughness'].default_value=.58
     principled.inputs['Specular IOR Level'].default_value=.28
    if m.get('Mode')!='neon':continue
    nodes=m.node_tree.nodes
    emission=next((n for n in nodes if n.type=='EMISSION'),None)
    if emission is None:emission=nodes.new('ShaderNodeEmission')
    emission.inputs['Color'].default_value=lib.rgba(m['Ramp'][1])
    emission.inputs['Strength'].default_value=1
    output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
    m.node_tree.links.new(emission.outputs[0],output.inputs['Surface'])
 Asset.setup_preview=setup
 original=Asset.finish
 def wrapped(a):
  # Uniform scale preserves image proportions, including the stag's giant antlers.
  bpy.context.view_layer.update()
  objects=[o for group in a.groups.values() for o in group]
  pts=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
  low=min(p.z for p in pts);high=max(p.z for p in pts)
  target=3.9 if a.meta.get('Reference')==REFS['solarPhoenix'] else 3.5 if a.meta.get('Reference') in (REFS['meteorDrake'],REFS['crystalStag'],REFS['sparkHare']) else 3.0
  factor=target/(high-low)
  delta=Vector((0,0,0 if a.meta.get('Flying') else -low*factor))
  for o in objects:o.location=o.location*factor+delta;o.scale*=factor
  a.joints={g:p*factor+delta for g,p in a.joints.items()}
  a.meta['TargetHeight']=target
  root=a.empty(a.id.split('/')[-1],(0,0,0))
  root['PetColor']=a.meta['PetColor']
  root['PrimaryPart']='Body'
  for o in objects:o.parent=root
  return original(a)
 Asset.finish=wrapped

def validate(reports):
 checked=[];original_scene=bpy.context.window.scene
 for r in reports:
  path=OUT/r['id'];s=bpy.data.scenes.new('ReferenceExportValidation');bpy.context.window.scene=s
  try:
   bpy.ops.import_scene.fbx(filepath=str(path.with_suffix('.fbx')),use_custom_props=True)
   meshes=[o for o in s.objects if o.type=='MESH']
   tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
   assert tris==r['triangles'] and tris<=7000,(r['id'],tris)
   assert len(meshes)==len(r['objects'])
   assert any(o.get('RobloxName')=='Body' for o in meshes)
   bpy.context.view_layer.update()
   pts=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
   dimensions=[max(p[i] for p in pts)-min(p[i] for p in pts) for i in range(3)]
   assert max(abs(dimensions[i]-r['dimensions_blender'][i]) for i in range(3))<.015
   for o in meshes:
    assert max(abs(v-1) for v in o.scale)<.001
    if o.get('AnimationGroup'):
     assert o.get('AnimationPivot') is not None
    textured=any(n.type=='TEX_IMAGE' for m in o.data.materials for n in m.node_tree.nodes)
    if o.get('RuntimeTint') or o.get('RobloxMaterial')=='Neon':assert not textured
    if textured:
     assert len(o.data.uv_layers)==1
     for polygon in o.data.polygons:
      uv=[o.data.uv_layers[0].data[i].uv for i in polygon.loop_indices]
      assert all((p-uv[0]).length<.000001 for p in uv)
    if o.get('RuntimeTint'):
     for m in o.data.materials:
      node=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
      assert min(node.inputs['Base Color'].default_value[:3])>.9
   png=path.with_suffix('.png').read_bytes();w,h,depth,ctype=struct.unpack('>IIBB',png[16:26]);assert (w,h,ctype)==(512,512,6)
   checked.append({'id':r['id'],'triangles':tris,'mesh_count':len(meshes),'dimensions':dimensions,'passed':True})
  finally:
   for o in list(s.objects):bpy.data.objects.remove(o,do_unlink=True)
   bpy.context.window.scene=original_scene;bpy.data.scenes.remove(s)
 (OUT/'validation.json').write_text(json.dumps(checked,indent=2))
 print('VALIDATION_PASSED',len(checked))

def main():
 normalize_finish();reports=[]
 for name,fn in BUILDERS.items():
  for lv in (False,True):
   reports.append(fn(lv))
 (OUT/'manifest.json').write_text(json.dumps(reports,indent=2))
 # Also deliver the requested previews/ directory without duplicating mesh exports.
 (OUT/'previews').mkdir(exist_ok=True)
 for r in reports:shutil.copy2((OUT/r['id']).with_suffix('.png'),OUT/'previews'/((OUT/r['id']).name+'.png'))
 validate(reports)
 print('REFERENCE_SET_COMPLETE',len(reports))

if __name__=='__main__':main()


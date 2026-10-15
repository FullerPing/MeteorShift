"""Fourteen individually sculpted pet designs, each with a complete ascended look.

Run through the shared Blender asset runner; importing never touches the scene.
"""
from assetlib import *
from math import pi, sin, cos
from functools import partial


COLORS = {
    'pebblePup': '#969696', 'scrapSparrow': '#BEA06E',
    'packMule': '#BEA078', 'sparkHare': '#FFDC5A', 'jetWisp': '#6EDCFF',
    'coinMagpie': '#FFDC64', 'cargoMole': '#967860', 'graniteGolem': '#78828C',
    'crystalStag': '#BE82FF', 'lodeWyrm': '#FFAA46', 'auroraOwl': '#78FFD2',
    'meteorDrake': '#FF8232', 'drillbot': '#FFB030', 'solarPhoenix': '#FF783C',
}


def new(pet, level10, flying=False):
    a = Asset('pets/' + pet + ('_lv10' if level10 else ''), budget=5000)
    a.meta.update(PetColor=COLORS[pet], Level10=level10,
                  PivotType='BodyCenter' if flying else 'BottomCenter',
                  PrimaryPart='Body', FrontAxis='-Y')
    return a


def orb(a, group, pos, size, color, mode='palette'):
    return a.ellipsoid(group, pos, size, color, mode, segments=10, rings=6)


def eye(a, group, x, y, z, size=.16, glow=False, color='ink'):
    orb(a, group, (x, y, z), (size, .10, size * 1.15), color,
        'neon' if glow else 'palette')
    if not glow:
        orb(a, group, (x-.025, y-.056, z+.035), (.038,.024,.045), 'white')


def eyes(a, group, x, y, z, size=.16, glow=False, color='ink'):
    for side in (-1, 1):
        eye(a, group, x*side, y, z, size, glow, color)


def joint(a, group, p, follows=None):
    a.joint(group, p)
    if follows:
        a.meta.setdefault('animation_groups', {})[group] = follows


def feet(a, front_y, back_y, x, height, color, wide=.43):
    for side in (-1, 1):
        for group, y in [('FrontLeg', front_y), ('BackLeg', back_y)]:
            name = group if side == -1 else group+'.001'
            orb(a, name, (side*x,y,height/2), (wide,wide*1.2,height),color)
            joint(a,name,(side*x,y,height*.83),group)


def shard(a, group, pos, length, color='cyan', radius=.13, mode='neon'):
    return a.cylinder(group,pos,radius,length,color,mode,vertices=5,radius2=0)


def feather(a, group, root, tip, width, color, mode='palette'):
    """A tapered, softly faceted feather, not a rectangular wing slab."""
    x,y,z=root; tx,ty,tz=tip
    dx,dz=tx-x,tz-z
    mag=(dx*dx+dz*dz)**.5 or 1
    px,pz=-dz/mag*width,dx/mag*width
    mid=(x+dx*.53,y+(ty-y)*.53,z+dz*.53)
    verts=[(x,y-.05,z),(x,y+.05,z),
           (mid[0]+px,mid[1],mid[2]+pz),(tx,ty,tz),
           (mid[0]-px,mid[1],mid[2]-pz),
           (mid[0],mid[1]-.10,mid[2]),(mid[0],mid[1]+.10,mid[2])]
    faces=[(0,2,5),(2,3,5),(3,4,5),(4,0,5),
           (1,6,2),(2,6,3),(3,6,4),(4,6,1),(0,1,2),(0,4,1)]
    # Closed, tapered organic surface: its thin natural edge needs no box bevel.
    return a.mesh(group,verts,faces,color,mode)


def pebble_pup(level10=False):
    a=new('pebblePup',level10)
    a.ico('Body',(0,.13,1.12),(1.53,2.05,1.57),COLORS['pebblePup'],'tint',subdivisions=2)
    a.ico('Head',(0,-.86,1.88),(1.39,1.27,1.32),'stone',subdivisions=2)
    orb(a,'Head',(0,-1.47,1.67),(.80,.40,.48),'#C8CEDC')
    orb(a,'Head',(0,-1.70,1.77),(.23,.15,.19),'ink')
    eyes(a,'Head',.34,-1.41,2.06,.19)
    for s in (-1,1):
        orb(a,'Head',(s*.65,-.87,2.05),(.39,.62,.74),'#626C84')
    feet(a,-.56,.75,.57,.69,'stone',.45)
    # Overlapping upper pebbles keep the legs connected to the curved boulder.
    for s in (-1,1):
        for base,y in [('FrontLeg',-.56),('BackLeg',.75)]:
            g=base if s<0 else base+'.001'
            orb(a,g,(s*.52,y,.69),(.39,.43,.57),'stone')
    for i in range(3):
        a.ico('Tail',(0,1.13+i*.23,1.22+i*.23),(.47-i*.08,.48-i*.07,.47-i*.07),'stone',seed=i)
    for i in range(3):
        a.ico('GreyChip',((i-1)*.25,-1.23,.19+i*.06),(.19,.23,.18),'stone',seed=i)
    a.hidden('GreyChip')
    joint(a,'GreyChip',(0,-1.23,.19))
    joint(a,'Head',(0,-.56,1.60)); joint(a,'Tail',(0,.98,1.20))
    if level10:
        a.ring('AccentTrim',(0,-.49,1.39),.63,.065,'#626C84',axis='Y',segments=16,sides=4)
        a.ico('Head',(0,-1.50,2.42),(.36,.14,.23),'#C8CEDC')
        for s in (-1,1):
            orb(a,'FrontLeg' if s==-1 else 'FrontLeg.001',(s*.58,-.72,.24),(.54,.46,.29),'#C8CEDC')
    return a.finish()


def scrap_sparrow(level10=False):
    a=new('scrapSparrow',level10,True)
    orb(a,'Body',(0,0,0),(1.27,1.50,1.44),COLORS['scrapSparrow'],'tint')
    orb(a,'Head',(0,-.56,.55),(1.13,1.02,1.03),'#BEA06E')
    # An asymmetric bolt eye and dark glass eye distinguish the scrap bird.
    a.cylinder('Head',(-.28,-1.065,.66),.15,.065,'steel',vertices=6,rot=(pi/2,0,0))
    a.box('Head',(-.28,-1.107,.66),(.17,.03,.033),'ink',bevel=.008,rot=(0,.3,0))
    eye(a,'Head',.28,-1.06,.66,.19)
    a.between('Head',(0,-1.0,.42),(0,-1.56,.35),.20,'rust',vertices=4,radius2=0)
    for side in (-1,1):
        group='WingsLeft' if side<0 else 'WingsRight'
        for i in range(3):
            feather(a,group,(side*.48,.0,.24),(side*(1.09+i*.14),.45-i*.16,-.47+i*.17),.20,
                    ['#D6985C','#BEA06E','#A86C3E'][i])
            orb(a,group,(side*(.62+i*.11),-.10,.05+i*.06),(.07,.07,.07),'steel')
        joint(a,group,(side*.49,0,.23))
        a.between('Feet',(side*.25,-.03,-.59),(side*.25,-.16,-.88),.055,'rust',vertices=6)
        a.between('Feet',(side*.25,-.16,-.88),(side*.25,-.47,-.89),.055,'rust',vertices=6)
    for i in range(3):
        x=(i-1)*.25
        a.tube('Tail',[(x,.53,-.17),(x,.70,-.09),(x,.80,-.23),(x,.90,-.15)],.045,'steel','palette',sides=4)
        feather(a,'Tail',(x,.81,-.15),(x*1.6,1.53,-.06),.16,'wood')
    joint(a,'Head',(0,-.34,.32)); joint(a,'Tail',(0,.56,-.17))
    if level10:
        for s in (-1,1):
            a.between('AccentTrim',(s*.47,-.36,.13),(s*.63,.39,-.17),.045,'equipment_gold',vertices=6)
        feather(a,'Head',(0,-.28,.88),(.1,-.1,1.25),.18,'rust')
    return a.finish()


def pack_mule(level10=False):
    a=new('packMule',level10)
    a.box('Body',(0,.12,1.32),(1.20,1.92,1.34),COLORS['packMule'],bevel=.26,mode='tint')
    a.box('Head',(0,-.99,1.96),(.99,.90,1.08),'stone',bevel=.24)
    orb(a,'Head',(0,-1.48,1.62),(.90,.75,.54),'#626C84')
    eyes(a,'Head',.28,-1.43,2.12,.16)
    for s in (-1,1):
        orb(a,'Head',(s*.20,-1.83,1.67),(.09,.05,.08),'ink')
    a.box('Ears',(-.31,-.86,2.74),(.25,.32,.90),'stone',bevel=.10,rot=(0,-.15,0))
    a.box('Ears',(.34,-.82,2.68),(.25,.33,.65),'stone',bevel=.10,rot=(0,.30,0))
    a.box('Ears',(.51,-.88,2.81),(.43,.30,.23),'#626C84',bevel=.09,rot=(0,.3,0))
    for i in range(4):
        a.box('Mane',(0,-.45+i*.24,2.05),(.30,.18,.32-i*.035),'ink',bevel=.045)
    feet(a,-.56,.74,.44,.77,'stone',.36)
    for s in (-1,1):
        g='Pannier' if s<0 else 'Pannier.001'; scale=1.15 if level10 else 1
        a.box(g,(s*.93,.21,1.36),(.70*scale,1.25*scale,1.02*scale),'wood',bevel=.17)
        a.box(g,(s*.96,-.44,1.54),(.64*scale,.12,.33),'#D6985C',bevel=.045)
        a.box(g,(s*.96,-.51,1.38),(.16,.07,.57),'#70462A',bevel=.018)
        a.box(g,(s*.96,-.56,1.47),(.28,.07,.22),'gold',bevel=.035)
        a.box(g,(s*.96,-.61,1.47),(.13,.03,.10),'wood',bevel=.012)
    a.tube('Tail',[(0,1.04,1.61),(0,1.39,1.38),(0,1.47,1.05)],.10,'stone','palette')
    orb(a,'Tail',(0,1.48,1.04),(.33,.25,.43),'ink')
    joint(a,'Head',(0,-.73,1.78));joint(a,'Ears',(0,-.85,2.35));joint(a,'Tail',(0,1.02,1.62))
    if level10:
        a.box('AccentTrim',(0,-.74,1.06),(1.06,.12,.13),'equipment_gold',bevel=.03)
        a.box('Head',(0,-1.46,2.42),(.29,.08,.19),'equipment_gold',bevel=.045)
    return a.finish()


def spark_hare(level10=False):
    a=new('sparkHare',level10)
    orb(a,'Body',(0,.19,1.06),(1.22,1.43,1.51),COLORS['sparkHare'],'tint')
    orb(a,'Head',(0,-.45,1.76),(1.17,1.03,1.04),'#FFDC5A')
    orb(a,'Belly',(0,-.53,1.05),(.77,.21,.83),'cream')
    eyes(a,'Head',.30,-.96,1.89,.24)
    orb(a,'Head',(0,-1.025,1.60),(.18,.10,.13),'pink')
    for s in (-1,1):
        g='FrontLeg' if s<0 else 'FrontLeg.001'
        orb(a,g,(s*.42,-.51,.44),(.30,.47,.75),'#FFDC5A')
        joint(a,g,(s*.43,-.37,.82),'FrontLeg')
        bg='BackLeg' if s<0 else 'BackLeg.001'
        orb(a,bg,(s*.55,.40,.54),(.59,.71,.94),'#FFDC5A')
        orb(a,bg,(s*.55,-.01,.16),(.52,.88,.31),'cream')
        joint(a,bg,(s*.48,.39,.84),'BackLeg')
        tipz=3.1+(.16 if level10 else 0)
        a.between('Ears',(s*.30,-.29,2.10),(s*.46,-.23,tipz),.17,'#FFDC5A',vertices=8,radius2=.12)
        a.between('Ears',(s*.30,-.44,2.18),(s*.43,-.37,tipz-.12),.082,'cream',vertices=6,radius2=.055)
        shard(a,'EarsGlow',(s*.46,-.23,tipz),.36,'cyan',.16)
        pg='PawGlowLeft' if s<0 else 'PawGlowRight'
        shard(a,pg,(s*.44,-.70,.27),.20,'frost',.095)
        joint(a,pg,(s*.43,-.37,.82),'FrontLeg')
    orb(a,'Tail',(0,.93,1.02),(.49,.47,.46),'cream')
    joint(a,'Ears',(0,-.27,2.07));joint(a,'EarsGlow',(0,-.27,2.07),'Ears')
    joint(a,'Head',(0,-.3,1.52));joint(a,'Tail',(0,.79,1.04))
    a.tube('SparkLink',[(-.27,-1.1,.54),(.07,-1.4,.79),(-.06,-1.53,.93),(.30,-1.88,1.20)],.055,'cyan')
    a.hidden('SparkLink')
    joint(a,'SparkLink',(0,-1.1,.54))
    if level10:
        a.tube('AccentGlow',[(-.31,-.66,1.31),(0,-.70,1.45),(.31,-.66,1.31)],.035,'cyan')
        for s in (-1,1):
            a.between('EarsGlow',(s*.46,-.23,3.14),(s*.76,-.25,3.43),.105,'frost','neon',vertices=5,radius2=0)
            a.between('EarsGlow',(s*.46,-.23,3.24),(s*.26,-.25,3.61),.075,'cyan','neon',vertices=5,radius2=0)
    return a.finish()


def jet_wisp(level10=False):
    a=new('jetWisp',level10,True)
    orb(a,'Body',(0,0,0),(1.43,1.21,1.53),COLORS['jetWisp'],'tint')
    a.between('Head',(0,0,.44),(.22,.12,1.11),.40,'cyan',vertices=10,radius2=0)
    orb(a,'Core',(0,-.51,-.09),(.89,.19,1.07),'white','neon')
    eyes(a,'Head',.27,-.666,.17,.14)
    for s in (-1,1):
        feather(a,'Tail',(s*.35,.13,-.34),(s*.49,.73,-1.11),.30,'cyan','neon')
        feather(a,'Tail',(s*.39,.36,-.50),(s*.64,1.02,-.91),.15,'white','neon')
    joint(a,'Tail',(0,.09,-.39));joint(a,'Head',(0,0,.32))
    if level10:
        for s in (-1,1):
            feather(a,'AscendedFlames',(s*.57,0,.1),(s*.92,.36,.7),.17,'white','neon')
        a.tube('AccentGlow',[(-.49,-.54,-.04),(0,-.64,-.49),(.49,-.54,-.04)],.04,'cyan')
    return a.finish()


def coin_magpie(level10=False):
    a=new('coinMagpie',level10,True)
    orb(a,'Plumage',(0,.12,0),(1.12,1.37,1.35),'ink')
    orb(a,'Body',(0,-.42,-.05),(.81,.53,1.02),COLORS['coinMagpie'],'tint')
    orb(a,'Head',(0,-.48,.61),(.99,.98,.91),'ink')
    for s in (-1,1):
        orb(a,'Head',(s*.27,-.936,.74),(.245,.075,.26),'white')
    eyes(a,'Head',.27,-.989,.74,.135)
    a.between('Head',(0,-.89,.48),(0,-1.41,.43),.16,'equipment_dark',vertices=5,radius2=.02)
    a.cylinder('Head',(0,-1.43,.25),.26,.08,'gold',vertices=16,rot=(pi/2,0,0))
    a.ring('Head',(0,-1.479,.25),.20,.025,'#FFE66E',segments=16,sides=4)
    a.box('Head',(0,-1.50,.25),(.04,.025,.23),'#CE8C14',bevel=.01)
    for s in (-1,1):
        group='WingsLeft' if s<0 else 'WingsRight'
        for i in range(4):
            feather(a,group,(s*.43,.12,.28),(s*(.89+i*.09),.56,-.30-i*.15),.18,
                    ['#148A8C','#308C34','#CE8C14','white'][i])
        joint(a,group,(s*.45,.10,.29))
        a.between('Feet',(s*.25,-.06,-.58),(s*.25,-.30,-.86),.045,'ink',vertices=6)
    for i in range(3):
        feather(a,'Tail',((i-1)*.20,.56,-.17),((i-1)*.32,1.87,-.55),.16,
                '#148A8C' if i==1 else 'ink')
    joint(a,'Head',(0,-.33,.30));joint(a,'Tail',(0,.52,-.17))
    a.between('CoinGlint',(-.35,-1.5,.25),(.35,-1.5,.25),.025,'gold','neon',vertices=4)
    a.between('CoinGlint',(0,-1.5,-.10),(0,-1.5,.60),.025,'white','neon',vertices=4)
    a.hidden('CoinGlint')
    joint(a,'CoinGlint',(0,-1.5,.25))
    if level10:
        for s in (-1,1):
            feather(a,'WingsLeft' if s<0 else 'WingsRight',(s*.45,-.06,.34),(s*1.28,.38,-.38),.07,'equipment_gold')
        shard(a,'CoinGlow',(0,-1.52,.57),.15,'gold',.08)
        joint(a,'CoinGlow',(0,-.33,.30),'Head')
    return a.finish()


def cargo_mole(level10=False):
    a=new('cargoMole',level10)
    orb(a,'Body',(0,.16,1.02),(1.78,1.74,1.83),COLORS['cargoMole'],'tint')
    orb(a,'Head',(0,-.55,1.62),(1.31,1.05,1.11),'#70462A')
    orb(a,'Head',(0,-1.13,1.50),(.35,.37,.28),'pink')
    for s in (-1,1):
        a.tube('Head',[(s*.42,-1.005,1.81),(s*.29,-1.06,1.77),(s*.18,-1.02,1.81)],.039,'ink','palette')
        g='FrontLeg' if s<0 else 'FrontLeg.001'
        orb(a,g,(s*.78,-.44,.71),(.55,.56,.69),'#70462A')
        for i in range(3):
            a.between(g,(s*(.62+i*.13),-.63,.54),(s*(.65+i*.14),-.87,.40),.055,'pink',vertices=5,radius2=.018)
        joint(a,g,(s*.65,-.25,.91),'FrontLeg')
    for s in (-1,1):
        bg='BackLeg' if s<0 else 'BackLeg.001'
        orb(a,bg,(s*.54,.58,.19),(.48,.66,.37),'#70462A')
        joint(a,bg,(s*.54,.58,.34),'BackLeg')
    orb(a,'Head',(0,-.45,2.14),(1.34,1.12,.61),'gold')
    orb(a,'Head',(0,-.54,1.99),(1.53,1.38,.13),'gold')
    a.cylinder('Head',(0,-1.08,2.17),.19,.14,'equipment_dark',vertices=12,rot=(pi/2,0,0))
    orb(a,'HeadGlow',(0,-1.165,2.17),(.25,.07,.25),'warm_glow','neon')
    a.box('Satchel',(0,.94,1.16),(1.16,.60,1.05),'wood',bevel=.16)
    a.box('Satchel',(0,1.26,1.38),(.97,.10,.37),'cream',bevel=.08)
    for s in (-1,1):
        a.tube('Satchel',[(s*.46,.84,1.57),(s*.73,.17,1.72),(s*.60,-.40,1.12)],.072,'#70462A','palette')
    a.ico('OreChunk',(0,.99,1.89),(.43,.42,.47),'orange',seed=5)
    a.hidden('OreChunk');joint(a,'OreChunk',(0,.99,1.89))
    joint(a,'Head',(0,-.40,1.45));joint(a,'HeadGlow',(0,-.40,1.45),'Head')
    if level10:
        a.box('AccentTrim',(0,1.33,1.40),(.24,.08,.25),'equipment_gold',bevel=.035)
        a.tube('HeadTrim',[(-.56,-.54,2.29),(0,-.49,2.46),(.56,-.54,2.29)],.045,'equipment_gold','palette')
        a.ring('HeadTrim',(0,-1.18,2.17),.18,.038,'equipment_gold',segments=16,sides=4)
        for y,z in [(-.85,2.31),(-.57,2.45),(-.29,2.45)]:
            a.box('HeadTrim',(0,y,z),(.15,.25,.075),'navy',bevel=.025)
        joint(a,'HeadTrim',(0,-.40,1.45),'Head')
    return a.finish()


def granite_golem(level10=False):
    a=new('graniteGolem',level10)
    a.box('Body',(0,.08,1.61),(1.56,1.06,1.48),COLORS['graniteGolem'],bevel=.23,mode='tint')
    a.box('Head',(0,-.04,2.54),(1.05,.92,.84),'#626C84',bevel=.20)
    for s in (-1,1):
        a.box('HeadGlow',(s*.26,-.518,2.59),(.31,.045,.105),'warm_glow',bevel=.025,mode='neon')
        g='FrontLeg' if s<0 else 'FrontLeg.001'
        a.box(g,(s*1.01,.03,1.73),(.52,.68,.76),'#626C84',bevel=.15)
        a.box(g,(s*1.20,-.19,1.06),(.77,.87,.77),'#626C84',bevel=.19)
        for i in range(3):
            a.box(g,(s*(.97+i*.20),-.65,1.14),(.15,.13,.25),'stone',bevel=.04)
        joint(a,g,(s*.78,.04,2.02),'FrontLeg')
        bg='BackLeg' if s<0 else 'BackLeg.001'
        a.box(bg,(s*.45,.04,.47),(.61,.73,.94),'#626C84',bevel=.14)
        a.box(bg,(s*.45,-.17,.17),(.71,.94,.32),'stone',bevel=.08)
        joint(a,bg,(s*.45,.04,.83),'BackLeg')
    a.box('ChestHatch',(0,-.51,1.60),(.88,.13,.80),'ink',bevel=.09)
    a.box('ChestGlow',(0,-.585,1.60),(.64,.035,.54),'warm_glow',bevel=.07,mode='neon')
    a.box('ChestHatch',(0,-.62,1.60),(.11,.065,.61),'#626C84',bevel=.02)
    for i in range(3):
        a.ico('Moss',(-.54+i*.20,.02,2.39),(.36,.49,.21),'green',seed=i)
    joint(a,'Head',(0,.01,2.21));joint(a,'HeadGlow',(0,.01,2.21),'Head')
    if level10:
        for s in (-1,1):
            a.box('AccentTrim',(s*.60,-.51,1.72),(.12,.10,1.05),'equipment_gold',bevel=.02)
            a.tube('CrackGlow',[(s*.32,-.502,2.85),(s*.10,-.52,2.75),(s*.14,-.54,2.63)],.025,'gold')
        joint(a,'CrackGlow',(0,.01,2.21),'Head')
    return a.finish()


def crystal_stag(level10=False):
    a=new('crystalStag',level10)
    a.ico('Body',(0,.19,1.46),(.96,1.56,.99),COLORS['crystalStag'],'tint',subdivisions=2)
    a.between('Head',(0,-.43,1.62),(0,-.78,2.36),.29,'violet',vertices=7,radius2=.24)
    a.ico('Head',(0,-.89,2.47),(.63,.80,.67),'violet',subdivisions=1)
    a.ico('Head',(0,-1.26,2.30),(.47,.53,.35),'#CE9CFF')
    eyes(a,'Head',.20,-1.24,2.53,.105)
    a.ico('Underbelly',(0,-.18,1.19),(.71,1.20,.35),'cream')
    for s in (-1,1):
        feather(a,'Head',(s*.22,-.73,2.62),(s*.66,-.64,2.83),.15,'violet')
        for g,y in [('FrontLeg',-.43),('BackLeg',.71)]:
            name=g if s<0 else g+'.001'
            a.between(name,(s*.33,y,1.25),(s*.39,y-.08,.14),.105,'#CE9CFF',vertices=6,radius2=.075)
            a.box(name,(s*.39,y-.15,.11),(.22,.33,.20),'#6C38BA',bevel=.045)
            joint(a,name,(s*.33,y,1.24),g)
        end=3.45 if level10 else 3.23
        a.tube('AntlersGlow',[(s*.20,-.76,2.73),(s*.34,-.65,2.98),(s*.50,-.59,end)],.065,'violet')
        a.tube('AntlersGlow',[(s*.35,-.65,3.0),(s*.68,-.69,3.12),(s*.78,-.62,3.29)],.048,'violet')
        a.between('AntlersGlow',(s*.45,-.62,3.14),(s*.25,-.60,3.35),.043,'#CE9CFF','neon',vertices=5,radius2=0)
    feather(a,'Tail',(0,.91,1.52),(0,1.35,1.75),.16,'violet')
    for i in range(3):
        shard(a,'TargetShard',((i-1)*.23,-1.52,.27+i*.08),.43,'violet',.11)
    a.hidden('TargetShard')
    joint(a,'TargetShard',(0,-1.52,.27))
    joint(a,'Head',(0,-.45,1.70));joint(a,'AntlersGlow',(0,-.45,1.70),'Head');joint(a,'Tail',(0,.89,1.53))
    if level10:
        a.tube('AccentTrim',[(-.38,-.51,1.76),(0,-.57,1.58),(.38,-.51,1.76)],.04,'equipment_gold','palette')
        for s in (-1,1):
            shard(a,'ShoulderGlow',(s*.47,-.19,1.84),.31,'violet',.09)
    return a.finish()


def lode_wyrm(level10=False):
    a=new('lodeWyrm',level10)
    orb(a,'Body',(0,-.48,1.15),(1.18,1.11,1.21),COLORS['lodeWyrm'],'tint')
    # Seven separate coiled copper segments, each with an independent joint.
    for i in range(7):
        theta=-pi/2+i*.50; r=.94; x=cos(theta)*r; y=.41+sin(theta)*r
        z=.55+.09*sin(theta); size=.91-i*.065; group='Tail' if i==0 else 'Tail.%03d'%i
        orb(a,group,(x,y,z),(size,size*.89,size),'rust')
        a.ring(group+'Glow',(x,y-.12,z),size*.43,.028,'warm_glow',mode='neon',segments=12,sides=4)
        joint(a,group,(x,y-.25,z),'Tail');joint(a,group+'Glow',(x,y-.25,z),'Tail')
        if level10:
            a.ico(group,(x,y,z+size*.48),(.20,.28,.17),'equipment_gold')
    orb(a,'Head',(0,-1.04,1.55),(1.27,1.00,1.18),'rust')
    a.ring('Head',(0,-1.50,1.35),.39,.10,'steel',segments=16,sides=5)
    for i in range(8):
        theta=2*pi*i/8
        a.between('Head',(.38*cos(theta),-1.53,1.35+.38*sin(theta)),
                  (.31*cos(theta),-1.80,1.35+.31*sin(theta)),.065,'light_steel',vertices=5,radius2=0)
    for s in (-1,1):
        orb(a,'Head',(s*.29,-1.44,1.92),(.32,.28,.34),'#703626')
    eyes(a,'HeadGlow',.29,-1.602,1.94,.205,True,'warm_glow')
    a.ring('TunnelLight',(0,-1.96,.52),.53,.07,'gold',mode='neon',axis='Y',segments=16,sides=4)
    for i in range(3):
        a.ico('TunnelOre',((i-1)*.32,-2.02,.32+i*.07),(.23,.32,.25),'orange','neon',seed=i)
    a.hidden('TunnelLight');a.hidden('TunnelOre')
    joint(a,'TunnelLight',(0,-1.96,.52));joint(a,'TunnelOre',(0,-2.02,.40))
    joint(a,'Head',(0,-.67,1.32));joint(a,'HeadGlow',(0,-.67,1.32),'Head')
    if level10:
        a.ring('HeadTrim',(0,-1.44,1.35),.49,.044,'equipment_gold',segments=16,sides=4)
        joint(a,'HeadTrim',(0,-.67,1.32),'Head')
    return a.finish()


def aurora_owl(level10=False):
    a=new('auroraOwl',level10,True)
    orb(a,'Body',(0,0,-.10),(1.50,1.10,1.59),COLORS['auroraOwl'],'tint')
    orb(a,'Head',(0,-.10,.65),(1.67,1.00,1.19),'teal')
    for s in (-1,1):
        orb(a,'Head',(s*.40,-.55,.70),(.72,.17,.78),'#DCF8FF')
        orb(a,'Head',(s*.40,-.66,.73),(.43,.09,.47),'gold')
        orb(a,'Head',(s*.40,-.719,.73),(.21,.05,.30),'ink')
        eye(a,'EyeGlow',s*.36,-.75,.81,.07,True,'warm_glow')
        feather(a,'Head',(s*.47,0,1.03),(s*.77,.05,1.53),.19,'teal')
        group='WingsLeft' if s<0 else 'WingsRight'
        for i in range(5):
            feather(a,group,(s*.56,.04,.30-i*.05),(s*((1.75 if level10 else 1.54)-i*.12),.18,-.12-i*.20),.20,
                    ['teal','#78ECDE','#8CE262','#96DEFF','#A462F6'][i])
        trail=[(s*1.53,.18,-.12),(s*1.73,.45,-.49),(s*1.69,.76,-.89),(s*1.96,1.11,-1.06)]
        a.tube(group+'Glow',trail,.045 if not level10 else .065,'teal')
        joint(a,group,(s*.59,.03,.31));joint(a,group+'Glow',(s*.59,.03,.31),group)
    a.between('Head',(0,-.65,.47),(0,-.89,.21),.11,'gold',vertices=5,radius2=0)
    for row in range(3):
        for x in (-.33,0,.33):
            feather(a,'ChestFeathers',(x,-.51,.10-row*.23),(x,-.57,-.18-row*.23),.14,
                    '#78ECDE' if row%2 else '#DCF8FF')
    joint(a,'Head',(0,-.02,.27));joint(a,'EyeGlow',(0,-.02,.27),'Head')
    if level10:
        a.tube('HeadTrim',[(-.69,-.56,1.03),(0,-.64,1.16),(.69,-.56,1.03)],.04,'equipment_gold','palette')
        joint(a,'HeadTrim',(0,-.02,.27),'Head')
        shard(a,'CrownGlow',(0,-.13,1.39),.33,'teal',.13)
        joint(a,'CrownGlow',(0,-.02,.27),'Head')
    return a.finish()


def meteor_drake(level10=False):
    a=new('meteorDrake',level10)
    # Tintable lava belly under independent charcoal armour plates.
    orb(a,'Body',(0,.16,1.39),(1.65,2.04,1.58),COLORS['meteorDrake'],'tint')
    for s in (-1,1):
        for j in range(3):
            a.ico('Scales',(s*.61,-.50+j*.56,1.68),(.71,.72,.95),'equipment_dark',seed=j)
    orb(a,'Head',(0,-1.05,2.17),(1.44,1.35,1.24),'equipment_dark')
    orb(a,'Head',(0,-1.63,1.96),(1.01,.97,.62),'#283456')
    eyes(a,'HeadGlow',.40,-1.63,2.44,.19,True,'white')
    for s in (-1,1):
        a.between('Head',(s*.48,-.78,2.61),(s*.66,-.56,3.24),.16,'#626C84',vertices=6,radius2=.05)
        a.between('HeadGlow',(s*.66,-.56,3.14),(s*.70,-.53,3.43),.076,'orange','neon',vertices=6,radius2=0)
        orb(a,'Head',(s*.29,-2.09,2.05),(.12,.06,.10),'ink')
        a.between('Head',(s*.37,-1.88,1.87),(s*.34,-1.89,1.68),.075,'cream',vertices=5,radius2=0)
        wing='WingsLeft' if s<0 else 'WingsRight'
        verts=[(s*.65,.27,1.93),(s*1.34,.50,2.72),(s*1.80,.86,2.36),
               (s*1.47,.68,1.82),(s*1.14,.55,1.96),(s*.92,.40,1.65)]
        shell=verts+[(x,y+.055,z) for x,y,z in verts]
        faces=[(5,4,3,2,1,0),(6,7,8,9,10,11)]
        faces += [(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
        a.mesh(wing,shell,faces,'#A02228',bevel=.015)
        for tip in (verts[1],verts[2],verts[4]):
            a.between(wing,verts[0],tip,.055,'equipment_dark',vertices=6)
        a.tube(wing+'Glow',[verts[1],verts[2],verts[3]],.029,'orange')
        joint(a,wing,verts[0]);joint(a,wing+'Glow',verts[0],wing)
    feet(a,-.61,.86,.66,.70,'equipment_dark',.53)
    # The belly curves upward at the sides: bridge each ankle to its actual hip.
    for s in (-1,1):
        for base,y in [('FrontLeg',-.61),('BackLeg',.86)]:
            g=base if s<0 else base+'.001'
            a.between(g,(s*.56,y,1.38),(s*.66,y,.42),.23,'equipment_dark',vertices=8,radius2=.18)
            joint(a,g,(s*.56,y,1.34),base)
    tail=[(0,1.0,1.47),(0,1.63,1.05),(.41,2.16,.58),(.87,2.30,.31)]
    for i in range(3):
        a.between('Tail',tail[i],tail[i+1],.35-i*.09,'equipment_dark',vertices=8,radius2=.26-i*.09)
    for i,p in enumerate(tail[1:]):
        shard(a,'TailGlow',(p[0],p[1],p[2]+.27),.39-i*.05,'orange',.13)
    for x in (-.46,.46):
        a.tube('Cracks',[(x,-.92,1.55),(x*.5,-.99,1.32),(x*.85,-.90,1.02)],.036,'orange')
    a.between('FlameBreath',(0,-2.00,1.96),(0,-3.15,1.98),.12,'orange','neon',vertices=8,radius2=.47)
    a.between('ArrivalStreak',(0,.15,.74),(.45,2.34,3.82),.36,'orange','neon',vertices=8,radius2=0)
    a.hidden('FlameBreath');a.hidden('ArrivalStreak')
    joint(a,'FlameBreath',(0,-2.00,1.96));joint(a,'ArrivalStreak',(0,.15,.74))
    joint(a,'Head',(0,-.66,1.97));joint(a,'HeadGlow',(0,-.66,1.97),'Head')
    joint(a,'Tail',(0,1.0,1.47));joint(a,'TailGlow',(0,1.0,1.47),'Tail')
    if level10:
        for i in range(3):
            shard(a,'SpineGlow',(0,-.06+i*.49,2.24),.53,'orange',.16)
        a.tube('HeadTrim',[(-.57,-1.64,2.52),(0,-1.70,2.66),(.57,-1.64,2.52)],.042,'equipment_gold','palette')
        joint(a,'HeadTrim',(0,-.66,1.97),'Head')
    return a.finish()


def drillbot(level10=False):
    a=new('drillbot',level10,True)
    orb(a,'Chassis',(0,.13,0),(1.72,1.76,1.42),'steel')
    a.cylinder('Body',(0,-.21,0),.728,.35,COLORS['drillbot'],'tint',vertices=16,rot=(pi/2,0,0))
    a.cylinder('FacePlate',(0,-.68,0),.61,.18,'equipment_dark',vertices=16,rot=(pi/2,0,0))
    for s in (-1,1):
        a.box('HazardMarks',(s*.47,-.421,.31),(.14,.06,.33),'ink',bevel=.018,rot=(0,s*.32,0))
    orb(a,'EyeLens',(0,-.804,.28),(.52,.10,.20),'warm_glow','neon')
    # Stepped spiral drill silhouette, independently spinning around the nose.
    for i in range(5):
        y=-.81-i*.19
        a.cylinder('Drill',(0,y,-.12),.38-i*.066,.23,
                   'light_steel' if i%2==0 else 'steel',vertices=8,
                   radius2=.30-i*.06,rot=(pi/2,0,i*.24))
    a.between('Drill',(0,-1.63,-.12),(0,-1.97,-.12),.105,'light_steel',vertices=8,radius2=0)
    for s in (-1,1):
        group='WingsLeft' if s<0 else 'WingsRight'
        a.between(group,(s*.69,.12,.20),(s*1.04,.12,.38),.10,'equipment_dark',vertices=8)
        a.cylinder(group,(s*1.10,.12,.41),.20,.16,'equipment_gold' if level10 else 'steel',vertices=10)
        radius=.85 if level10 else .66
        for direction in (-1,1):
            feather(a,group,(s*1.10,.12,.50),(s*1.10+direction*radius,.25,.50),.15,'light_steel')
        joint(a,group,(s*1.10,.12,.41))
        a.cylinder('Engine',(s*.47,.72,-.33),.20,.39,'equipment_dark',vertices=10,rot=(pi/2,0,0))
        orb(a,'EngineGlow',(s*.47,.94,-.33),(.27,.08,.27),'cyan' if level10 else 'orange','neon')
    joint(a,'Drill',(0,-.72,-.12))
    a.tube('HeatWave',[(-.34,-1.13,-.50),(-.18,-1.35,-.76),(.16,-1.56,-.52),(.30,-1.82,-.68)],.035,'warm_glow')
    a.hidden('HeatWave')
    joint(a,'HeatWave',(0,-1.13,-.50))
    if level10:
        a.ring('AccentTrim',(0,-.56,0),.69,.048,'equipment_gold',segments=20,sides=4)
        for s in (-1,1):
            a.box('AccentTrim',(s*.59,.10,.55),(.12,.80,.13),'equipment_gold',bevel=.035)
    return a.finish()


def solar_phoenix(level10=False):
    a=new('solarPhoenix',level10,True)
    orb(a,'Body',(0,0,0),(1.10,1.08,1.37),COLORS['solarPhoenix'],'tint')
    orb(a,'BreastFire',(0,-.49,.08),(.71,.19,.88),'white','neon')
    orb(a,'Head',(0,-.36,.78),(.80,.83,.86),'gold')
    eyes(a,'HeadGlow',.22,-.773,.91,.11,True,'white')
    a.between('Head',(0,-.71,.65),(0,-1.09,.55),.13,'equipment_gold',vertices=5,radius2=0)
    for i in range(5):
        x=(i-2)*.16
        feather(a,'HeadGlow',(x*.55,-.25,1.02),(x*1.7,-.18,1.66-abs(i-2)*.12),.095,
                'white' if i%2==0 else 'gold','neon')
    for s in (-1,1):
        wing='WingsLeft' if s<0 else 'WingsRight'
        for i in range(5):
            reach=(1.72 if level10 else 1.51)-i*.12
            feather(a,wing,(s*.38,.03,.35-i*.06),(s*reach,.16,.54-i*.25),.21,'gold')
            feather(a,wing+'Glow',(s*.77,-.08,.37-i*.05),(s*(reach+.12),.13,.58-i*.25),.095,
                    'white' if i%2==0 else 'orange','neon')
        joint(a,wing,(s*.39,0,.31));joint(a,wing+'Glow',(s*.39,0,.31),wing)
    for i in range(5):
        x=(i-2)*.20; length=1.75-abs(i-2)*.25+(.25 if level10 else 0)
        feather(a,'Tail',(x*.4,.40,-.37),(x*1.8,1.12,-length),.24,'gold','neon')
        feather(a,'Tail',(x*.4,.32,-.45),(x*1.72,1.03,-length+.20),.105,'white','neon')
    a.ring('Halo',(0,-.02,1.62),.64 if level10 else .54,.045,'equipment_gold',mode='neon',axis='Z',segments=24,sides=5)
    joint(a,'Halo',(0,-.02,1.62));joint(a,'Tail',(0,.33,-.37))
    joint(a,'Head',(0,-.23,.50));joint(a,'HeadGlow',(0,-.23,.50),'Head')
    a.ring('WorkingRing',(0,0,-1.89),1.08,.065,'gold',mode='neon',axis='Z',segments=24,sides=4)
    orb(a,'ScorchGlow',(0,0,-1.92),(1.57,1.57,.04),'orange','neon')
    a.hidden('WorkingRing');a.hidden('ScorchGlow')
    joint(a,'WorkingRing',(0,0,-1.89));joint(a,'ScorchGlow',(0,0,-1.92))
    if level10:
        for s in (-1,1):
            a.tube('AccentTrim',[(s*.36,-.42,.32),(s*.26,-.56,.03),(0,-.58,-.22)],.03,'equipment_gold','palette')
        shard(a,'CrownGem',(0,-.49,1.28),.29,'white',.11)
        joint(a,'CrownGem',(0,-.23,.50),'Head')
    return a.finish()


_SPECIES = {
    'pebblePup': pebble_pup, 'scrapSparrow': scrap_sparrow,
    'packMule': pack_mule, 'sparkHare': spark_hare, 'jetWisp': jet_wisp,
    'coinMagpie': coin_magpie, 'cargoMole': cargo_mole, 'graniteGolem': granite_golem,
    'crystalStag': crystal_stag, 'lodeWyrm': lode_wyrm, 'auroraOwl': aurora_owl,
    'meteorDrake': meteor_drake, 'drillbot': drillbot, 'solarPhoenix': solar_phoenix,
}
BUILDERS = {'pets/'+name+('_lv10' if level10 else ''): partial(builder, level10)
            for name,builder in _SPECIES.items() for level10 in (False,True)}

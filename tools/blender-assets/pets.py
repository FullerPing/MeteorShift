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
    'dustBunny': '#D6C8B2', 'emberNewt': '#FF7846', 'geodeTurtle': '#966EC8',
    'cometFox': '#7FB6FF', 'nebulaJelly': '#C882FF', 'magmaCrab': '#E65028',
    'frostYeti': '#BEE6FF', 'quartzKitsune': '#FFBEE6', 'galaxyGriffin': '#5A50C8',
    'voidLeviathan': '#3C286E',
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


# ---- 2026-10-24: ten new species (shop commons, magmaEgg / voidEgg pets and the group mascot) ----

def dust_bunny(level10=False):
    a=new('dustBunny',level10)
    a.ico('Body',(0,.15,.95),(1.75,1.75,1.65),COLORS['dustBunny'],'tint',subdivisions=2)
    # loose crater-dust puffs clumped round the round body
    for i,(x,y,z,s) in enumerate([(-.80,.15,.70,.72),(.80,.15,.70,.72),(-.55,.80,1.20,.66),(.55,.80,1.20,.66),
                                  (0,.60,1.70,.78),(-.62,-.30,.42,.56),(.62,-.30,.42,.56),(0,.95,.55,.6)]):
        a.ico('Fluff',(x,y,z),(s,s,s*.9),'cream',seed=i)
    orb(a,'Head',(0,-.62,1.58),(1.40,1.18,1.18),'cream')
    orb(a,'Head',(0,-1.13,1.40),(.64,.30,.40),'white')
    orb(a,'Head',(0,-1.28,1.50),(.18,.10,.13),'pink')
    eyes(a,'Head',.31,-1.14,1.74,.22)
    for s in (-1,1):
        orb(a,'Head',(s*.50,-1.06,1.42),(.24,.08,.14),'#FFB0E2')
        a.between('Ears',(s*.24,-.55,2.02),(s*.48,-.42,3.05),.23,'cream',vertices=8,radius2=.17)
        a.between('Ears',(s*.25,-.73,2.10),(s*.46,-.62,2.92),.12,'#FFB0E2',vertices=6,radius2=.08)
        orb(a,'Ears',(s*.48,-.42,3.05),(.34,.30,.30),'cream')
    feet(a,-.55,.55,.42,.42,'cream',.44)
    a.ico('Tail',(0,1.12,1.0),(.62,.55,.62),'white',seed=7)
    for i in range(3):
        a.ico('GreyChip',((i-1)*.25,-1.30,.18+i*.06),(.22,.24,.20),'cream',seed=i)
    a.hidden('GreyChip')
    joint(a,'GreyChip',(0,-1.30,.18))
    joint(a,'Head',(0,-.40,1.32));joint(a,'Ears',(0,-.55,1.98));joint(a,'Tail',(0,.90,1.0))
    if level10:
        a.ring('AccentTrim',(0,-.42,1.05),.66,.07,'equipment_gold',axis='Y',segments=16,sides=4)
        orb(a,'AccentTrim',(0,-1.10,.92),(.26,.12,.26),'gold')
        for s in (-1,1):
            shard(a,'EarsGlow',(s*.50,-.42,3.32),.34,'gold',.14)
        joint(a,'EarsGlow',(0,-.55,1.98),'Ears')
    return a.finish()


def ember_newt(level10=False):
    a=new('emberNewt',level10)
    orb(a,'Body',(0,.20,.62),(1.15,2.0,.85),COLORS['emberNewt'],'tint')
    orb(a,'Belly',(0,-.05,.40),(.86,1.55,.42),'cream')
    for i,(x,y) in enumerate([(-.25,-.25),(.22,.15),(-.18,.62),(.20,.95)]):
        orb(a,'Spots',(x,y,1.0-abs(y-.2)*.12),(.24,.24,.12),'gold')
    orb(a,'Head',(0,-1.05,.82),(1.28,1.05,.80),'orange')
    for s in (-1,1):
        orb(a,'Head',(s*.33,-1.18,1.10),(.44,.40,.40),'orange')
        orb(a,'Head',(s*.52,-1.36,.78),(.18,.06,.10),'#FFB0E2')
    eyes(a,'Head',.33,-1.36,1.13,.21)
    a.tube('Head',[(-.24,-1.53,.72),(0,-1.575,.66),(.24,-1.53,.72)],.03,'ink','palette')
    for s in (-1,1):
        for base,y,glow in [('FrontLeg',-.50,'FrontToeGlow'),('BackLeg',.80,'BackToeGlow')]:
            g=base if s<0 else base+'.001'; tg=glow if s<0 else glow+'.001'
            a.between(g,(s*.40,y,.55),(s*.70,y-.08,.30),.15,'orange',vertices=6,radius2=.12)
            a.between(g,(s*.70,y-.08,.30),(s*.78,y-.12,.06),.12,'orange',vertices=6,radius2=.10)
            for k in (-1,0,1):
                orb(a,tg,(s*.82+k*.10,y-.30+abs(k)*.06,.06),(.17,.22,.13),'orange','neon')
            joint(a,g,(s*.40,y,.55),base);joint(a,tg,(s*.40,y,.55),base)
    tail=[(0,1.05,.60),(0,1.65,.48),(.30,2.15,.36),(.62,2.40,.30)]
    for i in range(3):
        a.between('Tail',tail[i],tail[i+1],.30-i*.09,'orange',vertices=8,radius2=.22-i*.08)
    shard(a,'TailGlow',(.66,2.45,.40),.22,'orange',.07)
    joint(a,'Tail',(0,1.0,.60));joint(a,'TailGlow',(0,1.0,.60),'Tail')
    joint(a,'Head',(0,-.62,.70))
    a.tube('HeatWave',[(-.30,-1.55,1.35),(-.10,-1.75,1.55),(.12,-1.62,1.75),(.28,-1.85,1.95)],.035,'warm_glow')
    a.hidden('HeatWave');joint(a,'HeatWave',(0,-1.55,1.35))
    if level10:
        for i in range(4):
            shard(a,'SpineGlow',(0,-.40+i*.42,1.0+(.04 if i in (1,2) else 0)),.30-i*.03,'orange',.11)
        for s in (-1,1):
            feather(a,'Head',(s*.15,-.92,1.18),(s*.42,-.70,1.62),.13,'gold')
        a.ring('AccentTrim',(0,-.55,.66),.50,.05,'equipment_gold',axis='Y',segments=16,sides=4)
    return a.finish()


def geode_turtle(level10=False):
    a=new('geodeTurtle',level10)
    a.ellipsoid('Body',(0,.15,.92),(2.3,2.5,1.65),COLORS['geodeTurtle'],'tint',segments=14,rings=8)
    a.ring('Rim',(0,.15,.62),1.12,.15,'stone',axis='Z',segments=18,sides=5)
    for i in range(7):
        t=pi*.15+i*pi*2/7
        a.ico('Rim',(cos(t)*.95,.15+sin(t)*1.05,1.15),(.62,.62,.38),'stone',seed=10+i)
    orb(a,'Geode',(0,.20,1.62),(1.35,1.45,.30),'#161E36')
    a.ring('Geode',(0,.20,1.68),.70,.10,'#C8CEDC',axis='Z',segments=16,sides=4)
    tall=.95 if level10 else .70
    for i,(x,y,h,lean) in enumerate([(0,.2,tall,(0,0)),(-.30,.0,.50,(-.18,-.10)),(.30,.05,.55,(.20,-.08)),
                                     (-.18,.48,.48,(-.12,.18)),(.22,.45,.44,(.15,.16))]):
        a.between('ShellGlow',(x,y,1.45),(x+lean[0]*1.4,y+lean[1]*1.4,1.55+h*1.35),.22 if i==0 else .16,'violet','neon',vertices=5,radius2=0)
    a.between('Head',(0,-.85,.70),(0,-1.18,.88),.28,'teal',vertices=8)
    orb(a,'Head',(0,-1.38,.98),(.98,.92,.86),'teal')
    for s in (-1,1):
        orb(a,'Head',(s*.34,-1.72,.86),(.20,.06,.11),'#FFB0E2')
    eyes(a,'Head',.23,-1.76,1.12,.19)
    a.tube('Head',[(-.16,-1.81,.83),(0,-1.84,.79),(.16,-1.81,.83)],.028,'ink','palette')
    feet(a,-.70,.95,.88,.55,'teal',.62)
    a.between('Tail',(0,1.30,.50),(0,1.75,.34),.15,'teal',vertices=6,radius2=0)
    a.ico('OreChunk',(0,.20,2.05),(.40,.40,.45),'violet',seed=4)
    a.hidden('OreChunk');joint(a,'OreChunk',(0,.20,2.05))
    joint(a,'Head',(0,-.80,.72));joint(a,'Tail',(0,1.25,.50))
    if level10:
        a.ring('AccentTrim',(0,.15,.80),1.14,.06,'equipment_gold',axis='Z',segments=18,sides=4)
        a.ring('AccentTrim',(0,.20,1.76),.70,.05,'equipment_gold',axis='Z',segments=16,sides=4)
        a.between('ShellGlow',(.05,.30,1.55),(.12,.36,2.2),.09,'white','neon',vertices=5,radius2=0)
    return a.finish()


def comet_fox(level10=False):
    a=new('cometFox',level10)
    orb(a,'Body',(0,.20,1.05),(1.15,1.75,1.15),COLORS['cometFox'],'tint')
    orb(a,'Chest',(0,-.45,.98),(.74,.40,.80),'white')
    orb(a,'Head',(0,-.72,1.78),(1.32,1.10,1.08),'#6CB8FF')
    orb(a,'Head',(0,-1.22,1.56),(.60,.52,.40),'white')
    orb(a,'Head',(0,-1.49,1.64),(.18,.10,.13),'ink')
    for s in (-1,1):
        orb(a,'Head',(s*.50,-.98,1.52),(.46,.36,.38),'white')
        a.between('Ears',(s*.30,-.66,2.16),(s*.56,-.62,2.92),.27,'#6CB8FF',vertices=6,radius2=.02)
        a.between('Ears',(s*.30,-.78,2.18),(s*.52,-.74,2.75),.15,'white',vertices=6,radius2=.01)
    eyes(a,'Head',.30,-1.23,1.90,.20)
    feet(a,-.45,.78,.36,.78,'#6CB8FF',.32)
    for s in (-1,1):
        for base,y in [('FrontLeg',-.45),('BackLeg',.78)]:
            g=base if s<0 else base+'.001'
            orb(a,g,(s*.36,y-.06,.10),(.34,.42,.20),'white')
    # one big brush tail sweeping up and back, white comet tip
    orb(a,'Tail',(0,1.05,1.22),(.55,.60,.55),'#6CB8FF')
    for loc,size,c in [((0,1.72,1.72),(1.0,1.05,2.15),'#6CB8FF'),((0,2.42,2.42),(.80,.85,1.0),'white')]:
        orb(a,'Tail',loc,size,c).rotation_euler=(-.79,0,0)
    for i,(x,y,z,c) in enumerate([(.52,1.55,1.60,'white'),(-.50,1.85,1.95,'cyan'),(.48,2.15,2.15,'gold'),
                                  (-.42,2.35,2.50,'white'),(0,1.80,2.50,'cyan'),(0,2.95,2.75,'white'),(.22,3.18,2.58,'gold')]):
        a.ico('TailGlow',(x,y,z),(.16,.16,.16),c,'neon',seed=20+i)
    joint(a,'Tail',(0,.88,1.18));joint(a,'TailGlow',(0,.88,1.18),'Tail')
    joint(a,'Head',(0,-.45,1.50));joint(a,'Ears',(0,-.70,2.10))
    a.tube('SparkLink',[(-.27,-1.2,.54),(.07,-1.5,.79),(-.06,-1.63,.93),(.30,-1.98,1.20)],.055,'cyan')
    a.hidden('SparkLink');joint(a,'SparkLink',(0,-1.2,.54))
    if level10:
        a.ring('AccentTrim',(0,-.42,1.38),.50,.06,'equipment_gold',axis='Y',segments=16,sides=4)
        a.between('HeadGlow',(0,-1.18,2.22),(0,-1.24,2.52),.10,'gold','neon',vertices=4,radius2=0)
        a.between('HeadGlow',(-.14,-1.21,2.32),(.14,-1.21,2.32),.07,'gold','neon',vertices=4)
        joint(a,'HeadGlow',(0,-.45,1.50),'Head')
        for i,(x,y,z) in enumerate([(.50,2.00,2.30),(-.50,2.10,2.30),(-.15,3.35,2.95)]):
            a.ico('TailGlow',(x,y,z),(.20,.20,.20),'white','neon',seed=40+i)
    return a.finish()


def nebula_jelly(level10=False):
    a=new('nebulaJelly',level10,True)
    a.ellipsoid('Body',(0,0,.35),(1.95,1.95,1.55),COLORS['nebulaJelly'],'tint',segments=14,rings=8)
    a.ring('Rim',(0,0,-.30),.86,.14,'#FFB0E2',axis='Z',segments=18,sides=5)
    orb(a,'Core',(0,0,-.30),(1.25,1.25,.55),'#FA78C8','neon')
    for i in range(11):
        t=i*2.39; f=.25+.6*((i*.37)%1)
        r=.97*sin(f*pi/2+.35); z=.35+.77*cos(f*pi/2+.35)
        orb(a,'Speckles',(r*cos(t),r*sin(t),z),(.13,.13,.13),['white','cyan','#FFE66E'][i%3],'neon')
    for s in (-1,1):
        orb(a,'Face',(s*.50,-.82,.05),(.24,.08,.13),'#FA78C8')
    eyes(a,'Face',.27,-.90,.22,.20)
    a.tube('Face',[(-.13,-.94,-.02),(0,-.96,-.07),(.13,-.94,-.02)],.026,'ink','palette')
    for i in range(8):
        t=2*pi*i/8+pi/8; x,y=cos(t)*.78,sin(t)*.78
        pts=[(x*(1-.12*k)+.10*sin(k*1.7+i),y*(1-.12*k)+.10*cos(k*1.7+i),-.35-.36*k) for k in range(5)]
        a.tube('Tail',pts,.07,'violet' if i%2 else '#FFB0E2','palette',sides=5)
    for i in range(3):
        t=2*pi*i/3
        pts=[(.22*cos(t)+.12*sin(k*1.4+i),.22*sin(t)+.12*cos(k*1.4),-.45-.30*k) for k in range(5)]
        a.tube('Tail',pts,.13-.01*i,'#CE9CFF','palette',sides=6)
    joint(a,'Tail',(0,0,-.30))
    if level10:
        a.ring('AccentTrim',(0,0,-.18),.92,.06,'equipment_gold',axis='Z',segments=18,sides=4)
        a.ring('Halo',(0,0,1.45),.55,.05,'equipment_gold',mode='neon',axis='Z',segments=20,sides=4)
        joint(a,'Halo',(0,0,1.45))
        shard(a,'CrownGlow',(0,-.05,1.20),.30,'#FFE66E',.12)
    return a.finish()


def magma_crab(level10=False):
    a=new('magmaCrab',level10)
    orb(a,'Body',(0,.10,.85),(2.1,1.7,1.05),COLORS['magmaCrab'],'tint')
    orb(a,'Belly',(0,.05,.58),(1.75,1.40,.45),'#FFB24A')
    plates=[(-.45,-.05),(.45,-.05),(0,.42),(-.52,.55),(.52,.55),(0,-.38)]
    for i,(x,y) in enumerate(plates):
        a.ico('Shell',(x,y,1.22),(.62,.55,.32),'equipment_dark',seed=30+i)
    for pts in [[(-.75,-.3,1.30),(-.2,-.15,1.38),(.2,.15,1.40),(.78,.25,1.28)],
                [(0,-.62,1.20),(0,.05,1.40),(-.25,.7,1.34)],[(.25,.75,1.30),(.05,.25,1.40)]]:
        a.tube('ShellGlow',pts,.045,'orange')
    for s in (-1,1):
        a.between('Head',(s*.30,-.55,1.10),(s*.38,-.62,1.70),.07,'equipment_dark',vertices=6)
        orb(a,'Head',(s*.38,-.64,1.82),(.38,.36,.38),'white')
        orb(a,'Head',(s*.38,-.81,1.84),(.19,.06,.21),'ink')
        orb(a,'Head',(s*.41,-.845,1.88),(.05,.03,.06),'white')
        g='Claw' if s<0 else 'Claw.001'
        a.between(g,(s*.85,-.40,.85),(s*1.25,-.92,.95),.14,'red',vertices=6)
        orb(a,g,(s*1.32,-1.20,1.0),(.78,.82,.62),'red')
        a.between(g,(s*1.30,-1.52,1.10),(s*1.20,-1.98,1.20),.18,'red',vertices=6,radius2=.03)
        a.between(g,(s*1.42,-1.52,.90),(s*1.38,-1.86,.80),.13,'red',vertices=6,radius2=.03)
        joint(a,g,(s*.85,-.40,.85),'FrontLeg')
        bg='BackLeg' if s<0 else 'BackLeg.001'
        for y in (-.15,.25,.65):
            a.between(bg,(s*.85,y,.70),(s*1.35,y+.05,.62),.08,'#A02228',vertices=6)
            a.between(bg,(s*1.35,y+.05,.62),(s*1.52,y+.08,.02),.08,'#A02228',vertices=6,radius2=.03)
        joint(a,bg,(s*.85,.25,.70),'BackLeg')
    a.tube('Head',[(-.20,-.80,.72),(0,-.86,.66),(.20,-.80,.72)],.03,'ink','palette')
    joint(a,'Head',(0,-.45,1.05))
    for i in range(3):
        a.ico('GreyChip',((i-1)*.30,-1.50,.20+i*.06),(.22,.24,.20),'equipment_dark',seed=i)
    a.hidden('GreyChip');joint(a,'GreyChip',(0,-1.50,.20))
    if level10:
        for i,x in enumerate((-.32,0,.32)):
            a.between('AccentTrim',(x,-.30,1.38),(x*1.2,-.34,1.68+(.12 if i==1 else 0)),.09,'equipment_gold',vertices=5,radius2=0)
        for s in (-1,1):
            g='ClawGlow' if s<0 else 'ClawGlow.001'
            a.tube(g,[(s*1.05,-1.10,1.28),(s*1.32,-1.25,1.32),(s*1.55,-1.10,1.20)],.04,'orange')
            joint(a,g,(s*.85,-.40,.85),'FrontLeg')
    return a.finish()


def frost_yeti(level10=False):
    a=new('frostYeti',level10)
    orb(a,'Body',(0,.10,1.40),(1.95,1.60,2.05),COLORS['frostYeti'],'tint')
    for i,(x,y,z,s) in enumerate([(0,-.15,2.42,.70),(-.42,-.05,2.30,.55),(.42,-.05,2.30,.55),(-.85,.05,1.95,.55),(.85,.05,1.95,.55)]):
        a.ico('Fur',(x,y,z),(s,s,s*.85),'white',seed=50+i)
    orb(a,'Head',(0,-.62,1.82),(1.20,.45,.98),'frost')
    eyes(a,'Head',.26,-.86,1.98,.20)
    orb(a,'Head',(0,-.87,1.60),(.48,.06,.20),'ink')
    for s in (-1,1):
        a.box('Head',(s*.10,-.89,1.66),(.10,.04,.09),'white',bevel=.02)
        orb(a,'Head',(s*.44,-.82,1.72),(.20,.06,.11),'#FFB0E2')
        a.between('Head',(s*.48,-.40,2.40),(s*.80,-.32,2.86),.13,'cream',vertices=6,radius2=.02)
        g='FrontLeg' if s<0 else 'FrontLeg.001'
        orb(a,g,(s*1.02,-.12,1.25),(.62,.66,1.30),'white')
        orb(a,g,(s*1.08,-.22,.62),(.48,.52,.40),'frost')
        joint(a,g,(s*.86,-.08,1.85),'FrontLeg')
        bg='BackLeg' if s<0 else 'BackLeg.001'
        orb(a,bg,(s*.50,.05,.36),(.66,.76,.62),'white')
        orb(a,bg,(s*.50,-.18,.10),(.58,.66,.22),'frost')
        joint(a,bg,(s*.50,.05,.62),'BackLeg')
    joint(a,'Head',(0,-.40,1.65))
    a.box('Pannier',(0,1.05,1.75),(1.25,.72,1.20),'glass',bevel=.16)
    a.box('Pannier',(-.22,.70,2.02),(.36,.06,.30),'white',bevel=.03)
    a.box('Pannier',(.30,.70,1.48),(.18,.06,.14),'#DCF8FF',bevel=.02)
    for s in (-1,1):
        a.tube('Pannier',[(s*.45,1.0,2.30),(s*.88,.25,2.32),(s*1.02,-.32,1.95),(s*.98,-.22,1.55)],.065,'wood','palette')
    a.ico('OreChunk',(0,1.05,2.55),(.42,.42,.45),'orange',seed=6)
    a.hidden('OreChunk');joint(a,'OreChunk',(0,1.05,2.55))
    if level10:
        a.between('IceGlow',(-.25,1.42,1.45),(-.30,1.62,2.10),.16,'cyan','neon',vertices=5,radius2=0)
        a.between('IceGlow',(.20,1.42,1.40),(.30,1.60,1.92),.12,'cyan','neon',vertices=5,radius2=0)
        for s in (-1,1):
            a.box('AccentTrim',(s*.66,-.42,1.85),(.20,.08,.22),'equipment_gold',bevel=.03)
            g='FrontLeg' if s<0 else 'FrontLeg.001'
            a.ring(g,(s*1.05,-.15,.86),.30,.05,'equipment_gold',axis='Z',segments=14,sides=4)
    return a.finish()


def quartz_kitsune(level10=False):
    a=new('quartzKitsune',level10)
    orb(a,'Body',(0,.20,1.05),(1.10,1.65,1.15),COLORS['quartzKitsune'],'tint')
    orb(a,'Chest',(0,-.45,.98),(.72,.40,.80),'white')
    orb(a,'Head',(0,-.72,1.78),(1.28,1.08,1.05),'#FFB0E2')
    orb(a,'Head',(0,-1.20,1.56),(.58,.50,.40),'white')
    orb(a,'Head',(0,-1.46,1.64),(.17,.10,.12),'ink')
    for s in (-1,1):
        orb(a,'Head',(s*.48,-.98,1.52),(.42,.34,.36),'white')
        a.between('Head',(s*.30,-1.23,1.70),(s*.52,-1.10,1.66),.035,'#C44696',vertices=4)
        a.between('Ears',(s*.30,-.66,2.14),(s*.52,-.62,2.88),.26,'#FFB0E2',vertices=6,radius2=.05)
        a.between('Ears',(s*.30,-.78,2.16),(s*.48,-.74,2.70),.14,'white',vertices=6,radius2=.02)
        shard(a,'EarsGlow',(s*.53,-.62,2.96),.22,'#FA78C8',.07)
    eyes(a,'Head',.29,-1.21,1.90,.19)
    a.between('HeadGlow',(0,-1.10,2.10),(0,-1.16,2.36),.09,'#FA78C8','neon',vertices=4,radius2=0)
    feet(a,-.45,.78,.36,.78,'#FFB0E2',.32)
    for s in (-1,1):
        for base,y in [('FrontLeg',-.45),('BackLeg',.78)]:
            g=base if s<0 else base+'.001'
            orb(a,g,(s*.36,y-.06,.10),(.34,.42,.20),'white')
    for ang in (-.62,0,.62):
        base=(0,1.0,1.18); mid=(sin(ang)*.55,1.45,1.70-abs(ang)*.12); tip=(sin(ang)*1.0,1.75,2.55-abs(ang)*.35)
        a.between('Tail',base,mid,.20,'#FFB0E2',vertices=6,radius2=.26)
        a.between('Tail',mid,tip,.26,'pink',vertices=6,radius2=.13)
        end=(tip[0]*1.12,tip[1]+.10,tip[2]+.45)
        a.between('TailGlow',tip,end,.13,'#FA78C8','neon',vertices=6,radius2=0)
        if level10:
            a.ring('Tail',mid,.25,.04,'equipment_gold',axis='Z',segments=12,sides=4)
    joint(a,'Tail',(0,.95,1.18));joint(a,'TailGlow',(0,.95,1.18),'Tail')
    joint(a,'Head',(0,-.45,1.50));joint(a,'HeadGlow',(0,-.45,1.50),'Head')
    joint(a,'Ears',(0,-.70,2.10));joint(a,'EarsGlow',(0,-.70,2.10),'Ears')
    for i in range(3):
        shard(a,'TargetShard',((i-1)*.23,-1.62,.27+i*.08),.43,'#FA78C8',.11)
    a.hidden('TargetShard');joint(a,'TargetShard',(0,-1.62,.27))
    if level10:
        a.ring('AccentTrim',(0,-.42,1.38),.50,.06,'equipment_gold',axis='Y',segments=16,sides=4)
        orb(a,'CollarGlow',(0,-.92,1.12),(.20,.14,.24),'#FA78C8','neon')
        for s in (-1,1):
            a.ring('Ears',(s*.45,-.63,2.62),.15,.04,'equipment_gold',axis='Z',segments=12,sides=4)
    return a.finish()


def galaxy_griffin(level10=False):
    a=new('galaxyGriffin',level10,True)
    orb(a,'Body',(0,.15,-.05),(1.30,1.60,1.30),COLORS['galaxyGriffin'],'tint')
    orb(a,'Chest',(0,-.42,.02),(.86,.40,.98),'#465882')
    orb(a,'Head',(0,-.45,.72),(1.05,1.0,1.0),'navy')
    for s in (-1,1):
        orb(a,'Head',(s*.25,-.905,.82),(.26,.075,.28),'white')
        feather(a,'Head',(s*.25,-.30,1.12),(s*.42,.10,1.55),.15,'#A462F6')
    eyes(a,'Head',.25,-.955,.82,.15)
    a.between('Head',(0,-.88,.62),(0,-1.36,.48),.18,'gold',vertices=5,radius2=0)
    a.between('Head',(0,-1.30,.50),(0,-1.36,.34),.06,'#CE8C14',vertices=5,radius2=0)
    feather(a,'Head',(0,-.40,1.18),(0,-.05,1.62),.17,'#A462F6')
    for i,(x,y,z) in enumerate([(.30,-.25,1.18),(-.35,-.55,1.10),(.42,-.75,.95)]):
        orb(a,'HeadGlow',(x,y,z),(.08,.08,.08),'white','neon')
    joint(a,'HeadGlow',(0,-.30,.30),'Head')
    for i,(x,y,z) in enumerate([(.45,.30,.40),(-.50,.10,.35),(.55,.60,-.20),(-.40,.75,.10),(.15,.85,.30),(-.55,.35,-.35),(.35,-.10,-.50)]):
        orb(a,'Stars',(x,y,z),(.09,.09,.09),'white' if i%3 else 'gold','neon')
    for s in (-1,1):
        group='WingsLeft' if s<0 else 'WingsRight'
        for i in range(5):
            feather(a,group,(s*.55,.10,.35-i*.05),(s*((1.85 if level10 else 1.65)-i*.13),.30,.75-i*.30),.21,
                    ['navy','#465882','#A462F6','navy','#2E80F0'][i])
        for k,(dx,dz) in enumerate([(1.30,.65),(1.05,.25),(1.40,.05),(.95,-.15)]):
            orb(a,group+'Glow',(s*dx,.14,dz),(.08,.08,.08),'white','neon')
        joint(a,group,(s*.58,.08,.32));joint(a,group+'Glow',(s*.58,.08,.32),group)
        a.between('Feet',(s*.28,-.30,-.55),(s*.28,-.42,-.86),.06,'gold',vertices=6)
        for k in (-1,0,1):
            a.between('Feet',(s*.28,-.42,-.86),(s*.28+k*.09,-.62,-.90),.04,'#CE8C14',vertices=4,radius2=.01)
        bg='BackLeg' if s<0 else 'BackLeg.001'
        orb(a,bg,(s*.42,.55,-.55),(.46,.55,.60),'navy')
        joint(a,bg,(s*.42,.55,-.35),'BackLeg')
    a.tube('Tail',[(0,.85,-.20),(0,1.30,-.35),(0,1.65,-.20),(0,1.85,.10)],.08,'navy','palette')
    orb(a,'Tail',(0,1.92,.22),(.34,.30,.40),'#A462F6')
    orb(a,'TailGlow',(0,1.95,.48),(.12,.12,.12),'white','neon')
    joint(a,'Tail',(0,.80,-.20));joint(a,'TailGlow',(0,.80,-.20),'Tail')
    joint(a,'Head',(0,-.30,.30))
    if level10:
        for x in (-.22,0,.22):
            a.between('HeadTrim',(x,-.55,1.15),(x*1.3,-.58,1.45+(.12 if x==0 else 0)),.07,'equipment_gold',vertices=5,radius2=0)
        a.tube('HeadTrim',[(-.30,-.60,1.12),(0,-.68,1.16),(.30,-.60,1.12)],.05,'equipment_gold','palette')
        joint(a,'HeadTrim',(0,-.30,.30),'Head')
        a.tube('AccentGlow',[(-.38,-.55,.35),(0,-.64,.10),(.38,-.55,.35)],.035,'white')
    return a.finish()


def void_leviathan(level10=False):
    a=new('voidLeviathan',level10,True)
    # an air-swimming serpent: head, the tinted first segment and a wavy run of tail segments
    seg=[(0,-.35,0,1.0),(.20,.20,.15,.88),(.12,.70,.42,.78),(-.14,1.12,.66,.68),(-.26,1.50,.95,.58),(-.12,1.82,1.25,.48),(.14,2.05,1.55,.40)]
    last='Tail.%03d'%(len(seg)-2)
    for i,(x,y,z,s) in enumerate(seg):
        g='Body' if i==0 else ('Tail' if i==1 else 'Tail.%03d'%(i-1))
        orb(a,g,(x,y,z),(s,s*1.05,s*.95),COLORS['voidLeviathan'] if i==0 else 'navy','tint' if i==0 else 'palette')
        orb(a,g if i else 'Belly',(x,y-.05,z-s*.30),(s*.66,s*.85,s*.36),'#A462F6')
        ring_g='BodyGlow' if i==0 else g+'Glow'
        nxt=seg[min(i+1,len(seg)-1)]; prv=seg[max(i-1,0)]
        band=a.ring(ring_g,(0,0,0),s*.5,.03,'cyan',mode='neon',axis='Y',segments=14,sides=4)
        band.location=(x,y,z); band.rotation_euler=Vector((nxt[0]-prv[0],nxt[1]-prv[1],nxt[2]-prv[2])).to_track_quat('Y','Z').to_euler()
        if i:
            joint(a,g,(x,y-.25,z),'Tail');joint(a,ring_g,(x,y-.25,z),'Tail')
        if i<len(seg)-1:
            feather(a,g if i else 'Fin',(x,y-.05,z+s*.40),(x,y+.25,z+s*.40+.32-i*.03),.12,'#A462F6')
    tx,ty,tz,ts=seg[-1]
    feather(a,last,(tx,ty+.1,tz),(tx-.45,ty+.75,tz+.25),.26,'#A462F6')
    feather(a,last,(tx,ty+.1,tz),(tx+.45,ty+.75,tz-.25),.26,'#A462F6')
    a.tube(last+'Glow',[(tx-.45,ty+.75,tz+.25),(tx,ty+.25,tz),(tx+.45,ty+.75,tz-.25)],.035,'cyan')
    orb(a,'Head',(0,-1.05,.15),(1.05,1.15,.92),'navy')
    orb(a,'Head',(0,-1.42,-.02),(.70,.55,.45),'#465882')
    for s in (-1,1):
        orb(a,'Head',(s*.29,-1.42,.36),(.34,.28,.32),'navy')
        a.between('Head',(s*.25,-.80,.50),(s*.45,-.45,.90),.10,'#A462F6',vertices=5,radius2=0)
        a.tube('HeadGlow',[(s*.32,-1.62,-.08),(s*.62,-1.70,-.18),(s*.85,-1.55,-.38)],.03,'cyan')
    eyes(a,'HeadGlow',.29,-1.555,.38,.20,True,'cyan')
    a.tube('Head',[(-.20,-1.66,-.12),(0,-1.70,-.16),(.20,-1.66,-.12)],.028,'ink','palette')
    feather(a,'Fin',(0,-.95,.55),(0,-.55,1.05),.18,'#A462F6')
    a.tube('FinGlow',[(0,-.95,.62),(0,-.70,.92),(0,-.50,1.0)],.03,'cyan')
    for s in (-1,1):
        w='WingsLeft' if s<0 else 'WingsRight'
        feather(a,w,(s*.42,-.30,-.15),(s*1.05,.0,-.45),.22,'#A462F6')
        feather(a,w,(s*.42,-.20,-.20),(s*.90,.20,-.60),.16,'navy')
        joint(a,w,(s*.42,-.30,-.15))
    joint(a,'Head',(0,-.65,.10));joint(a,'HeadGlow',(0,-.65,.10),'Head')
    if level10:
        for x in (-.20,0,.20):
            a.between('HeadTrim',(x,-1.05,.55),(x*1.3,-1.05,.85+(.12 if x==0 else 0)),.07,'equipment_gold',vertices=5,radius2=0)
        joint(a,'HeadTrim',(0,-.65,.10),'Head')
        for i,(x,y,z,s) in enumerate(seg[:3]):
            a.ring('AccentTrim',(x,y+.15,z),s*.50,.035,'equipment_gold',axis='Y',segments=14,sides=4)
    return a.finish()


_SPECIES = {
    'pebblePup': pebble_pup, 'scrapSparrow': scrap_sparrow,
    'packMule': pack_mule, 'sparkHare': spark_hare, 'jetWisp': jet_wisp,
    'coinMagpie': coin_magpie, 'cargoMole': cargo_mole, 'graniteGolem': granite_golem,
    'crystalStag': crystal_stag, 'lodeWyrm': lode_wyrm, 'auroraOwl': aurora_owl,
    'meteorDrake': meteor_drake, 'drillbot': drillbot, 'solarPhoenix': solar_phoenix,
    'dustBunny': dust_bunny, 'emberNewt': ember_newt, 'geodeTurtle': geode_turtle,
    'cometFox': comet_fox, 'nebulaJelly': nebula_jelly, 'magmaCrab': magma_crab,
    'frostYeti': frost_yeti, 'quartzKitsune': quartz_kitsune, 'galaxyGriffin': galaxy_griffin,
    'voidLeviathan': void_leviathan,
}
BUILDERS = {'pets/'+name+('_lv10' if level10 else ''): partial(builder, level10)
            for name,builder in _SPECIES.items() for level10 in (False,True)}

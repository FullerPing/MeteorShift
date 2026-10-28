"""Twelve collectible mineral sculptures; run through the Blender asset runner."""
from assetlib import *
from math import pi, sin, cos, sqrt, exp


def _new(name):
    a = Asset('meteor/minerals/' + name, budget=1500)
    a.meta.update(Optional=True, MineralID=name, FrontAxis='-Y',
                  PivotType='BottomCenter', TargetSize=1.5)
    return a


def _finish(a, metallic=False):
    """Normalize actual geometry and use private glossy material copies."""
    bpy.context.view_layer.update()
    objects=[o for items in a.groups.values() for o in items]
    coords=[o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    low=[min(p[i] for p in coords) for i in range(3)]
    high=[max(p[i] for p in coords) for i in range(3)]
    scale=1.5/max(high[i]-low[i] for i in range(3))
    offset=Vector(((low[0]+high[0])/2,(low[1]+high[1])/2,low[2]))
    copies={}
    for obj in objects:
        obj.location=(obj.location-offset)*scale
        obj.scale*=scale
        for mod in obj.modifiers:
            if mod.type=='BEVEL':mod.width*=scale
        for i,material in enumerate(obj.data.materials):
            if material.get('Mode')!='palette':continue
            key=material.as_pointer()
            if key not in copies:
                copied=material.copy()
                copied.name=a.id.split('/')[-1]+'_'+material.name
                shader=next(n for n in copied.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
                shader.inputs['Roughness'].default_value=.31 if metallic else .23
                shader.inputs['Specular IOR Level'].default_value=.42
                shader.inputs['Metallic'].default_value=.40 if metallic else .06
                copies[key]=copied
            obj.data.materials[i]=copies[key]
    return a.finish()


def _octa(a,loc,size,color):
    x,y,z=loc; w,d,h=size
    verts=[(x,y,z-h/2),(x-w/2,y,z),(x,y-d/2,z),
           (x+w/2,y,z),(x,y+d/2,z),(x,y,z+h/2)]
    faces=[(0,2,1),(0,3,2),(0,4,3),(0,1,4),
           (5,1,2),(5,2,3),(5,3,4),(5,4,1)]
    return a.mesh('Mineral',verts,faces,color,bevel=.012)


def _prism(a,loc,radius,height,color,sides=6,lean=(0,0),tip=.22,bevel=.008):
    x,y,z=loc; verts=[]
    for top in (False,True):
        for i in range(sides):
            angle=2*pi*i/sides+pi/6
            verts.append((x+radius*cos(angle)+(lean[0] if top else 0),
                          y+radius*sin(angle)+(lean[1] if top else 0),
                          z+height*(1-tip) if top else z))
    verts.append((x+lean[0],y+lean[1],z+height))
    faces=[tuple(reversed(range(sides)))]
    faces += [(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
    faces += [(sides+i,sides+(i+1)%sides,2*sides) for i in range(sides)]
    return a.mesh('Mineral',verts,faces,color,bevel=bevel)


def _inlay(a,outline,inner_scale,body,core,depth=.34):
    """Faceted outer rim with a visible inset core, not an occluded inner object."""
    count=len(outline); cz=(max(z for x,z in outline)+min(z for x,z in outline))/2
    inner=[(x*inner_scale,cz+(z-cz)*inner_scale) for x,z in outline]
    verts=[(x,-depth*.30,z) for x,z in outline]
    verts += [(x,-depth*.61,z) for x,z in inner]
    verts += [(x,depth*.50,z) for x,z in outline]
    faces=[]
    for i in range(count):
        j=(i+1)%count
        faces.extend([(i,j,count+j,count+i),(i,2*count+i,2*count+j,j)])
    faces.append(tuple(range(2*count,3*count)))
    a.mesh('Mineral',verts,faces,body,bevel=.009)
    glow=a.poly('Glow',inner,.055,core,mode='neon',bevel=.005)
    glow.location.y=-depth*.57


def magnetite():
    a=_new('magnetite')
    a.ico('Mineral',(0,0,.12),(1.12,.84,.24),'navy',seed=4)
    for loc,size,color in [((-.05,.10,.74),(.83,.75,1.44),'#969CB0'),
                            ((-.44,-.06,.43),(.69,.65,.86),'#626C84'),
                            ((.46,.01,.49),(.70,.70,.98),'#969CB0'),
                            ((.15,-.34,.34),(.54,.54,.66),'#465882')]:
        _octa(a,loc,size,color)
    return _finish(a,True)


def _petal(a,angle,radius,height,width,color):
    # Curled radial petals, closed at their edges, made from three bent sections.
    verts=[]
    rows=4; cols=5
    for layer in (-1,1):
        for row in range(rows):
            t=row/(rows-1); r=.10+(radius-.10)*t
            for col in range(cols):
                q=(col/(cols-1)-.5)*2
                spread=width*sin(pi*(.12+.80*t))*q
                z=.16+height*t*t+.13*q*q*t+layer*.022
                verts.append((r*cos(angle)-spread*sin(angle),r*sin(angle)+spread*cos(angle),z))
    faces=[]; n=rows*cols
    for layer in range(2):
        for row in range(rows-1):
            for col in range(cols-1):
                i=layer*n+row*cols+col
                faces.append((i,i+1,i+cols+1,i+cols))
    boundary=list(range(cols))+[r*cols+cols-1 for r in range(1,rows)]+list(range(n-2,n-cols-1,-1))+[r*cols for r in range(rows-2,0,-1)]
    for i,j in zip(boundary,boundary[1:]+boundary[:1]):faces.append((i,j,j+n,i+n))
    a.mesh('Mineral',verts,faces,color)


def hematite_rose():
    a=_new('hematiteRose')
    a.ico('Mineral',(0,0,.12),(.67,.67,.24),'#A02228',seed=3)
    for i in range(7):_petal(a,2*pi*i/7,.75,.27,.29,'#D6544C' if i%2 else '#A02228')
    for i in range(5):_petal(a,2*pi*i/5+.4,.47,.57,.20,'#D6544C')
    for i in range(3):_petal(a,2*pi*i/3,.24,.71,.12,'#FF7068')
    return _finish(a,True)


def meteoric_nickel():
    a=_new('meteoricNickel')
    # Pits deform the actual nugget surface, not dark dots painted over a ball.
    seg,rows=20,10; verts=[(0,0,1.04)]
    pits=[(4,4),(12,3),(14,6),(17,5),(8,7),(1,6)]
    for j in range(1,rows):
        phi=pi*j/rows
        for i in range(seg):
            th=2*pi*i/seg
            dip=sum(.20*exp(-(((min(abs(i-pi_),seg-abs(i-pi_)))/.65)**2+((j-pj)/.65)**2)) for pi_,pj in pits)
            r=1-dip+.045*sin(3*th+phi)*sin(phi)
            verts.append((.71*r*sin(phi)*cos(th),.49*r*sin(phi)*sin(th),.52+.52*r*cos(phi)))
    bottom=len(verts);verts.append((0,0,0))
    faces=[(0,1+i,1+(i+1)%seg) for i in range(seg)]
    faces += [(1+j*seg+i,1+j*seg+(i+1)%seg,1+(j+1)*seg+(i+1)%seg,1+(j+1)*seg+i) for j in range(rows-2) for i in range(seg)]
    faces += [(bottom,1+(rows-2)*seg+(i+1)%seg,1+(rows-2)*seg+i) for i in range(seg)]
    a.mesh('Mineral',verts,faces,'#D6DAC4')
    # Intersecting Widmanstatten-like bands follow the exposed front surface.
    for slope in (-.55,.55):
        for offset in (-.23,0,.23):
            points=[]
            for i in range(7):
                x=-.46+i*.153; z=.53+offset+slope*x
                y=-.49*sqrt(max(.04,1-(x/.71)**2-((z-.52)/.52)**2))-.013
                points.append((x,y,z))
            a.tube('Mineral',points,.012,'#96A0B4','palette',sides=4)
    return _finish(a,True)


def starfall_iron():
    a=_new('starfallIron')
    outline=[((.76 if i%2==0 else .35)*sin(i*pi/5),
              .75+(.76 if i%2==0 else .35)*cos(i*pi/5)) for i in range(10)]
    _inlay(a,outline,.48,'#FFA040','warm_glow',.47)
    for x,z in [(-.25,.85),(.22,.58)]:
        a.ico('Mineral',(x,-.26,z),(.085,.055,.085),'rust',seed=2)
    return _finish(a,True)


def rime_pearl():
    a=_new('rimePearl')
    # An open ice cup with a thick rim and pointed frozen scallops.
    n=12; verts=[]
    for r,z in [(.28,0),(.58,.36),(.44,.36),(.24,.13)]:
        for i in range(n):
            t=2*pi*i/n; verts.append((r*cos(t),r*sin(t),z))
    faces=[]
    for ring in range(3):
        for i in range(n):faces.append((ring*n+i,ring*n+(i+1)%n,(ring+1)*n+(i+1)%n,(ring+1)*n+i))
    faces.extend([tuple(reversed(range(n))),tuple(range(3*n,4*n))])
    a.mesh('Mineral',verts,faces,'frost',bevel=.012)
    a.ellipsoid('Mineral',(0,0,.75),(.96,.96,1.01),'#E2F0FA',segments=16,rings=10)
    for i in range(8):
        t=2*pi*i/8
        _prism(a,(.49*cos(t),.49*sin(t),.26),.11,.28,'frost',sides=5,tip=.55,bevel=0)
    a.ellipsoid('Mineral',(-.18,-.439,.97),(.19,.045,.13),'white',segments=8,rings=4)
    return _finish(a)


def frost_opal():
    a=_new('frostOpal')
    a.ellipsoid('Mineral',(0,0,.75),(1.07,.64,1.50),'#8CE8E2',segments=20,rings=12)
    # A pearly spiral inlaid along the oval's curved front.
    points=[]
    for i in range(30):
        t=i/29; theta=t*2*pi*1.22; r=.025+.36*t
        x=r*cos(theta); z=.75+r*1.40*sin(theta)
        y=-.32*sqrt(max(.04,1-(x/.535)**2-((z-.75)/.75)**2))-.012
        points.append((x,y,z))
    a.tube('Mineral',points,.019,'#E2F0FA','palette',sides=5)
    return _finish(a)


def glacial_sapphire():
    a=_new('glacialSapphire')
    _prism(a,(0,0,0),.44,1.50,'#4888F0',tip=.24)
    # Narrow pale edge facets preserve its clean, tall six-sided silhouette.
    for angle in (7*pi/6,11*pi/6):
        x,y=.44*cos(angle),.44*sin(angle)
        a.between('Mineral',(x,y,.14),(x,y,1.08),.016,'frost',vertices=4)
    return _finish(a)


def heart_of_winter():
    a=_new('heartOfWinter')
    outline=[(0,0),(-.66,.68),(-.71,1.02),(-.56,1.29),(-.27,1.36),
             (0,1.12),(.27,1.36),(.56,1.29),(.71,1.02),(.66,.68)]
    _inlay(a,outline,.62,'#96F6FF','white',.43)
    a.tube('Mineral',[(-.58,-.19,.97),(-.42,-.21,1.16),(-.25,-.21,1.21)],.027,'frost','palette',sides=5)
    return _finish(a)


def prism_shard():
    a=_new('prismShard')
    # A skewed triangular prism, visibly different from hexagonal crystals.
    verts=[(-.49,-.24,0),(.46,-.24,0),(0,.41,0),
           (-.35,-.20,1.18),(.30,-.20,1.01),(.13,.34,1.50)]
    obj=a.mesh('Mineral',verts,[(0,2,1),(0,1,4,3),(1,2,5,4),(2,0,3,5),(3,4,5)],'#FFC4F0',bevel=.012)
    obj.data.materials.append(mat('violet','palette'))
    obj.data.materials.append(mat('frost','palette'))
    obj.data.polygons[2].material_index=1
    for index in (3,4):obj.data.polygons[index].material_index=2
    return _finish(a)


def amethyst_spire():
    a=_new('amethystSpire')
    a.ico('Mineral',(0,0,.12),(1.16,.75,.24),'#6C38BA',seed=7)
    _prism(a,(-.03,.12,.06),.27,1.44,'#AC68E8',lean=(.02,.06),tip=.25)
    _prism(a,(-.39,-.04,.06),.23,.91,'violet',lean=(-.11,-.02),tip=.26)
    _prism(a,(.37,-.10,.06),.24,1.12,'#AC68E8',lean=(.12,.02),tip=.28)
    return _finish(a)


def resonant_quartz():
    a=_new('resonantQuartz')
    # Two true pointed terminations and three inward-cut hexagonal ring grooves.
    n=6; levels=[(.23,.36),(.40,.36),(.43,.305),(.48,.305),(.51,.36),
                (.70,.36),(.73,.305),(.78,.305),(.81,.36),
                (.99,.36),(1.02,.305),(1.07,.305),(1.10,.36),(1.27,.36)]
    verts=[(r*cos(2*pi*i/n+pi/6),r*sin(2*pi*i/n+pi/6),z) for z,r in levels for i in range(n)]
    low=len(verts);high=low+1;verts.extend([(0,0,0),(0,0,1.5)])
    faces=[];grooves=[]
    for row in range(len(levels)-1):
        if row in (2,6,10):grooves.extend(range(len(faces),len(faces)+n))
        faces += [(row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i) for i in range(n)]
    last=(len(levels)-1)*n
    faces += [(low,(i+1)%n,i) for i in range(n)]
    faces += [(high,last+i,last+(i+1)%n) for i in range(n)]
    obj=a.mesh('Mineral',verts,faces,'#FF78CE')
    obj.data.materials.append(mat('#C44696','palette'))
    for index in grooves:obj.data.polygons[index].material_index=1
    return _finish(a)


def void_diamond():
    a=_new('voidDiamond')
    # A dark octahedral shell has an open diamond window for the luminous star.
    outline=[(0,0),(-.65,.82),(0,1.50),(.65,.82)]
    _inlay(a,outline,.57,'#4C2C6B','#965CFF',.61)
    star=[((.27 if i%2==0 else .064)*sin(i*pi/4),
           .80+(.40 if i%2==0 else .064)*cos(i*pi/4)) for i in range(8)]
    obj=a.poly('Glow',star,.027,'white',mode='neon',bevel=.003);obj.location.y=-.393
    for x,z,r in [(-.17,.64,.028),(.13,1.04,.023),(.25,.81,.018)]:
        a.ellipsoid('Glow',(x,-.39,z),(r,.028,r),'cyan',mode='neon',segments=6,rings=4)
    return _finish(a)


BUILDERS={
    'meteor/minerals/magnetite':magnetite,
    'meteor/minerals/hematiteRose':hematite_rose,
    'meteor/minerals/meteoricNickel':meteoric_nickel,
    'meteor/minerals/starfallIron':starfall_iron,
    'meteor/minerals/rimePearl':rime_pearl,
    'meteor/minerals/frostOpal':frost_opal,
    'meteor/minerals/glacialSapphire':glacial_sapphire,
    'meteor/minerals/heartOfWinter':heart_of_winter,
    'meteor/minerals/prismShard':prism_shard,
    'meteor/minerals/amethystSpire':amethyst_spire,
    'meteor/minerals/resonantQuartz':resonant_quartz,
    'meteor/minerals/voidDiamond':void_diamond,
}

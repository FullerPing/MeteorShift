from assetlib import *
from mathutils.bvhtree import BVHTree

def meteor_core():
    a=Asset('meteor/meteor_core',10000)
    core=a.ico('Core',(0,0,0),(56.7,56.7,56.7),'#D74E18',mode='tint',subdivisions=3,seed=1337)
    # Low-frequency warping keeps a cohesive boulder rather than noisy terrain.
    for v in core.data.vertices:
        d=v.co.normalized(); v.co*=1+.025*math.sin(d.x*8+d.z*4)*math.cos(d.y*7)
    for ax in range(3):
        extent=max(v.co[ax] for v in core.data.vertices)-min(v.co[ax] for v in core.data.vertices)
        for v in core.data.vertices:v.co[ax]*=56.7/extent
    bpy.context.view_layer.update(); tree=BVHTree.FromObject(core,bpy.context.evaluated_depsgraph_get())
    def surface(d,offset=.20):
        d=Vector(d).normalized(); hit,normal,_,_=tree.ray_cast(d*80,-d,160)
        return (hit+normal*offset if hit is not None else d*28.35),normal
    rng=random.Random(48)
    for k in range(12):
        az=math.tau*k/12
        pts=[]
        start=-.65+rng.random()*.35; end=.70+rng.random()*.55
        for j in range(40):
            t=j/39
            lat=start+(end-start)*t; ang=az+math.sin(t*14.4+k)*.08
            d=(math.cos(lat)*math.cos(ang),math.cos(lat)*math.sin(ang),math.sin(lat))
            pts.append(surface(d)[0])
        a.tube('Vein',pts,.22 if k%3 else .34,'#FF963C','neon',sides=4)
        # Branching makes each strip read as a fracture instead of a meridian.
        b=pts[17]; branch=[b]
        for j in range(1,13):branch.append(surface(Vector(b)+Vector((math.sin(az),-math.cos(az),.2))*j*.65)[0])
        a.tube('Vein',branch,.15,'#FF963C','neon',sides=4)
    for k in range(36):
        z=-.66+1.61*(k+.5)/36; az=k*math.pi*(3-math.sqrt(5)); r=math.sqrt(1-z*z)
        pos,n=surface((r*math.cos(az),r*math.sin(az),z),0)
        a.empty('NodeSlot',pos,n)
    a.meta.update({'slot_count':36,'coordinate_note':'Brief NodeSlot vertical Y is Roblox Y; Blender Z is vertical. Local +Z is the surface normal.','preview_tint':'Iron'})
    return a.finish()

def node(variant):
    a=Asset('meteor/node_piece_'+variant,3000)
    rng=random.Random(ord(variant))
    if variant=='a':
        for loc,size in [((0,0,6),(36,36,12)),((-10,-7,7),(19,23,12)),((9,5,8),(21,26,14)),((3,-9,8),(23,18,12))]:
            a.ico('Rock',loc,size,'#B87654','tint',2,seed=rng.randrange(500))
    elif variant=='b':
        a.ico('Rock',(0,0,4),(40,38,8),'#B87654','tint',2,seed=9)
        for x,y,z,w,h in [(-11,5,9,16,15),(2,8,9,17,17),(12,0,8,15,13),(-3,-9,8,23,12)]:
            ob=a.box('Rock',(x,y,z),(w,13,h),'#B87654',bevel=1.2,mode='tint',rot=(.12,.16*x/12,.2))
    elif variant=='c':
        for loc,size in [((0,0,3),(40,40,6)),((-1,0,6),(34,33,6)),((2,3,9),(26,27,6)),((-2,3,11),(18,20,5))]:
            a.ico('Rock',loc,size,'#B87654','tint',2,seed=rng.randrange(500))
    else:
        a.ico('Rock',(0,0,3),(38,38,6),'#9E6CCC','tint',2,seed=9)
        for x,y,h,r in [(-10,4,14,7),(0,4,19,7),(10,1,14,6),(-2,-9,13,6),(7,10,11,5)]:
            a.cylinder('Rock',(x,y,3+h/2),r,h,'#9E6CCC','tint',vertices=6,radius2=r*.65)
            a.cylinder('Rock',(x,y,3+h+4),r*.65,8,'#9E6CCC','tint',vertices=6,radius2=0)
    bpy.context.view_layer.update()
    trees=[BVHTree.FromObject(o,bpy.context.evaluated_depsgraph_get()) for o in a.groups['Rock']]
    for i in range(5 if variant!='d' else 7):
        az=i*math.tau/(5 if variant!='d' else 7)+.3; x=math.cos(az)*11;y=math.sin(az)*10
        heights=[]
        for o in a.groups['Rock']:
            local=o.matrix_world.inverted()@Vector((x,y,60)); direct=o.matrix_world.inverted().to_3x3()@Vector((0,0,-1))
            hit,co,normal,face=o.ray_cast(local,direct)
            if hit:heights.append((o.matrix_world@co).z)
        z=(max(heights) if heights else 8)+1.9
        a.ico('Ore',(x,y,z),(7,6,7),'#C4AA96' if variant!='d' else '#FF7AD6','tint',2,seed=i)
    # Exact bounding envelope is an import contract, independent of the sculpt layout.
    bpy.context.view_layer.update(); obs=[o for ps in a.groups.values() for o in ps]
    pts=[o.matrix_world@Vector(p) for o in obs for p in o.bound_box]
    lo=Vector([min(p[j] for p in pts) for j in range(3)]); hi=Vector([max(p[j] for p in pts) for j in range(3)])
    s=Vector((40/(hi.x-lo.x),40/(hi.y-lo.y),17/(hi.z-lo.z)))
    for o in obs:
        world=o.matrix_world.copy()
        for v in o.data.vertices:
            p=world@v.co; v.co=((p.x-(lo.x+hi.x)/2)*s.x,(p.y-(lo.y+hi.y)/2)*s.y,(p.z-lo.z)*s.z)
        o.matrix_world=Matrix.Identity(4)
    a.meta['preview_tint']='Iron' if variant!='d' else 'Crystal'
    return a.finish()

def ore_chunk():
    a=Asset('meteor/ore_chunk',1500); a.ico('Ore',(0,0,.5),(1,1,1),'#C4AA96','tint',2,seed=44);return a.finish()

ORE={'iron':'#C4AA96','frost':'#60E2FF','crystal':'#FF7AD6','alien':'#78FF96'}
def ore(kind):
    a=Asset('items/ore_'+kind,800); c=ORE[kind]
    if kind=='iron':
        a.ico('Ore',(0,0,.55),(1.2,1.05,1.1),c,'tint',2,seed=22)
        a.ico('Ore',(.25,-.25,.60),(.6,.65,.7),c,'tint',1,seed=4)
    elif kind in ('frost','crystal'):
        for x,y,h,r in [(-.3,.1,.8,.25),(.12,.14,1.2,.28),(.30,-.20,.65,.23),(-.1,-.3,.7,.22)]:
            a.cylinder('Ore',(x,y,h*.4),r,h*.8,c,'tint',6,radius2=r*.8)
            a.cylinder('Ore',(x,y,h*.9),r*.8,h*.2,c,'tint',6,radius2=0)
    else:
        for loc,size in [((0,0,.5),(1.1,1,.95)),((.35,-.2,.5),(.5,.6,.7)),((-.2,.25,.75),(.7,.6,.6))]:a.ellipsoid('Ore',loc,size,c,'tint',10,6)
        a.meta['RobloxMaterial']='Neon'
    return a.finish()

def ingot(a,group,loc,color,mode='tint',scale=1,logo=True):
    verts=[(-1,-.5,0),(1,-.5,0),(1,.5,0),(-1,.5,0),(-.8,-.35,.8),(.8,-.35,.8),(.8,.35,.8),(-.8,.35,.8)]
    verts=[Vector(v)*scale+Vector(loc) for v in verts]
    a.mesh(group,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],color,mode,bevel=.055*scale)
    if not logo:return
    # A raised meteor seal, kept in the same tint mesh.
    p=Vector(loc)+Vector((.12,0,.816))*scale
    a.cylinder(group,p,.18*scale,.045*scale,color,mode,vertices=7)
    for i in range(3):a.between(group,Vector(loc)+Vector((-.45,.13*(i-1),.825))*scale,Vector(loc)+Vector((-.05,.09*(i-1),.825))*scale,.022*scale,color,mode,vertices=4)
def bar(kind):
    a=Asset('items/bar_'+kind,800);ingot(a,'Bar',(0,0,0),ORE[kind]);return a.finish()
def bar_stack():
    a=Asset('items/bar_stack',800)
    for level,count in enumerate((3,2,1)):
        for j in range(count):ingot(a,'Bars',(0,(j-(count-1)/2)*.98,level*.73),'gold','palette',.9,logo=False)
    for o in a.groups['Bars']:
        for v in o.data.vertices:v.co.x*=4/1.8;v.co.y*=3/2.86;v.co.z*=2/2.18
    return a.finish()
def coin():
    a=Asset('items/coin',800)
    a.cylinder('Coin',(0,0,1),.91,.22,'gold',vertices=32,rot=(math.pi/2,0,0))
    for y in [-.12,.12]:
        a.ring('Coin',(0,y,1),.91,.055,'gold',segments=32,sides=4)
        # Geometric dollar glyph: thick stroke plus a continuous angular S.
        a.between('Coin',(0,y*1.30,.40),(0,y*1.30,1.61),.045,'gold',vertices=4)
        a.tube('Coin',[(.30,y*1.4,1.42),(.13,y*1.4,1.52),(-.24,y*1.4,1.42),(-.27,y*1.4,1.22),(.22,y*1.4,.95),(.26,y*1.4,.77),(-.13,y*1.4,.59),(-.32,y*1.4,.70)],.065,'gold','palette',sides=4)
    return a.finish()
def core_shard():
    a=Asset('items/core_shard',800)
    a.cylinder('Shard',(0,0,.68),.38,.83,'#9661FF','neon',vertices=5,radius2=.29)
    a.cylinder('Shard',(0,0,1.215),.29,.40,'cyan','neon',vertices=5,radius2=0)
    a.cylinder('Clasp',(0,0,.16),.40,.30,'equipment_gold',vertices=5,radius2=.36)
    for k in range(3):
        t=k*math.tau/3;a.between('Clasp',(.35*math.cos(t),.35*math.sin(t),.10),(.30*math.cos(t),.30*math.sin(t),.52),.07,'equipment_gold',vertices=5)
    return a.finish()

BUILDERS={'meteor/meteor_core':meteor_core,'meteor/ore_chunk':ore_chunk,'items/bar_stack':bar_stack,'items/coin':coin,'items/core_shard':core_shard}
for v in 'abcd':BUILDERS['meteor/node_piece_'+v]=lambda v=v:node(v)
for k in ORE:
    BUILDERS['items/ore_'+k]=lambda k=k:ore(k)
    BUILDERS['items/bar_'+k]=lambda k=k:bar(k)

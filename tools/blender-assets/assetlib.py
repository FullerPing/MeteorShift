"""Deterministic low-poly authoring, isolated exports and import metadata."""
import bpy, bmesh, math, json, random
from pathlib import Path
from mathutils import Vector, Matrix
from collections import defaultdict

ROOT = Path('Z:/final-final-actual-final/MeteorShift/blender')
ROOT.mkdir(exist_ok=True)
RAMPS = dict(zip('orange red blue navy pink violet gold green teal frost stone wood cream sulfur rust'.split(), [
 ['FFB24A','FA8028','BA4E1A'],['FF7068','E8403A','A02228'],['6CB8FF','2E80F0','1C4AA8'],
 ['465882','283456','161E36'],['FFB0E2','FA78C8','C44696'],['CE9CFF','A462F6','6C38BA'],
 ['FFE66E','FFC428','CE8C14'],['8CE262','58C440','308C34'],['78ECDE','2CC8BE','148A8C'],
 ['DCF8FF','96DEFF','54A8DE'],['C8CEDC','96A0B4','626C84'],['D6985C','A86C3E','70462A'],
 ['FFFAE8','FFECC4','DEC496'],['FAF078','DEC83C','968022'],['D67C54','AA5638','703626']]))
SINGLES = dict(zip('white ink glass warm_glow equipment_dark steel light_steel equipment_gold cyan'.split(),
 ['FCFCFF','1C2034','A8E2FF','FFD678','1D2533','859CB1','E3F1F9','FFC95C','6DEFFF']))
SINGLES.update(dict(zip('Common Uncommon Rare Epic Legendary Premium'.split(),['B0BAC6','78DC8C','5AAAFF','BE78FF','FFBE3C','FF6EBE'])))
SWATCHFILE=ROOT/'palette-swatches.json'
SWATCHES=json.loads(SWATCHFILE.read_text()) if SWATCHFILE.exists() else list(dict.fromkeys(sum(RAMPS.values(),[])+list(SINGLES.values())))

def rgba(h):
    h=h.lstrip('#'); vals=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals)+(1,)

def colors(c):
    if c in RAMPS:return RAMPS[c]
    return [SINGLES.get(c,c).lstrip('#').upper()]*3

def palette_image():
    im=bpy.data.images.get('CraterworksPalette')
    if not im: im=bpy.data.images.new('CraterworksPalette',width=256,height=256,alpha=True)
    # Raw image pixels are sRGB values; shader image node decodes them.
    px=[0.0]*(256*256*4)
    for y in range(256):
        for x in range(256):
            idx=(y//16)*16+x//16
            h=SWATCHES[idx] if idx<len(SWATCHES) else 'FCFCFF'
            off=(y*256+x)*4
            px[off:off+4]=[int(h[k:k+2],16)/255 for k in (0,2,4)]+[1]
    im.pixels.foreach_set(px); im.filepath_raw=str(ROOT/'palette.png')
    im.file_format='PNG'; im.save()
    pending=SWATCHFILE.with_suffix('.pending')
    pending.write_text(json.dumps(SWATCHES,indent=2)); pending.replace(SWATCHFILE)
    return im

def mat(c,mode):
    hs=colors(c); key='CW_'+mode+'_'+hs[1]
    m=bpy.data.materials.get(key)
    if m:return m
    for h in hs:
        if h not in SWATCHES: SWATCHES.append(h)
    assert len(SWATCHES)<=256,'palette capacity exceeded'
    m=bpy.data.materials.new(key); m.use_nodes=True
    m.diffuse_color=rgba(hs[1]); m['Mode']=mode; m['Ramp']=hs
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=rgba(hs[1]); p.inputs['Roughness'].default_value=.82
    p.inputs['Specular IOR Level'].default_value=.18
    if mode=='palette':
        n=m.node_tree.nodes.new('ShaderNodeTexImage'); n.image=bpy.data.images.get('CraterworksPalette') or palette_image()
        interp=[i.identifier for i in n.bl_rna.properties['interpolation'].enum_items]
        n.interpolation=next(v for v in interp if v=='Closest')
        m.node_tree.links.new(n.outputs['Color'],p.inputs['Base Color'])
    elif mode=='neon':
        p.inputs['Emission Color'].default_value=rgba(hs[1]); p.inputs['Emission Strength'].default_value=.75
    return m

class Asset:
    def __init__(self,ident,budget=3000,pivot=(0,0,0)):
        # A repeat build replaces only this pipeline's previous version of this asset.
        for old in list(bpy.data.scenes):
            if old.get('AssetID')==ident:
                for obj in list(old.objects):bpy.data.objects.remove(obj,do_unlink=True)
                bpy.data.scenes.remove(old)
        self.id=ident; self.budget=budget; self.pivot=Vector(pivot); self.groups=defaultdict(list)
        self.joints={}; self.hidden_groups=set(); self.meta={}; self.scene=bpy.data.scenes.new('CW_'+ident.replace('/','_'))
        bpy.context.window.scene=self.scene
        self.scene.unit_settings.scale_length=1
        self.scene['AssetID']=ident
    def add(self,o,g,c,mode):
        o.name=self.id.replace('/','_')+'__'+g
        o.data.materials.append(mat(c,mode)); self.groups[g].append(o)
        return o
    def bevel(self,o,width):
        if width:
            m=o.modifiers.new('Rounded cartoon edges','BEVEL'); m.width=width; m.segments=2
        return o
    def box(self,group,loc,size,color='stone',bevel=.08,mode='palette',rot=None):
        bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.scale=size
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        if rot:o.rotation_euler=rot
        self.bevel(o,bevel); return self.add(o,group,color,mode)
    def ellipsoid(self,group,loc,size,color='stone',mode='palette',segments=12,rings=8):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=loc)
        o=bpy.context.object; o.scale=tuple(v/2 for v in size)
        return self.add(o,group,color,mode)
    def ico(self,group,loc,size,color='stone',mode='palette',subdivisions=1,seed=0):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions,radius=1,location=loc)
        o=bpy.context.object; rng=random.Random(seed)
        for v in o.data.vertices:v.co*=rng.uniform(.90,1.08)
        for axis in range(3):
            lo=min(v.co[axis] for v in o.data.vertices); hi=max(v.co[axis] for v in o.data.vertices)
            for v in o.data.vertices:v.co[axis]=(v.co[axis]-(lo+hi)/2)/(hi-lo)*size[axis]
        return self.add(o,group,color,mode)
    def cylinder(self,group,loc,radius,depth,color='steel',mode='palette',vertices=12,radius2=None,rot=None):
        bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=radius,radius2=radius if radius2 is None else radius2,depth=depth,location=loc)
        o=bpy.context.object
        if rot:o.rotation_euler=rot
        return self.add(o,group,color,mode)
    def between(self,group,start,end,radius,color='steel',mode='palette',vertices=8,radius2=None):
        d=Vector(end)-Vector(start); o=self.cylinder(group,(Vector(start)+Vector(end))/2,radius,d.length,color,mode,vertices,radius2)
        o.rotation_euler=d.to_track_quat('Z','Y').to_euler(); return o
    def mesh(self,group,verts,faces,color='stone',mode='palette',bevel=0):
        me=bpy.data.meshes.new(group); me.from_pydata(verts,[],faces); me.update()
        bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
        o=bpy.data.objects.new(group,me); self.scene.collection.objects.link(o)
        self.bevel(o,bevel); return self.add(o,group,color,mode)
    def poly(self,group,points,depth,color='steel',mode='palette',bevel=.025):
        n=len(points); verts=[(x,y,z) for y in (-depth/2,depth/2) for x,z in points]
        faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        return self.mesh(group,verts,faces,color,mode,bevel)
    def ring(self,group,loc,radius,tube,color='gold',mode='palette',axis='Y',segments=24,sides=6):
        verts=[]; faces=[]
        for i in range(segments):
            t=math.tau*i/segments
            for j in range(sides):
                q=math.tau*j/sides; p=Vector(((radius+tube*math.cos(q))*math.cos(t),(radius+tube*math.cos(q))*math.sin(t),tube*math.sin(q)))
                if axis=='Y':p=Vector((p.x,p.z,p.y))
                elif axis=='X':p=Vector((p.z,p.x,p.y))
                verts.append(Vector(loc)+p)
        for i in range(segments):
            for j in range(sides):faces.append((i*sides+j,((i+1)%segments)*sides+j,((i+1)%segments)*sides+(j+1)%sides,i*sides+(j+1)%sides))
        return self.mesh(group,verts,faces,color,mode)
    def tube(self,group,points,radius,color='cyan',mode='neon',sides=6):
        verts=[]; faces=[]
        for i,p in enumerate(points):
            tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
            q=tangent.to_track_quat('Z','Y')
            for j in range(sides):verts.append(Vector(p)+q@Vector((radius*math.cos(j*math.tau/sides),radius*math.sin(j*math.tau/sides),0)))
        faces=[tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))]
        for i in range(len(points)-1):
            for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
        return self.mesh(group,verts,faces,color,mode)
    def empty(self,name,loc,normal=None):
        o=bpy.data.objects.new(name,None); self.scene.collection.objects.link(o); o.location=loc; o['RobloxName']=name
        if normal:o.rotation_euler=Vector(normal).to_track_quat('Z','Y').to_euler()
        return o
    def joint(self,group,position):self.joints[group]=Vector(position)
    def hidden(self,group):self.hidden_groups.add(group)
    def finish(self):
        bpy.context.window.scene=self.scene; out=[]
        for group,parts in self.groups.items():
            bpy.ops.object.select_all(action='DESELECT')
            for o in parts:
                o.select_set(True); bpy.context.view_layer.objects.active=o
                for modifier in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
            bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join(); o=bpy.context.object
            bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
            bm=bmesh.new(); bm.from_mesh(o.data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bmesh.ops.triangulate(bm,faces=list(bm.faces)); bm.to_mesh(o.data); bm.free()
            for layer in list(o.data.uv_layers):o.data.uv_layers.remove(layer)
            uv=o.data.uv_layers.new(name='Palette')
            for p in o.data.polygons:
                m=o.data.materials[p.material_index]; ramp=m['Ramp']; h=ramp[0 if p.normal.z>.45 else 2 if p.normal.z<-.25 else 1]
                idx=SWATCHES.index(h)
                for li in p.loop_indices:uv.data[li].uv=((idx%16+.5)/16,(idx//16+.5)/16)
                p.use_smooth=False
            if all(m.get('Mode')!='palette' for m in o.data.materials):o.data.uv_layers.remove(uv)
            pivot=self.joints.get(group,self.pivot)
            o.data.transform(Matrix.Translation(-pivot)); o.location=pivot
            o.name=group; o['RobloxName']=group.split('.')[0]; o['AssetID']=self.id
            modes=set(m.get('Mode') for m in o.data.materials)
            if 'tint' in modes or group in ('Vein','OreFleck'):o['RuntimeTint']=True
            if 'neon' in modes:o['RobloxMaterial']='Neon'
            if group in self.joints:o['AnimationGroup']=self.meta.get('animation_groups',{}).get(group,group.split('.')[0]); o['AnimationPivot']=list(pivot)
            if group in self.hidden_groups:o['HiddenWorkProp']=True
            out.append(o)
        bpy.context.view_layer.update()
        allpts=[o.matrix_world@v.co for o in out for v in o.data.vertices]
        lo=Vector([min(p[j] for p in allpts) for j in range(3)]); hi=Vector([max(p[j] for p in allpts) for j in range(3)])
        tris=sum(len(o.data.polygons) for o in out)
        assert tris<=self.budget,f'{self.id}: {tris} > {self.budget} triangles'
        path=ROOT/self.id; path.parent.mkdir(parents=True,exist_ok=True); palette_image()
        report={'id':self.id,'triangles':tris,'budget':self.budget,'dimensions_blender':list(hi-lo),'bounds':[list(lo),list(hi)],'pivot':list(self.pivot),'objects':[],'metadata':self.meta}
        for o in out:
            item={'name':o.name,'roblox_name':o['RobloxName'],'triangles':len(o.data.polygons),'origin':list(o.location),'runtime_tint':bool(o.get('RuntimeTint')),'neon':o.get('RobloxMaterial')=='Neon','work_prop':bool(o.get('HiddenWorkProp'))}
            if o.get('AnimationGroup'):item['animation_group']=o['AnimationGroup'];item['animation_pivot']=list(o['AnimationPivot'])
            report['objects'].append(item)
        # Tint export is neutral. Preview colors are restored only after FBX serialization.
        tinted=[]
        for o in out:
            for m in o.data.materials:
                if (m.get('Mode')=='tint' or o.get('RuntimeTint')) and m not in [x[0] for x in tinted]:
                    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'); tinted.append((m,tuple(p.inputs['Base Color'].default_value)))
                    p.inputs['Base Color'].default_value=rgba('FCFCFF'); m.diffuse_color=rgba('FCFCFF')
        bpy.ops.object.select_all(action='DESELECT')
        for o in list(self.scene.objects):
            if o.type in ('MESH','EMPTY'):o.select_set(True)
        bpy.ops.export_scene.fbx(filepath=str(path.with_suffix('.fbx')),use_selection=True,object_types={'MESH','EMPTY'},use_mesh_modifiers=True,mesh_smooth_type='OFF',use_triangles=True,bake_anim=False,axis_forward='-Z',axis_up='Y',bake_space_transform=True,apply_scale_options='FBX_SCALE_ALL',add_leaf_bones=False,use_custom_props=True,path_mode='RELATIVE')
        report['attachments']=[{'name':o.get('RobloxName',o.name),'position':list(o.location),'normal':list(o.rotation_euler.to_matrix()@Vector((0,0,1)))} for o in self.scene.objects if o.type=='EMPTY']
        for o in out:
            if o.get('HiddenWorkProp'):o.hide_render=True
        self.setup_preview(lo,hi)
        self.scene.render.filepath=str(path.with_suffix('.png'))
        # Saving only this scene avoids carrying the user's original scene or earlier assets.
        bpy.data.libraries.write(str(path.with_suffix('.blend')),{self.scene},path_remap='RELATIVE_ALL',fake_user=True,compress=True)
        path.with_suffix('.json').write_text(json.dumps(report,indent=2))
        for m,c in tinted:
            p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'); p.inputs['Base Color'].default_value=c; m.diffuse_color=c
        bpy.ops.render.render(write_still=True)
        for o in self.scene.objects:o.name=self.id.replace('/','_')+'__'+o.name
        print('ASSET_DONE '+self.id+' '+str(tris)+' triangles')
        return report
    def setup_preview(self,lo,hi):
        s=self.scene; center=(lo+hi)/2; size=max(hi-lo)
        c=bpy.data.cameras.new('PreviewCamera'); o=bpy.data.objects.new('PreviewCamera',c); s.collection.objects.link(o)
        o.location=center+Vector((.95,-1.8,1.05))*size; o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
        c.type='ORTHO'; c.ortho_scale=size*1.5; s.camera=o
        for name,off,power,r in [('Key',(-3,-4,6),450,4),('Fill',(4,-2,3),180,5),('Rim',(1,4,5),550,3)]:
            l=bpy.data.lights.new(name,'AREA'); ob=bpy.data.objects.new(name,l); s.collection.objects.link(ob)
            ob.location=center+Vector(off)*size/3; l.energy=power*(size/3)**2; l.shape='DISK'; l.size=r*size/3
            ob.rotation_euler=(center-ob.location).to_track_quat('-Z','Y').to_euler()
        s.world=bpy.data.worlds.new('Studio'); s.world.use_nodes=True
        bg=next(n for n in s.world.node_tree.nodes if n.type=='BACKGROUND'); bg.inputs['Color'].default_value=(.35,.4,.5,1); bg.inputs['Strength'].default_value=.6
        s.render.resolution_x=512; s.render.resolution_y=512; s.render.resolution_percentage=100; s.render.film_transparent=True
        formats=[i.identifier for i in s.render.image_settings.bl_rna.properties['file_format'].enum_items]; s.render.image_settings.file_format=next(x for x in formats if x=='PNG')
        s.render.image_settings.color_mode='RGBA'
        try:s.render.engine='BLENDER_EEVEE'
        except TypeError:pass
        opts=[i.identifier for i in s.view_settings.bl_rna.properties['view_transform'].enum_items]
        if 'Standard' in opts:s.view_settings.view_transform='Standard'

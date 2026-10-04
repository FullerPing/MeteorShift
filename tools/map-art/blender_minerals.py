"""Original faceted mineral points. Preserve every existing Blender scene."""
import bpy, bmesh, math, random, json
from pathlib import Path
root = Path(r'Z:\final-final-actual-final\MeteorShift\assets\map-art\geology')
root.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes.get('MeteorShiftGeologyWorkshop') or bpy.data.scenes.new('MeteorShiftGeologyWorkshop')
bpy.context.window.scene = scene
export = {}
colors = [(0.57, .43, .28, 1), (.32, .72, .80, 1), (.68, .42, .83, 1)]
for index, name in enumerate(['IronNodule', 'QuartzPoint', 'SplitCrystal']):
    old = bpy.data.objects.get(name)
    if old:
        assert old.get('MeteorShiftGeologyOwned')
        bpy.data.objects.remove(old, do_unlink=True)
    rng = random.Random(10821 + index)
    sides = [7, 6, 5][index]
    vertices = []
    for ring, (height, radius) in enumerate([(0, .65), (.25, 1), (.68, .80)]):
        for k in range(sides):
            a = 2*math.pi*k/sides + ring*.09
            r = radius*rng.uniform(.84, 1.1)
            vertices.append((r*math.cos(a), r*math.sin(a)*.85, height+rng.uniform(-.035,.035)))
    vertices.append((.12*(index-1), -.07, [1.0,1.5,1.25][index]))
    mesh = bpy.data.meshes.new(name+'Geometry')
    mesh.from_pydata(vertices, [], [])
    bm = bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.convex_hull(bm, input=list(bm.verts), use_existing_faces=False)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh); bm.free(); mesh.update()
    obj = bpy.data.objects.new(name, mesh); scene.collection.objects.link(obj)
    obj['MeteorShiftGeologyOwned'] = True; obj.location = (index*3.5,0,0)
    mat = bpy.data.materials.get(name+'Material') or bpy.data.materials.new(name+'Material')
    mat.use_nodes=True; mat.diffuse_color=colors[index]
    shader = next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    shader.inputs['Base Color'].default_value=colors[index]; shader.inputs['Roughness'].default_value=.62
    obj.data.materials.clear(); obj.data.materials.append(mat)
    vs = [tuple(v.co) for v in mesh.vertices]
    lo=[min(v[i] for v in vs) for i in range(3)]; hi=[max(v[i] for v in vs) for i in range(3)]
    norm=[[(v[i]-(lo[i]+hi[i])/2)/(hi[i]-lo[i]) for i in range(3)] for v in vs]
    normalized=[[round(v[0],6),round(v[2],6),round(-v[1],6)] for v in norm]
    faces=[[j+1 for j in p.vertices] for p in mesh.polygons]
    export[name]={'vertices':normalized,'faces':faces}
    lines=['# Original MeteorShift mineral, Y-up']
    lines += ['v '+' '.join(map(str,v)) for v in normalized]
    lines += ['f '+' '.join(map(str,f)) for f in faces]
    (root/(name+'.obj')).write_text('\n'.join(lines)+'\n')
(root/'mineral-geometry.json').write_text(json.dumps(export,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(root/'MeteorShift-geology-workshop.blend'),copy=True)
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        for space in area.spaces:
            if space.type=='VIEW_3D':
                space.region_3d.view_location=(3.5,0,.5); space.region_3d.view_distance=12
print(json.dumps({n:{'vertices':len(d['vertices']),'triangles':len(d['faces'])} for n,d in export.items()}))

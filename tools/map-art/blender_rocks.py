"""Author small, flat-shaded stone variants in a separate Blender workshop scene.

Execute through Blender MCP. The original scene and objects are retained.
Mesh data is exported with Roblox's Y-up coordinate convention; no textures,
external models, or asset publication are needed.
"""
import bpy
import bmesh
import json
import math
import random
from pathlib import Path
from mathutils import Quaternion

root = Path('Z:/final-final-actual-final/MeteorShift/assets/map-art')
root.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes.get('MeteorShiftRockWorkshop')
if scene is None:
    scene = bpy.data.scenes.new('MeteorShiftRockWorkshop')
bpy.context.window.scene = scene
collection = bpy.data.collections.get('MeteorShiftStoneVariants')
if collection is None:
    collection = bpy.data.collections.new('MeteorShiftStoneVariants')
    scene.collection.children.link(collection)

palette = [(0.25, 0.23, 0.21, 1), (0.40, 0.37, 0.31, 1), (0.30, 0.31, 0.28, 1)]
materials = []
for i, rgba in enumerate(palette):
    mat = bpy.data.materials.get(f'MeteorShiftStone_{i}') or bpy.data.materials.new(f'MeteorShiftStone_{i}')
    mat.diffuse_color = rgba
    mat.use_nodes = True
    node = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value = rgba
    node.inputs['Roughness'].default_value = 0.92
    materials.append(mat)

export = {}
for variant, name in enumerate(['FracturedBasalt', 'LayeredTalus', 'WeatheredBoulder']):
    existing = bpy.data.objects.get(name)
    if existing is not None:
        assert existing.get('MeteorShiftOwned'), f'Refusing to overwrite {name}'
        bpy.data.objects.remove(existing, do_unlink=True)
    rng = random.Random(771 + variant)
    verts, faces = [], []
    sides = 9
    # Four offset rings give broad facets, a chipped crown, and a stable foot.
    for ring, (height, radius) in enumerate([(0, .78), (.20, 1), (.72, .86), (1, .48)]):
        for k in range(sides):
            angle = 2 * math.pi * k / sides + ring * .11
            r = radius * rng.uniform(.88, 1.10)
            verts.append((math.cos(angle) * r, math.sin(angle) * r * .82,
                          height + (rng.uniform(-.055, .055) if ring not in (0, 3) else 0)))
    faces.append(tuple(reversed(range(sides))))
    for ring in range(3):
        for k in range(sides):
            n = (k + 1) % sides
            faces.append((ring * sides + k, ring * sides + n,
                          (ring + 1) * sides + n, (ring + 1) * sides + k))
    faces.append(tuple(3 * sides + k for k in range(sides)))
    mesh = bpy.data.meshes.new(name + 'Mesh')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj['MeteorShiftOwned'] = True
    collection.objects.link(obj)
    obj.location = (variant * 3.1, 0, 0)
    for mat in materials:
        mesh.materials.append(mat)
    for poly in mesh.polygons:
        poly.use_smooth = False
        poly.material_index = (poly.index // 7 + variant) % 3
    # Normalize the geometry around zero for direct scaling to saved Roblox parts.
    lo = [min(v.co[j] for v in mesh.vertices) for j in range(3)]
    hi = [max(v.co[j] for v in mesh.vertices) for j in range(3)]
    data = []
    for v in mesh.vertices:
        xyz = [(v.co[j] - (lo[j] + hi[j]) / 2) / (hi[j] - lo[j]) for j in range(3)]
        data.append([round(xyz[0], 6), round(xyz[2], 6), round(-xyz[1], 6)])
    export[name] = {'vertices': data, 'faces': [[i + 1 for i in p.vertices] for p in mesh.polygons]}
    # OBJ uses Roblox coordinates too, making it useful for conventional importing.
    lines = [f'o {name}'] + ['v ' + ' '.join(map(str, v)) for v in data]
    lines += ['f ' + ' '.join(map(str, f)) for f in export[name]['faces']]
    (root / (name + '.obj')).write_text('\n'.join(lines) + '\n', encoding='utf-8')

(root / 'stone-geometry.json').write_text(json.dumps(export, indent=2), encoding='utf-8')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            view = area.spaces.active.region_3d
            view.view_location = (3.1, 0, .45)
            view.view_distance = 10
            view.view_rotation = Quaternion((.88, .28, .12, .35)).normalized()
            shading = area.spaces.active.shading
            valid = [v.identifier for v in shading.bl_rna.properties['color_type'].enum_items]
            if 'MATERIAL' in valid:
                shading.color_type = 'MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(root / 'MeteorShift-stone-workshop.blend'), copy=True)
print(json.dumps({'variants': list(export), 'triangles': {n: len(d['faces']) for n, d in export.items()}, 'directory': str(root)}))

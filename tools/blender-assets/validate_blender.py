"""Re-import every delivery FBX into temporary scenes and verify the actual files."""
import bpy, json, math, struct
from pathlib import Path
from mathutils import Vector
ROOT=Path('Z:/final-final-actual-final/MeteorShift/blender')

def validate(expected_count=115):
    previous=bpy.context.window.scene
    reports=[json.loads(p.read_text()) for folder in ['equipment','pets','eggs','meteor','items','rocks','map','props'] for p in (ROOT/folder).rglob('*.json')]
    assert len(reports)==expected_count, f'Expected {expected_count} asset reports, found {len(reports)}'
    assert len({r['id'] for r in reports})==expected_count, 'Duplicate asset IDs'
    errors=[]; checked=[]
    for r in reports:
        ident=r['id']; path=ROOT/ident; problems=[]
        for suffix in ['.blend','.fbx','.png']:
            if not path.with_suffix(suffix).exists():problems.append('Missing '+suffix)
        png=path.with_suffix('.png').read_bytes()
        w,h,depth,ctype=struct.unpack('>IIBB',png[16:26])
        if (w,h,ctype)!=(512,512,6):problems.append(f'PNG format {w}x{h} type{ctype}')
        scene=bpy.data.scenes.new('CW_FBX_validation');bpy.context.window.scene=scene
        try:
            bpy.ops.import_scene.fbx(filepath=str(path.with_suffix('.fbx')),use_custom_props=True)
            meshes=[o for o in scene.objects if o.type=='MESH']; empties=[o for o in scene.objects if o.type=='EMPTY']
            bpy.context.view_layer.update()
            triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
            if triangles!=r['triangles']:problems.append(f'Triangle mismatch {triangles}!={r["triangles"]}')
            if triangles>r['budget']:problems.append('Over budget')
            if len(meshes)!=len(r['objects']):problems.append('Mesh count mismatch')
            actual_names=sorted(o.get('RobloxName',o.name.split('.')[0]) for o in meshes)
            expected_names=sorted(o['roblox_name'] for o in r['objects'])
            if actual_names!=expected_names:problems.append('Object names mismatch')
            points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
            lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)])
            # FBX coordinates are Y-up. Blender importer reverses the axis conversion.
            dim=hi-lo
            if any(abs(dim[j]-r['dimensions_blender'][j])>.01 for j in range(3)):problems.append('Round-trip dimensions changed')
            for o in meshes:
                if any(abs(s-1)>.001 for s in o.scale):problems.append(o.name+': unapplied scale')
                textured=any(n.type=='TEX_IMAGE' for m in o.data.materials if m.use_nodes for n in m.node_tree.nodes)
                if o.get('RuntimeTint') and textured:problems.append(o.name+': tint has texture')
                if o.get('RobloxMaterial')=='Neon' and textured:problems.append(o.name+': neon has texture')
                if textured:
                    if len(o.data.uv_layers)!=1:problems.append(o.name+': palette UV layer count')
                    else:
                        uv=o.data.uv_layers.active
                        for p in o.data.polygons:
                            coords=[uv.data[k].uv for k in p.loop_indices]
                            if any((c-coords[0]).length>.00001 for c in coords):problems.append(o.name+': face UVs not collapsed');break
                if o.get('RuntimeTint'):
                    for m in o.data.materials:
                        p=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None) if m.use_nodes else None
                        if p and min(p.inputs['Base Color'].default_value[:3])<.90:problems.append(o.name+': tint export not neutral')
            if ident=='meteor/meteor_core':
                if len(empties)!=36:problems.append('Expected 36 node slots')
                for o in empties:
                    if o.get('RobloxName')!='NodeSlot':problems.append('Attachment name lost')
            if ident.startswith('rocks/') and (dim.x>8.001 or dim.y>8.001):problems.append('Rock footprint exceeds 8 studs')
            if ident.startswith('props/') and len(meshes)>2:problems.append('Repeated prop exceeds two mesh objects')
            if ident.startswith('meteor/minerals/'):
                maximum=2 if ident.split('/')[-1] in ('starfallIron','heartOfWinter','voidDiamond') else 1
                if len(meshes)>maximum:problems.append('Mineral exceeds required object count')
                if max(dim)>1.8:problems.append('Mineral exceeds approximately 1.5 stud size')
            checked.append({'id':ident,'triangles':triangles,'dimensions':list(dim),'mesh_count':len(meshes),'errors':problems})
        except Exception as e:
            problems.append(str(e));checked.append({'id':ident,'errors':problems})
        finally:
            for o in list(scene.objects):bpy.data.objects.remove(o,do_unlink=True)
            bpy.context.window.scene=previous;bpy.data.scenes.remove(scene)
        errors.extend(ident+': '+e for e in problems)
    result={'assets':len(reports),'passed':len(reports)-sum(bool(c['errors']) for c in checked),'errors':errors,'checks':checked,'scope':'FBX round-trip, budgets, mesh names, palette UVs, neutral tint, PNG format, slots, rock footprints. Roblox Studio integration not tested.'}
    (ROOT/'validation.json').write_text(json.dumps(result,indent=2))
    (ROOT/'manifest.json').write_text(json.dumps({r['id']:r for r in reports},indent=2))
    print(json.dumps({'assets':len(reports),'errors':errors,'max_triangles':max(r['triangles'] for r in reports)}))
    return result

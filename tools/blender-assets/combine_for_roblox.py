# Packs the delivered FBX files into a few import-ready FBX files for Roblox Studio's 3D Importer,
# so the owner imports once per group instead of 100+ times. Each asset becomes one Empty named
# "<group>__<asset>" holding its meshes; the importer turns that into a Model per asset. Each mesh is
# renamed "<holder>#<i>", i = its index in the asset JSON's "objects", so the Studio-side
# tools/blender-assets/RobloxImport.luau can restore names, tint, Neon and pivots from the JSON.
# NodeSlot empties are dropped: the Studio script rebuilds them as Attachments from the JSON.
#
#   blender -b --factory-startup -P tools/blender-assets/combine_for_roblox.py
#
# Output: blender/roblox-import/<bundle>.fbx (palette texture embedded).

import bpy, json, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2] / 'blender'
OUT = ROOT / 'roblox-import'
BUNDLES = {
    'equipment': ['equipment'],
    'pets': ['pets'],
    'world': ['eggs', 'items', 'meteor', 'rocks', 'map'],
    'optional': ['props', 'meteor/minerals'],
}


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def files_for(folder):
    return sorted((ROOT / folder).glob('*.fbx'))


def add_asset(path, group):
    info = json.loads(path.with_suffix('.json').read_text())
    index = {o['name']: i for i, o in enumerate(info['objects'])}
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(path), use_custom_props=True)
    new = [o for o in bpy.data.objects if o not in before]
    name = f'{group}__{path.stem}'
    holder = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(holder)
    meshes = 0
    for o in new:
        if o.type != 'MESH':
            bpy.data.objects.remove(o)
            continue
        if o.name not in index:
            raise RuntimeError(f'{path}: mesh {o.name} is not in its JSON')
        world = o.matrix_world.copy()
        o.parent = holder
        o.matrix_world = world
        o.name = f'{name}#{index[o.name]}'
        meshes += 1
    if meshes != len(info['objects']):
        raise RuntimeError(f'{path}: {meshes} meshes, JSON lists {len(info["objects"])}')
    return meshes


def main():
    OUT.mkdir(exist_ok=True)
    report = {}
    for bundle, folders in BUNDLES.items():
        clear()
        meshes, assets = 0, []
        for folder in folders:
            group = folder.replace('/', '_')
            for path in files_for(folder):
                meshes += add_asset(path, group)
                assets.append(f'{group}__{path.stem}')
        if not assets:
            continue
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.export_scene.fbx(
            filepath=str(OUT / f'{bundle}.fbx'), use_selection=True, object_types={'MESH', 'EMPTY'},
            mesh_smooth_type='OFF', use_triangles=True, bake_anim=False, axis_forward='-Z', axis_up='Y',
            bake_space_transform=True, apply_scale_options='FBX_SCALE_ALL', add_leaf_bones=False,
            use_custom_props=True, path_mode='COPY', embed_textures=True)
        report[bundle] = {'assets': assets, 'meshes': meshes}
        print('BUNDLE_DONE', bundle, len(assets), 'assets', meshes, 'meshes')
    (OUT / 'bundles.json').write_text(json.dumps(report, indent=2))


main()

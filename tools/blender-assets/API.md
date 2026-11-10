# Asset authoring API

Use `from assetlib import *`. Files run inside Blender 5.2 through the parent agent only. Do not call Blender tools from delegated authoring tasks.

`a = Asset('equipment/pickaxe_t1', budget=3000, pivot=(0,0,0))` creates an isolated scene. Coordinates are Blender Z up, front -Y. Author the entire asset relative to its specified pivot. `a.finish()` merges components by group, applies modifiers, adds palette UVs, exports FBX and .blend, renders PNG and records validation. Each builder must create one asset per callable function; expose `BUILDERS` mapping relative asset IDs to zero-argument builder functions. Do not auto-execute.

Each geometry function returns an object, appends it to a named merge group, and accepts `group`, `color` (palette ramp name or hex), and `mode` (`palette` default, `tint`, `neon`). Tint/neon materials contain no texture; `color` is preview-only for tint (finish exports neutral). Use mode='neon' for glowing pieces, names per brief. Group can repeat to merge pieces. Use group='Tail.001' etc where pieces must remain separate.

- `a.box(group, loc, size, color='stone', bevel=0.08, mode='palette', rot=None)` bevelled cube, 2 segments. rot Euler radians.
- `a.ellipsoid(group, loc, size, color='stone', mode='palette', segments=12, rings=8)` size is full XYZ extent.
- `a.ico(group, loc, size, color='stone', mode='palette', subdivisions=1, seed=0)` lumpy ico, full XYZ extent.
- `a.cylinder(group, loc, radius, depth, color='steel', mode='palette', vertices=12, radius2=None, rot=None)` cone if radius2 provided; along Z, rotate as required.
- `a.between(group, start, end, radius, color='steel', mode='palette', vertices=8, radius2=None)` tapered rod between points.
- `a.ring(group, loc, radius, tube, color='gold', mode='palette', axis='Y', segments=24, sides=6)` torus, normal along named axis.
- `a.poly(group, points, depth, color='steel', mode='palette', bevel=0.025)` extruded XZ silhouette, depth along Y, centred Y=0. Translate returned object as needed.
- `a.mesh(group, verts, faces, color='stone', mode='palette', bevel=0)` custom mesh, recalculates normals.
- `a.tube(group, points, radius, color='cyan', mode='neon', sides=6)` polyline tube.
- `a.empty(name, loc, normal=None)` attachment; normal local +Z faces outward.
- `a.joint(group, position)` sets mesh origin for animated group; records AnimationPivot and AnimationGroup.
- `a.hidden(group)` hides working prop in previews only; records HiddenWorkProp for import.
- `a.meta` dictionary holds asset metadata.

Palette names: orange red blue navy pink violet gold green teal frost stone wood cream sulfur rust; singles white ink glass warm_glow equipment_dark steel light_steel equipment_gold cyan. Any hex is appended as a swatch to the shared 256px palette. Keep moderate triangle counts (box bevel ~108 triangles, ellipsoid ~168, ring ~288). Use fewer ring sides/segments where needed. Custom polygon shapes support concave polygons (triangulated at export).

No more than 3,000 triangles equipment, 5,000 pets, 2,000 eggs, 1,500 rocks, 8,000 heroes. Meshes must be modeled specifically to descriptions, not generic recolors. All required objects and identifying details matter. No game code or unrelated files should be changed.

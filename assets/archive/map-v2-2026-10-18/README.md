# Map v2, archived 18 October 2026

This is the live map just before the Caldera v2 redesign: map v2 with the 15 October crater polish. It is 540 × 540, and the WorldGeometry is as of commit `f9fd1b8`.

| File | What | Check |
|---|---|---|
| `Map.rbxm` | `Workspace.Map` (root renamed back to `Map`), 3,659 parts, 4,945 descendants, no scripts | sha256 `f848335974222649d38756981bcfede31efb1701747fac18b8cda4a6631e7705` |
| `Lighting.rbxm` | Folder `Lighting_v8` holding the 6 Lighting children (Atmosphere, Bloom, Grade, ...). The Lighting properties are stored as attributes on the folder. | sha256 `2779eec2e1d7fc7c471fae185904240002152226ae284c381d4d6f68b422c4b2` |

Both files were read back in Studio with `SerializationService:DeserializeInstancesAsync`, and the counts matched.

There is no terrain file because the place has no terrain (`Terrain:CountCells() == 0`). The mountains are parts in `Map.Backdrop`.

The same copies are also kept in the place as `ServerStorage.SwapRollback.Map_v8` and `Lighting_v8`. They only last if the place is saved.

**To restore:** move the new `Workspace.Map` out, insert `Map.rbxm` (Studio: right-click Workspace, Insert from File), then check out `src/shared/WorldGeometry.luau` from `f9fd1b8` so the code matches the map again.

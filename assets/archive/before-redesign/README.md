# Before-redesign backups

The four files in this directory are exact copies of the repository exports at HEAD `9e66f0a`.

`studio-snapshot/` contains fresher binary Roblox model files captured from the actual Studio Edit session on 5 October 2026, place 113476105600560. Each serialized buffer was deserialized successfully by Roblox before transfer. `studio-snapshot/manifest.json` records the transferred file sizes and SHA256 hashes.

The Terrain archive is a TerrainRegion captured from voxel corner (-256,-64,-256) through (256,128,256), with `RestoreCorner` stored on the instance. Restore using Terrain:PasteRegion(region, Vector3int16.new(-256,-64,-256), true). The Lighting archive is a Folder containing effects and Clouds; Lighting properties are attributes on that Folder. Restore Clouds to Terrain and the other effects to Lighting, then restore the stored properties.

These backups do not prove the open place was saved. No publishing was performed.

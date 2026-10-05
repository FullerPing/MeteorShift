# Staged geometry checkpoint

This is an incomplete redesign checkpoint, not a replacement for the four final contract assets.

- `Map_Redesign.rbxm`: 1,351 authored parts at offset `(0,0,3000)`. Temporary meteor preview excluded; six spawn pads disabled. No scripts. Live equipment, boundary authority and runtime integration remain pending.
- `ServerAssets_Redesign.rbxm`: 119 parts, Core and all NodePieces scaled exactly2x from the pristine backup, PlotStations removed from this clone. No scripts. Original live Assets remain unchanged.
- `Refinery_Redesign.rbxm`: 134 parts at final pivot `(0,0.8,-380)`, PrimaryPart Foundation, one UsePoint, SharedRefinery true. No scripts/prompts/Humanoids.
- `Lighting_Redesign.rbxm`: inactive daylight profile, six effects and a CloudSettings data Folder. No parts or scripts. The same profile is inside the staged map's Atmosphere model; live Lighting remains unchanged. Clouds must be materialized directly under Terrain during the approved swap.

`manifest.json` records verified bytes, SHA256 and engine serialization round-trips. The staged map, inactive lighting profile and tutorial edit were saved in Edit mode on6October2026; Studio confirmed at00:42:40.976. Unparented scaled Assets remain memory-only, so their binary export is required to restore them after reopening. Nothing was published.

Import only as isolated staging objects. Do not replace Workspace.Map or live ServerStorage.Assets, clear Terrain, enable staged spawns, or publish from this checkpoint. Follow the QA/swap/rollback gates in the plan. The original four exports and full terrain rollback are preserved under `assets/archive/before-redesign/`.

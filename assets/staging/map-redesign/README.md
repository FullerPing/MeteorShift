# Staged geometry checkpoint

This is an incomplete redesign checkpoint, not a replacement for the four final contract assets.

- `Map_Redesign.rbxm`: 1,351 authored parts at offset `(0,0,3000)`. Temporary meteor preview excluded; six spawn pads disabled. No scripts. Live equipment, boundary authority and runtime integration remain pending.
- `ServerAssets_Redesign.rbxm`: 119 parts, Core and all NodePieces scaled exactly2x from the pristine backup, PlotStations removed from this clone. No scripts. Original live Assets remain unchanged.
- `Refinery_Redesign.rbxm`: 134 parts at final pivot `(0,0.8,-380)`, PrimaryPart Foundation, one UsePoint, SharedRefinery true. No scripts/prompts/Humanoids.

`manifest.json` records verified bytes, SHA256 and engine serialization round-trips. These exports preserve the model data even though the place save for this stage is unconfirmed.

Import only as isolated staging objects. Do not replace Workspace.Map or live ServerStorage.Assets, clear Terrain, enable staged spawns, or publish from this checkpoint. Follow the QA/swap/rollback gates in the plan. The original four exports and full terrain rollback are preserved under `assets/archive/before-redesign/`.

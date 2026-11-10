# Map model improvement brief

Inspected the connected `new_AutoRecovery_0.rbxl` in Roblox Studio on October 1, 2026. The user approved this brief and target. The implemented pass is saved separately as `MeteorShift-map-polished.rbxl`; authoring sources and validation notes are in `tools/map-art/README.md`.

## Intended result

Give the existing meteor mining colony more distinctive silhouettes, useful visual landmarks, and convincing construction detail while retaining its circular layout and working mining and production interactions.

## Observed opportunities

- The shop and Trading Post each use a single rectangular body, two roof pieces, a flat door, and a sign. Add structural beams, framed windows, roof trim, awnings, and distinct trade and equipment displays. Keep the Trading Post sell counter accessible.
- The plaza has a small meteor fountain and large bare paving areas. Improve the fountain pedestal and basin, and add deliberately placed seating and planting around the plaza perimeter.
- Roads form a broad ring and radial links. Add restrained edge treatment and route markers so the town, crater, and plot entrances are easier to recognize from player height.
- The crater already has a bowl, irregular rim, and lamps. Add layered scorched rock and mineral accents around its outer edge, leaving entry routes and the meteor mining area clear.
- Twenty plots surround the town. Improve entrance posts, signs, fences, and pad edging while leaving the full production footprint available.
- Trees use three-part silhouettes. Vary canopy shapes, branch placement, and color in coherent clusters. Add small ground details outside circulation routes.
- The production template contains a hopper, conveyor, refinery, and collection shelter. Add bracing, mechanical housings, furnace trim, pipe fittings, and storage detail without obscuring working surfaces.
- Debris and meteor pieces already have ore accents. Improve their shape variation and material contrast while retaining recognizable mineable silhouettes.

## Gameplay contracts to preserve

- `Workspace.Map.Crater.MeteorSpawn` and its placement.
- `Workspace.Map.Plots` with all twenty plot models, `PlotId` attributes, `Pad` transforms, and `Sign.Label.Text` hierarchy.
- `ServerStorage.Assets.PlotStations` pivot: pad top center, with local negative Z toward the crater.
- Hopper `Intake`, conveyor `Belt`, refinery `Furnace`, collection `Bin`, and their upgrade prompts and attachments.
- Trading Post `SellPoint.ProximityPrompt`, spawn access, existing shop interaction, and tutorial target paths.
- Debris root parts and child flecks: the debris service hides all child parts on break and changes their color by tier.
- Meteor core attachments and node-piece roots used by the event assembly.

## Validation for implementation

Capture matching overview and player-height views before and after. Inspect every changed region for intersecting geometry and blocked paths. Compare part counts and keep added decoration anchored, with collision, touch, and query disabled where interaction is unnecessary. Check all gameplay contracts above in Edit mode; then verify plot assignment, production interactions, selling, debris break/respawn, and meteor spawning in Play mode. Save the finished place and refresh the affected model exports when a supported save/export mechanism is available.

## Approval

The user confirmed the recovery place and approved this direction with "yeah", then explicitly authorized continuing after the PC restart and allowed Blender.

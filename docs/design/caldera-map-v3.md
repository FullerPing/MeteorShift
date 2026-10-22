# Map v3 "Caldera Terraces": design

The owner approved this on 18 October 2026, after four competing layouts and a blind grading. The visual source is the Claude Design canvas "MeteorShift Map Redesign", boards "Caldera v2 · …". The positional source of truth is `tools/map-v3/plan.py`: every footprint in world studs, checked for overlaps and clearances. The archived v2 map is in `assets/archive/map-v2-2026-10-18/`.

## Idea
Height is progress. The island is a stadium of terraces facing the crater, and each new field sits a tier higher. Gold avenues lead up; slides and a Dive pad bring you down for the meteor.

## Geometry (world studs; X east, Z north; crater at the origin)
| Thing | Value |
|---|---|
| Play area | 1080 × 1080, `BoundaryHalf = 540` |
| T0 (Y 0) | r 0–250: crater, town, Rust Works, Frost Yard |
| Cliff T0→T1 | r 250–266, 16 straight segments per ring |
| T1 (Y 16) | r 266–360 |
| Cliff T1→T2 | r 360–372 |
| T2 (Y 32) | r 372 to the walls |
| Crown (Y 56) | plateau x −150..150, z 400..530 |
| Crater ring road | r 134, width 18, fast (unchanged contract) |
| Terrace Express | r 280, width 16, fast, on T1 |
| Avenues | 8, every 45° from the ring road out to the walls (diagonals end at corner Lookouts, north ends at the Crown at z 400), 24 wide, fast |
| Slides | beside the 45° avenue (clockwise side), the 135° avenue (counter-clockwise side) and the north avenue, 22 studs off the centre line, 8 wide, from the tier edge down to the ring road |
| Unchanged | crater bowl and `Config.LandingFX.Crater`, spawn grid (z −153/−148, x −18/0/18), Refinery (0, −177), `KillPlaneY = −70` |

Nothing within 117 studs of the crater is raised, so the shockwave's landing raycast works as today.

## Fields and the gate ladder
| Field id | Tier | Unlock | Reward (start values, tune in Play) |
|---|---|---|---|
| RustWorks | T0 | open | as today: Cash, Hp 4 |
| FrostYard | T0 | Level 5 | as today: Cash, Hp 10 |
| VioletQuarry | T1 | Level 12 | as today: Ore frost 0.4, Hp 10 |
| SulfurRidge | T1 | Level 20 | as today: Ore crystal 0.3, Hp 16 |
| EmberShelf | T2 | Level 30 | Cash, Hp 20, Seconds 9.5 (was 16), CashFloor 60, CeilingShare 0.02 |
| GlassScar | T2 | Level 40 | Ore alien 0.018 (was 0.4), Hp 24 |
| Starfall | Crown | Rebirth 1 | Cash, Hp 28, Seconds 13 (was 30), CashFloor 200, CeilingShare 0.03 |
| HaloLedge | Crown | Rebirth 3 | Ore alien 0.02 (was 0.6), Hp 32 |

Re-tuned 2026-10-22 so no field mined nonstop pays more than the player's expected income (`Config.Debris`, `tests/DebrisField.spec`).

- Tiers are always walkable; only fields are gated.
- A locked field:
  - refuses hits (`NodeService` `CanHit`)
  - refuses ORE travel
  - pushes out anyone standing on its floor
  - shows its gate as a solid barrier on that player's client, with "Level 12" (or the rebirth needed) on the plinth
- Gates open only through play; there are no Robux unlocks.

## Deposit points
Every field has an Ore Chute: a model holding a `UsePoint` under `Map.Chutes`. The Commissary moves to the T0 ENE slice, and the Refinery stays at spawn. `WorldMap.refineryPoints` returns all of them.

## Getting around
- **Up:** the avenues, which are fast lanes.
- **Down:** slides, which are physics-only.
- **Crown access:** the Sky Lift at (0, 410) is a prompt that moves you to the Crown and needs Rebirth 1.
- **Back from the Crown:** the Meteor Dive pad at (−30, 475) launches you on an arc to the crater rim.

## Budget
- **Parts:** about 15,000–18,000, with every district as its own streaming model.
- **Scenery:** 3,181 pieces from the seeded scatter.
- **Hero meshes:** drop-in replacements via `ServerStorage.MapArt`; the part fallbacks are built either way.

## Out of scope (space is reserved, built later)
- Shower lanes event
- Crack podium
- Scar Surge
- Ledge Run
- Sky Obby
- Daily geodes
- Telemetry for gate opens

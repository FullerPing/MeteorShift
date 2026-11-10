# World 2: Nebula Rift (plan, 2026-10-25)

Design canvas: https://claude.ai/artifact/L7jWLGdh1AFCtXuroETbbR (island plan, content, portal + Worlds menu).

A small floating island in space (600 × 600 studs; World 1 is 1080 × 1080) that opens at **rebirth 25**: one meteor
crater (the Rift), three ore fields, a small town (arrival plaza, Rift Refinery, Nebula Hatchery, return portal).

## Architecture: a second place in the same universe

World 2 is its own place (TeleportService), running the same Rojo scripts. Chosen over an island inside the World 1 place
because the code assumes one world per server everywhere:

- `MeteorService` runs one meteor and replicates one phase/countdown to the HUD; `Crater.MeteorSpawn` is a single path.
- `WorldGeometry` (boundary ±540, terraces, avenues, Crown), `WorldBoundary` (kills/returns anyone outside it),
  `CharacterSpeed` lanes, `Config.LandingFX.Crater` and the atmosphere all describe one map.
- A second place gets all of that for free: it just needs its own `Workspace.Map` that satisfies the same name contracts
  (`docs/guide/map-and-world.md`, "The names code depends on") and its own geometry numbers.

Cost: a teleport (5-10 s loading) and the DataStore session lock has to be handed over cleanly; players are split
across two server pools (late-game players only, so World 2 servers will be small; meteor sizing already scales by crowd).

## Status (2026-10-25)

Done: steps 1-4 (worlds config, travel + portals, content, the map), the ORE menu's world cards (instead of a separate
WORLDS tab). Open: Index pages for the three new meteors, the Nebula Egg and its pets, World 2 meteor icons, a
world-aware tutorial, `WorldGeometry` speed lanes for World 2's avenues, and the save/publish of both places.

## Build steps (one commit each, on release/interim)

1. **World identity.** `Config.Worlds` (Id, Name, PlaceId, Unlock = { Rebirths = 25 }, meteor type ids, field ids,
   geometry) and pure `Shared.Worlds` (`current()` from `game.PlaceId`, Studio override `workspace.DevWorld`;
   `isOpen(world, rebirths)`) + spec. Everything world-specific reads through it:
   `Config.Meteor.Types` schedule, `Config.Debris.Fields`, `WorldGeometry` constants, Tutorial starter field.
2. **Travel.** `WorldService` (server): validates the unlock, saves and **releases** the profile lock
   (`DataService` gets a `ReleaseForTeleport`), then `TeleportService:TeleportAsync` with a teleport loading screen;
   the arriving server's load retry already waits out a lock. Portal prompt on the Crown in World 1 and at the
   plaza in World 2; a WORLDS tab in the field travel menu (`FieldTravelController`). Badge "Into the Rift".
3. **Content config.** Meteor types Nebula / Solar / Eclipse (weights 60/25/15, same core model recoloured), ores
   nebulite / solarite / eclipse with bar prices, 12 Index minerals, fields Comet Drift (open, cash), Starlight Shelf
   (rebirth 27, solarite), Event Horizon (rebirth 30, eclipse). Fit with `Shared.Pacing` (a World 2 branch from
   rebirth 25) and update `tests/Pacing.spec`, `tests/DebrisField.spec`, `tests/Consistency.spec`.
4. **The map** in the new place: crater copied from World 1 at the same size (so LandingFX, shockwave and kill-floor
   numbers hold), island, roads, fields with gates/chutes/entrances, refinery, hatchery stand, portal, lighting.
   Built in Studio (or a small `tools/map-w2` stage set) and exported to `assets/world2/`.
5. **Nebula Egg** + its pets (later pets batch; the stand can show "coming soon" until then).
6. **Polish:** atmosphere (dark violet, no sun), music, telemetry `world_travel`, docs (`map-and-world.md`).

## Decisions (owner, 2026-10-25)

- Rebirth laps in World 2 take about as long as World 1's (13-15 min). So World 2 pays more (~3x) and the rebirth
  costs from 26 on rise with it; staying in World 1 past rebirth 25 is the slow road.
- Players can rebirth in World 2 and stay there.
- Portal: my pick, somewhere easy to reach. In the town by the spawn (not the Crown), plus the WORLDS tab anywhere.
- The place: created by the owner in Studio's Asset Manager (Places > Add New Place); its PlaceId goes in
  `Config.Worlds`. Step 1 (`Config.Worlds`, `Shared.Worlds`, spec) is done.

# MeteorShift

MeteorShift is a Roblox game: every few minutes a meteor slams into the crater in the middle of
town and the whole server rushes to mine it before it cools — nodes for ore, and a cracked core
pays everyone Core Shards. Between meteors, players mine debris fields around town, haul ore to
their line at the shared refinery, sell the bars for cash, and spend it on gear and production
levels. Core Shards buy Colony Perks and pet eggs, and rebirth resets the run for permanent
multipliers.

## Quick start

1. Open the saved place in Roblox Studio.
2. `rojo serve` in this folder, then connect from the Rojo plugin in Studio.
3. Run the specs in Edit mode (no Play needed) from the command bar or `execute_luau`:
   `require(game.ServerStorage.Tests.Runner)()`, or with a substring filter to run only
   matching specs, e.g. `require(game.ServerStorage.Tests.Runner)("MenuFit")`.
4. Play. In unpublished places profiles live in memory for the session, and the Studio meteor
   countdown is shortened; the dev hooks guide below covers both.

The world is not built by code: the map, the meteor and node templates and the lighting are
saved in the place, and Rojo never touches `Workspace`.

## Where the docs live

| Guide | Covers |
|---|---|
| [docs/guide/architecture.md](docs/guide/architecture.md) | Where everything lives and who talks to whom: repo map, Knit services, signal bus, state flow |
| [docs/guide/economy.md](docs/guide/economy.md) | Money: what ore and bars are worth, upgrade and rebirth costs, the Shared.Pacing model |
| [docs/guide/monetization.md](docs/guide/monetization.md) | The pass and product catalog, receipt flow, and the store's player-policy checks |
| [docs/guide/pets.md](docs/guide/pets.md) | Pets and eggs: the hatch loop, roles and perks, slot growth, premium pets |
| [docs/guide/profile-schema.md](docs/guide/profile-schema.md) | The saved profile: shape and defaults, migrations, what survives rebirth |
| [docs/guide/dev-hooks.md](docs/guide/dev-hooks.md) | Studio-only `Dev*` hooks and place attributes, and the chat commands |
| [docs/guide/testing.md](docs/guide/testing.md) | The spec Runner, spec conventions, the layout-spec pairing, the doc-reference checker |
| [docs/guide/map-and-world.md](docs/guide/map-and-world.md) | The place-side world: authoring contract, WorldGeometry, what is cloned, terrain and map tooling |
| [docs/guide/ui-hud.md](docs/guide/ui-hud.md) | The Fusion HUD: what it covers, the placement pipeline, the element roster |
| [docs/guide/hud-editing.md](docs/guide/hud-editing.md) | Owner tweaks: move, hide or add HUD elements from one config file |
| [docs/guide/native-ui.md](docs/guide/native-ui.md) | The native menus: builders vs exports vs runtime copies, bindings, styling layers |
| [docs/guide/audio.md](docs/guide/audio.md) | Sound and music: ids and tuning, playback, triggers, settings |
| [docs/guide/loading-screen.md](docs/guide/loading-screen.md) | The loading screen: stages and gating, preload, backgrounds, teardown |

Other docs and tools:

- [docs/design/meteor-shift-spec.md](docs/design/meteor-shift-spec.md) — the original MVP game spec.
- `docs/art-pipeline/` — Blender mesh briefs, pet-model conventions, the store-art plan.
- `docs/archive/` — superseded guides, design records, plan and run logs. History, not current truth.
- `docs/unrelated/ff.md` — an owner essay, not game content.
- Map generators, QA and rollback notes: [tools/map-v2/README.md](tools/map-v2/README.md).
- Native menu exports are regenerated in Studio with `tools/build-native-ui.luau`.

## Working on it

- Studio dev tooling — the `Dev*` command-bar hooks and place attributes (`DevMemoryStore` for
  isolated runs) and the `/meteor`, `/pickaxe` and `/backpack` chat commands — is catalogued in
  [docs/guide/dev-hooks.md](docs/guide/dev-hooks.md).
- What deserves a spec, and which spec guards which module, is in
  [docs/guide/testing.md](docs/guide/testing.md).
- Commands, architecture and conventions for AI coding agents: [CLAUDE.md](CLAUDE.md).

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

MeteorShift is a Roblox game (Luau, `--!strict`) synced to Studio with Rojo. Meteors crash into a central crater on a timer; players mine them together, haul ore to a personal refinery line, sell bars, upgrade gear, hatch pets and rebirth. `README.md` is the feature-by-feature spec (long, and parts are stale: the "plot-era map" section and the charcoal/studded UI description predate the current cartoon HUD restyle). Treat the code and `docs/` as the source of truth when they disagree.

## Commands

There is no build, lint or CLI test step. Everything runs through Rojo and Roblox Studio.

- `rojo serve` in the repo root, then connect with the Rojo plugin in Studio. `default.project.json` maps `src/shared` → `ReplicatedStorage.Shared`, `src/server` → `ServerScriptService.Server`, `src/client` → `StarterPlayerScripts.Client`, `tests` → `ServerStorage.Tests`, `src/loading` → `ReplicatedFirst`, `assets/native-ui` → `StarterGui`. `Packages/` (Knit, Fusion, Comm, Promise, Signal, Option) is vendored; don't edit it.
- Run all specs in Studio **Edit mode** (command bar or the Studio MCP `execute_luau`): `require(game.ServerStorage.Tests.Runner)()`. Run one spec (name or part of it): `require(game.ServerStorage.Tests.Runner)("MenuFit")`.
- Dev hooks (`DevGrant`, `DevGear`, `DevMeteor`, `DevLevel`, `DevMineral`, `DevBench`, `DevPet`, `DevProduct`, plus `/meteor`, `/pickaxe`, `/backpack` chat commands) and the `Dev*` attributes on `ServerStorage` / `ReplicatedStorage` are listed in the README's "Working on it" section. Set `ServerStorage.DevMemoryStore = true` **before** Play for isolated runs; clear it before saving the place.

## Testing conventions

- Logic worth testing is written as a pure module in `src/shared` (or `src/server/Lib`) with a `tests/<Name>.spec.luau` next to the others. A spec returns `function(t) ... end` and calls `t.test(name, fn)` with `t.eq`, `t.near`, `t.ok`. Require modules from `t.shared` / `t.lib` (fresh clones), never from the real `ReplicatedStorage.Shared`, or you test a stale require cache. See the header of `tests/Runner.luau`.
- Layout is tested the same way: each menu's sizing maths is a pure `Shared.*Layout` module (`EquipmentShopLayout`, `PetsLayout`, `StoreLayout`, `RebirthLayout`, `RefineryLayout`, `IndexLayout`, `HudLayout`) plus `Shared.MenuFit`, which shrinks menus on small screens by laying them out on a larger virtual screen. Change layout numbers there and update the spec, not the controller.
- `tests/Purchases.spec` and `tests/StoreLayout.spec` enforce that every pass/product in `Config.Monetization` appears in exactly one `Config.Store.Sections` entry or in `Config.Store.Elsewhere`. Adding a product means touching both.
- `Shared.Pacing` simulates a fresh player from Config and `tests/Pacing.spec` asserts progression targets (first rebirth ~14 min). Any change to prices, income or rebirth costs must be re-fitted until that spec passes.

## Architecture

**Knit, server and client.** `src/server/Main.server.luau` does `Knit.AddServices(Services)` and `Knit.Start()`; `src/client/Main.client.luau` does the same with `Controllers`. Drop a new `*Service.luau` / `*Controller.luau` into the folder and it loads. Services never poke each other's internals: they announce events through server-side signals (`NodeService.Hit`, `MeteorService.Landed/Ended`, `RewardService.ShardsAwarded`, `EconomyService.BarsSold`, `RebirthService.Reborn`, ...) that `TutorialService`, `TelemetryService`, `DailyService` and the badge code listen to. When a feature needs "when the player does X", add or reuse a signal rather than a direct call.

**State is server-owned and batched.** `DataService` owns the saved profile; `PlayerStateService` applies gameplay rules to it and replicates a `State` snapshot to the client at most once per `Config.Net.StateFlushInterval`. Controllers render from that snapshot and call service remotes; every action is re-validated on the server (range, swing speed, affordability, tier/level gates). Never trust a client number.

**Profile schema is versioned.** `src/server/Lib/ProfileTemplate.luau` holds the current `version` (10) and defaults; `DataService` migrates old profiles step by step. Adding saved data means: extend the template, bump the version, add a migration branch, and keep `RebirthReset` (what survives rebirth) consistent.

**Config is the only home for tuning numbers.** `src/shared/Config/init.luau` collects the table modules (Meteor, Gear, Pickaxes, Backpacks, Pets, Levels, Rebirth, Monetization, Store, Hud, HudEdit, HudIcons, Daily, Codes, Badges, ...). Rules that read Config live in sibling `Shared.*` modules (`Gear`, `Rebirth`, `Levels`, `MeteorTypes`, `Daily`, ...). Keep that split.

**Two UI systems side by side.**
- The main HUD and tutorial are Fusion (`HudView`, `UI`, `Controllers/HUDController`, `TutorialController`). Placement of every HUD button comes from one function, `Shared.HudLayout`, and the owner's per-element tweaks come from `Config/HudEdit.luau` (see `docs/hud-editing.md`).
- Internal menus (Shop, Pets, Foundry, Index, Rebirth, Store, Hatch, Settings, Backpack, Daily, Codes, Perks, WelcomeBack) are native ScreenGuis. Each `src/client/NativeMenus/<X>.luau` exposes `build()`; the authored result lives in `StarterGui` (exports in `assets/native-ui/*.rbxmx`) or is built at runtime with `NativeUI.getOrBuild`. Controllers fetch it via `NativeUI.get(name)`, bind controls **by instance name**, and `MenuSkin` restyles it on the way out (white body, blue border, glossy `Cartoon` surfaces, FredokaOne text with ink outline). Consequences: renaming an instance breaks its controller; menus carry a layout-mark attribute (`ShopLayout`, `PetsLayout`, `RebirthLayout`, `StoreLayout`) and when the saved copy's mark is older than the builder's `LAYOUT`, the controller swaps in the freshly built `Panel`, so bump `LAYOUT` whenever controls change. `RefineryMenu` is deliberately not exported (a stale export kept overwriting the redesign). Full workflow in `docs/native-ui.md`; `tools/build-native-ui.luau` regenerates menus in Studio.
- The Gear Shop and Pets menus have opted out of `MenuSkin` (`CartoonCustom = true` on their panels) and draw themselves with `MenuTheme` and `Shared.MenuPalette`, in the owner's "cartoon light" mockup (2026-10-13): the panel is a navy slab (outline and lip) with a white-to-pale-blue `Body` child; there's a blue title ribbon poking out of the top left, a red Close on the corner and wallet chips on the body; chunky buttons have a gradient face and a soft gloss band, with white text and an ink UIStroke on the blue and red buttons. Icons always come from `Config.HudIcons`. On a roomy window both draw the same 760x501 frame (body 760x475 plus the 26 px ribbon) scaled to 64% of the screen's width / 75% of its height (`EquipmentShopLayout.view`; Pets reuses it via `PetsLayout.compute(..., wide)`). On small screens they fall back to `MenuFit` layouts. To move another menu over, build it with `MenuTheme` (`panel`, `ribbon`, `closeCorner`, `chip`, `button`, `pill`, `well`, `bar`), mark its panels `CartoonCustom`, and replace its `N.enable` / colour assignments with `Theme.state` / `Theme.tab` / `Theme.select`. Panel children need ZIndex ≥ 2 to draw over `Body`.
- The colours the old controllers assign (tab active/inactive, disabled) are remapped by colour value inside `MenuSkin`. Restyling a menu usually means editing `MenuSkin` / `Cartoon` palettes, not each controller.

**The world is not built by code.** Rojo never touches `Workspace`; the map, the meteor core/node templates (`ServerStorage.Assets`), the pickaxe tool and the lighting are saved in the place, with `.rbxm` exports in `assets/` as backups. Only the meteor and plot production lines are cloned at runtime. Map geometry constants used by code are in `Shared.WorldGeometry`; map tooling is in `tools/map-v2`.

**Authoring pipelines (not runtime).** `blender/` and `tools/blender-assets/` generate gear/pet/egg/item meshes from JSON briefs; `tools/store-art`, `tools/key-art` and `assets/marketing` produce store and marketing art; `tools/export-native-ui.cjs` writes Studio ScreenGui property dumps to `.rbxmx`.

## Owner decisions that look like bugs but aren't

- Huge numbers are intentional: rebirth multiplies sales ×5 and every cash price ×3 (`Rebirth.priceMult`). Don't shrink them; keep income and prices inflating together, re-fit `Config.Rebirth.Costs` with `Shared.Pacing`, and keep `Format.number` suffixes ahead of the largest values.
- Core Shards, gear tier-ups (EVOLVE NOW R$), the forced Alien boss meteor, "Rebirth and Keep Everything", pet max-level and the Starter Value Pack are sold on purpose. Don't re-raise pay-to-skip concerns; wire and polish them. Product/pass ids in `Config.Monetization` that are `0` are intentionally off sale until the owner creates the dashboard item; never invent ids.
- Eggs cost earned Core Shards only and never Robux; no product changes mineral odds or grants random pets.

## Studio and Windows gotchas

- A `UIGradient`'s colours are multiplied with the object's own `BackgroundColor3`. Set the object white and let the gradient carry the colour (`MenuTheme.gradient` does this); setting both renders darker and more saturated than intended.
- Never replace `ReplicatedStorage.Shared` with a clone to bust the require cache: it breaks Rojo sync for that folder. Restart Studio to clear caches (the studio id changes; list studios again).
- Long `execute_luau` calls freeze Studio and time out: run loops in `task.spawn` with `task.wait()` and poll an attribute.
- During Play, `execute_luau` has its own require/Knit instances, so `Knit.GetService` fails there. Drive the real game through remotes from the Client datamodel and read server state via `ServerStorage.DevGrant:Invoke(player)` (returns a copy of the profile).
- Working tree files are LF in git but Windows will warn about CRLF; scripts that rewrite Luau should preserve LF and take care with `\n` escapes inside Luau strings.
- Scratch and generated output goes in `.tmp/` and `output/` (git-ignored). `docs/superpowers/` holds specs and plans from the brainstorming workflow.

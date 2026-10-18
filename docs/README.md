# MeteorShift docs

Start here: this is the index of everything under `docs/`. The code and the guides in
[`guide/`](guide/) are the source of truth — where prose and code disagree, the code wins. The repo-root
`README.md` (one level up) is the quick start.

## Guides — `docs/guide/`

| File | What it covers | Best for |
|---|---|---|
| [architecture.md](guide/architecture.md) | Where everything lives and who talks to whom: services, signals, state flow, config split | new dev |
| [economy.md](guide/economy.md) | Money: ore and bar values, upgrade and rebirth costs, pacing and `Shared.Pacing` | owner tweaks, reviewer |
| [monetization.md](guide/monetization.md) | The pass/product catalog, receipt grants, store placement rules, policy | owner tweaks, reviewer |
| [pets.md](guide/pets.md) | Pet roster, hatching odds and pity, perks, slots, where the server applies each role | new dev, artist |
| [profile-schema.md](guide/profile-schema.md) | The saved player record: schema versioning, migrations, what survives rebirth | reviewer, server dev |
| [testing.md](guide/testing.md) | The Studio spec Runner, spec conventions, layout-module pairing, the doc checker | new dev |
| [dev-hooks.md](guide/dev-hooks.md) | Studio dev hooks, `Dev*` attributes, chat commands, safety switches | owner tweaks, dev |
| [map-and-world.md](guide/map-and-world.md) | The place-side world: authoring contract, `Shared.WorldGeometry`, what code clones, map tooling | map artist, new dev |
| [ui-hud.md](guide/ui-hud.md) | The Fusion HUD pipeline: layout module, state bindings, element roster, toasts | new dev |
| [hud-editing.md](guide/hud-editing.md) | How to move, hide or tweak a HUD element via `Config/HudEdit` | owner tweaks |
| [native-ui.md](guide/native-ui.md) | Native menus: builder vs saved export, bind-by-name, layout marks, restyle layers, rebuild workflow | UI dev |
| [audio.md](guide/audio.md) | Sound and music: the `Sfx` module, trigger map, settings, asset policy | new dev |
| [loading-screen.md](guide/loading-screen.md) | The ReplicatedFirst loading screen: stages, preloading, timings, teardown | new dev, artist |

## Design — `docs/design/`

| File | What it covers |
|---|---|
| [meteor-shift-spec.md](design/meteor-shift-spec.md) | The original MVP game spec (v2); kept as design reference — numbers inside are superseded by code |

## Art pipeline — `docs/art-pipeline/`

| File | What it covers |
|---|---|
| [blender-asset-briefs.md](art-pipeline/blender-asset-briefs.md) | Per-asset Blender mesh briefs: style, scale, budgets |
| [pet-models.md](art-pipeline/pet-models.md) | Authored pet model conventions and the build/export tool |
| [store-art-plan.md](art-pipeline/store-art-plan.md) | Store icon, thumbnails and loading-art brief (delivered as 2D vector art) |

## Unrelated — `docs/unrelated/`

| File | Why it's here |
|---|---|
| [ff.md](unrelated/ff.md) | Owner's literary essay (Lithuanian), zero game content — kept untouched, out of the docs' way |

## Archive — `docs/archive/`

Historical material, kept for provenance. Excluded from the doc checker; do not treat any of it as current.

| File or subdir | Status |
|---|---|
| [balance.md](archive/balance.md) | SUPERSEDED by [guide/economy.md](guide/economy.md) |
| [economy-rework.md](archive/economy-rework.md) | SUPERSEDED by [guide/economy.md](guide/economy.md) |
| [purchases.md](archive/purchases.md) | SUPERSEDED by [guide/monetization.md](guide/monetization.md) |
| [map-improvement-handoff.md](archive/map-improvement-handoff.md) | HISTORY — Oct-8 map-model art pass, executed |
| [studio-refinery-prompt.md](archive/studio-refinery-prompt.md) | HISTORY — Studio-AI prompt that placed the shared refinery |
| [master-prompt.md](archive/master-prompt.md) | HISTORY — master prompt driving the Oct-4/5 overnight run |
| [overnight-report.md](archive/overnight-report.md) | HISTORY — execution report of that overnight run |
| `plans/` | HISTORY — completed implementation plans (improvement pass; Oct-1 map model audit) |
| `superpowers/plans/` | HISTORY — build plans (overnight pets; gear-level merge + price inflation; daily rewards) |
| `superpowers/specs/` | HISTORY — design specs for features since built (gear-level merge; price inflation; daily rewards) |
| `map-redesign/` | HISTORY — the big-map redesign as a unit: plan, compact revision, progress, report, audit, critique round, QA evidence |
| `hud-export/` | HISTORY — owner phone-HUD mockup PNGs |

`docs/plans/` is an empty leftover directory — its plans moved to `docs/archive/plans/`.

## How docs are maintained here

- Guides cite code as `file:line` against the current tree; a claim with no cite is a hint, not a fact.
- Tuning numbers live in `src/shared/Config`, not in prose — guides point at the Config file instead of
  copying values that drift.
- `docs/archive/` is excluded from the checker; everything else under `docs/`, plus `README.md` and
  `CLAUDE.md`, is checked: run `node tools/check-docs.cjs` from the repo root — exit 0 means every
  relative link and backticked repo path resolves.
- Never stamp the profile-schema version number into prose — point at `ProfileTemplate`'s `version` field.

# Audio

All audio is client-side. Two Config modules hold every id and all tuning, one module (`src/client/Sfx.luau`) plays everything else by name, and the triggers are the same replicated service signals the HUD listens to — the signal bus described in [docs/guide/architecture.md](architecture.md). The server never plays sound; `src/loading` has no audio (grep for `Sound` in `src/loading` finds nothing). The README's single-line audio bullet (README.md:19) points here.

## Where things live

| What | File |
|---|---|
| Sound ids, volume, pitch, cooldown, per-name cap, group, variants, duck (`Sounds`) | `src/shared/Config/Sounds.luau` |
| Music tracks, ambience bed, crater hum, crossfade and warn timing (`Music`) | `src/shared/Config/Music.luau` |
| Playback: 2D pools, spatial one-shots, SoundGroups, cooldowns, Settings mutes, preload | `src/client/Sfx.luau` |
| Music crossfade, ambience, crater hum, warning siren, core-crack stinger | `src/client/Controllers/MusicController.luau` |
| Signal-driven feedback: deposits, upgrades, level ups, pets, refusals, menus, tutorial | `src/client/Controllers/FeedbackController.luau` |
| The visual half of the same feedback (bursts, pillars, coin flight, camera kick) | `src/client/RewardFX.luau`, `src/shared/Config/RewardFX.luau` |
| Particle sprites (sparkle, ring, rays) | `assets/fx/`, drawn by `tools/store-art/draw_fx_sprites.py` |
| Shape guards for both configs | `tests/Sounds.spec.luau` |

## Playback mechanics (`src/client/Sfx.luau`)

- `Sfx.play(name, parent?, reach?, speed?)` looks the key up in `Config.Sounds`; an unknown name or a dropped play returns `nil` (`Sfx.luau:104-108`).
- **2D sounds** (no `parent`) come from a rotating pool of `Sound`s under `SoundService`, capped at `Entry.Max` per name (default 4) (`Sfx.luau:18,142-165`). **Spatial sounds** (`parent` = part/attachment) are one-shots destroyed on `Ended` or after 15 s, capped at `Max` (default 6) (`Sfx.luau:19,113-139`).
- `Cooldown` is the shortest gap between two plays of one name — a held mine button cannot pile up sounds (`Sfx.luau:81-89`).
- `PitchMin`/`PitchMax` pick a random `PlaybackSpeed` per play; the `speed` argument multiplies it (`Sfx.luau:62-68,122,162`). `Variants` rotate so repeats don't sound identical (`Sfx.luau:71-79`).
- Everything plays through a `SoundGroup` under `SoundService.Master` — `Music`, `Ambience`, `SFX`, `UI` (`Sfx.luau:20,32-59`). The SFX group carries a `CompressorSoundEffect` so bursts of hits, coins and fanfares don't clip (`Sfx.luau:49-54`).
- An entry's `Duck` sets a `DuckUntil` attribute on the Music group; `MusicController` reads it to lower the music briefly (`Sfx.luau:92-98`, `MusicController.luau:91-92`).
- `Sfx.bindSettings()` and `Sfx.preload()` run at boot from `Main.client.luau:7-8`; preload downloads every configured id once so the first hit doesn't stall (`Sfx.luau:186-207`).

## Music and ambience (`src/client/Controllers/MusicController.luau`)

Three looping beds start on `KnitStart`: the hub track, the event track (from silence) and the ambience bed (`MusicController.luau:39-43`; track specs at `Config/Music.luau:8-9,15`).

- Each `Heartbeat` the event mix moves toward `max(approach, event)` from `Shared.AtmosphereMood` — the same sky weights the atmosphere controller uses — over `Music.Fade` seconds (`MusicController.luau:66-75,90-96`; weights at `src/shared/AtmosphereMood.luau:76-77`). The event track restarts from the top each time it fades in from silence (`:86-89`), and ambience dips 60% while the event track is up (`:97`).
- **Stingers**: any `Config.Sounds` entry with `Duck` (the fanfares and `CoreStinger`) pulls the music to `Music.DuckTo` for its seconds (`Config/Music.luau:11-12`, `Sfx.luau:92-98`, `MusicController.luau:91-94`).
- **Crater hum** rides the active meteor's PrimaryPart during the `Impact`/`Active` phases, rolling off over `CraterHum.MinDistance`/`MaxDistance`, and is destroyed when the meteor leaves (`MusicController.luau:99-114`, `Config/Music.luau:16`).
- **The warning**: once per countdown, when the `Countdown` phase is within `Music.WarnAt` seconds of landing (12 s; the sky starts turning earlier at `Config.Atmosphere.ApproachLead` = 25 s, `src/shared/Config/Atmosphere.luau:25`), the siren plays twice — `MeteorSiren` + `MeteorBuild` whoosh, a second siren 0.9 s later (`MusicController.luau:77-82`, `Config/Music.luau:19`).
- `MeteorService.Impact` is remembered so the mood weights know how long the meteor has been down; `MeteorService.CoreCracked` fires the 2D `CoreStinger` (`MusicController.luau:52-57`; signals exposed on the service's `Client` table at `src/server/Services/MeteorService.luau:50-52`).

## Trigger map (event → signal → sound)

`FeedbackController` connects on Knit's client service mirrors (`Knit.GetService`, e.g. `FeedbackController.luau:23-31`; mirrors defined in each service's `Client` table, e.g. `src/server/Services/RefineryService.luau:20-26`):

| Game event | Signal | Sound(s) | Site |
|---|---|---|---|
| Ore deposited | `RefineryService.Deposited` | Deposit | `FeedbackController.luau:33-35` |
| Bars collected | `RefineryService.Collected` | Collect + CollectCoins + burst | `:36-40` |
| Line / gear level up | `UpgradeService.Upgraded`, `ShopService.Upgraded` | Upgrade + burst | `:41-48` |
| Gear evolve (purchase) | `ShopService.Purchased` | EvolveRise + Evolve + pillar | `:49-53` |
| Player level up | `LevelService.LevelUp` | LevelUp fanfare + pillar + "LEVEL UP!" | `:54-58` |
| Pet levels | `PetService.Leveled` | PetChime | `:59-62` |
| Pass pet arrives | `PetService.Bought` | RevealRare | `:63-66` |
| Index discovery | `IndexService.Discovered` | PetChime at 1.15× pitch | `:67-69` |
| Shards/bonus granted | `RewardService.Bonus` | Bonus | `:70-73` |
| Backpack overflow | `PlayerStateService.BackpackFull` | BackpackFull + "FULL!" | `:74-78` |
| Any refusal ("Need $X", "move closer") | `Notice` on Refinery/Upgrade/Shop/Pet/Economy/Perk | Deny | `:79-85` |
| Any of 10 menus opens/closes | player attributes (`ShopOpen`, `SettingsOpen`, … set by each menu) | MenuOpen / MenuClose | `:19-20,87-96` |
| Tutorial step completes | `TutorialService.Step` property observed | TutorialStep + burst + praise word | `:98-109` |
| Bars sold | `EconomyService.Sold` | SellCoins + Sell, then coins fly to the wallet and land with a high OrePickup | `HUDController.luau:494-511` |
| Meteor lands | `MeteorService.Impact` visuals | MeteorImpact (spatial, in the shockwave) + looped MeteorRumble riding the sky streak, ramping with `StreakLeadTime` | `MeteorFXController.luau:150-161,277,425-427`; streak cleared at `:55-67` |
| Core cracks | `MeteorService.CoreCracked` | CoreStinger (2D, above) + CoreCrack/CoreWhoosh/CoreChime spatial burst | `MusicController.luau:55-57`; `MeteorFXController.luau:370-372` |
| Ice/Crystal clusters erupt | landing build callbacks, ranks in `Config.LandingFX.SoundRanks` (1/4/7) | FrostCrackle / CrystalChime, spatial | `LandingFXController.luau:604-618`; sounds at `src/shared/Config/LandingFX.luau:33,36,54`, passed at `:716,1053` (see [docs/guide/map-and-world.md](map-and-world.md)) |
| Mining (client prediction) | — | Swing on each swing, HitA/HitB alternating per spark, NodeBreak when the node's `Hp` attribute hits 0, CritHit+CritSparkle on a server-confirmed crit, OrePickup whose pitch climbs with a 1.2 s pickup streak, Bonus (pitched) on Rich/Super Vein | `MiningController.luau:394,249-254,411-416,428-431,316-338,520-526` |
| Hatching | — | HatchTick, faster and higher as the wobble builds, then HatchCrack + a reveal keyed by rarity (premium uses the legendary sting) | `HatchController.luau:328-330,230-231`; rarity map `:37-40` |
| Rebirth succeeds | `RebirthService:Rebirth()` returns | RebirthWarp, then Rebirth fanfare 0.7 s later + pillar | `RebirthController.luau:152-155` |
| Field travel succeeds | `DebrisService:TravelTo` returns | Teleport + poofs | `FieldTravelController.luau` (Travel handler) |
| Claims and buys elsewhere | — | Upgrade at 1.1× pitch: code redeem, daily claim, perk buy. Bonus: quest-complete toast | `CodesController.luau:68`, `DailyController.luau:155,239`, `PerksController.luau:96` |
| UI buttons | — | Click: Fusion buttons, native menu buttons, intro pills, store offer tiles | `UI.luau:319,478`, `NativeUI.luau:94`, `IntroController.luau:68`, `OfferController.luau:58` |
| Pet footfalls | — | graniteGolem HeavyStep (a HitA sample), drill-style pets a looped RotorHum plus an arrival AssemblyClick, scrapSparrow a MetalTing on every `Sold` | `PetVisualController.luau:221-227,366-370`; pooled helper `:58-71` |

## The sound roster (`src/shared/Config/Sounds.luau`)

44 keys in six comment groups. Config cites are `Sounds.luau:<line>`; triggers are above.

| Group (keys) | Config | Header of the group's rule |
|---|---|---|
| Mining — HitA, HitB, Swing, CritHit, CritSparkle, NodeBreak, OrePickup, BackpackFull | `:26-34` | variants alternate so rapid swings don't repeat (`:25,32`) |
| Meteor — CoreCrack, CoreWhoosh, CoreChime, CoreStinger, MeteorImpact, MeteorRumble, MeteorSiren, MeteorBuild, FrostCrackle, CrystalChime | `:37-46` | stingers carry `Duck` (`:40`) |
| Refinery and money — Deposit, Collect, CollectCoins, Sell, SellCoins, Purchase | `:49-54` | short cooldowns against coin spam |
| Progress — Upgrade, EvolveRise, Evolve, LevelUp, PetChime, Bonus, RebirthWarp, Rebirth, Teleport | `:57-65` | fanfares duck the music |
| Hatching — HatchTick, HatchCrack, RevealCommon, RevealRare, RevealEpic, RevealLegendary | `:68-73` | reveal-by-rarity ladder |
| Interface — Click, MenuOpen, MenuClose, Deny, TutorialStep | `:76-80` | `Group = "UI"` so the Settings switch mutes them (`:76-80`) |

Music keys — Hub, Event, Ambience, CraterHum — live beside the crossfade/duck/warn numbers in `Config/Music.luau:8-19`; the spec pins them at "quiet volumes" (≤ 0.5, `tests/Sounds.spec.luau:44-53`).

## Player settings

The Settings menu (`src/client/NativeMenus/Settings.luau:20-25`) exposes four preference switches plus two HUD ones; the rows are wired from one list in `NativeHudMenus.luau:18-25` — each row named after its player attribute flips it on click (`:124-134`) and gets its default the first session (`:126`).

- **MusicOn** mutes the Music *and* Ambience groups; **SfxOn** mutes SFX *and* UI (`Sfx.luau:168-183`, applied at `Main.client.luau:7`). Silence means group volume 0, not pausing.
- **ReduceEffects** skips RewardFX visuals (`RewardFX.luau:20`), hatch rays and shell shards (`HatchController.luau:233-236`, live via `:298-300`), meteor particles — and it also silences the spatial impact and core-crack sounds, because they fire below the guard in the same FX functions (`MeteorFXController.luau:165` before `:277`, `:340` before `:370-372`; the 2D CoreStinger still plays). Pet footfall sounds check it too (`PetVisualController.luau:59`).
- **ReduceCameraShake** skips the crit kick and meteor shake (`RewardFX.luau:269`, `MeteorFXController.luau:42,380-381`, `ImpactFXController.luau:79`).
- These are **session-scoped local preferences**: nothing in `src/server` reads `MusicOn`/`SfxOn`/`ReduceEffects`, and the profile template has no settings key (both greps, self-verified 2026-10-18), so toggles revert to their defaults next session.

## Sources and licensing

Every sound is licensed for all Roblox experiences: uploads by Roblox's library accounts (Pro Sound Effects, APM), Roblox's own UI kit, or built-in `rbxasset://` clips (`Sounds.luau:2-4`, `Music.luau:2-3`). The owner's rule from the previous doc stands: never use Creator Store re-uploads by other users (old record, this file's history); to widen the library, search the toolbox and keep only creators `ProSoundEffects` or `APMOfficial`: `https://apis.roblox.com/toolbox-service/v2/assets:search?searchCategoryType=Audio&query=<words>&maxPageSize=100`.

Titles as recorded in the previous audio doc (kept as art direction; **not** re-verified against the store — the code carries ids only, and points back here for sources, `Sounds.luau:4`): Hub "Tropical Island" and Event "Level Up (Alternate 3)" (`Music.luau:8-9`), Ambience "Mountain Birds 1" and CraterHum "Low Rumble 2" (`Music.luau:15-16`), LevelUp "Cartoon Fanfare (c)", Evolve "Victory Lap (sting)", Rebirth "Winner", RevealLegendary "Top Prize", CoreStinger "Kinetic Victory (Sting)", and MenuOpen / MenuClose / Deny / TutorialStep / OrePickup / BackpackFull from the Roblox UI kit. To swap a sound, change its id in the config — nothing else names an id.

## Guards

`tests/Sounds.spec.luau` (run via the Runner — see [docs/guide/testing.md](testing.md)) keeps both configs playable: every id is an asset id with volume in 0..1 and a known group (`:11`), pitch ranges are ordered and variants non-empty, `Duck` ≤ 8 (`:19`), every name the game plays is configured (`:32-43`), music/beds are quiet and `WarnAt` fits inside `Atmosphere.ApproachLead` (`:44-53`), and RewardFX sprites are asset ids (`:54`).

## Adding a sound

1. Add a key to `Config/Sounds.luau` (id, volume, optional pitch band, cooldown, cap, group, variants, duck) — if the trigger plays it by name, add the name to the spec's list (`tests/Sounds.spec.luau:33-37`).
2. Trigger it from a signal, not a direct call: connect in `FeedbackController.luau` like the others, or in the controller that owns the moment, and call `Sfx.play("Key")` — spatial plays take the part and an optional reach (`Sfx.luau:104`).

## Known gaps

- `Purchase` (`Sounds.luau:54`) is configured but has no play site anywhere in `src` (self-verified grep) — purchases currently make sound through `Upgrade`/`EvolveRise`.
- Landing bursts get cluster sounds only for Ice and Crystal at ranks 1/4/7 (`Config/LandingFX.luau:33,36,54`); Iron and Alien landings rely on the shared `MeteorImpact` alone.
- There is no per-zone ambience — one global bed plus the crater hum (`Music.luau:15-16`); only two music tracks exist (hub/event).

# Architecture

MeteorShift in one sentence: a meteor slams into the crater on a timer (`MeteorService`), everyone mines it together (`NodeService`, ore into each player's backpack), ore is hauled to a personal refinery line at the shared world refinery (`RefineryService`), bars are sold for cash (`EconomyService`), cash buys gear and production levels (`ShopService`, `UpgradeService`), Core Shards buy perks and eggs (`PerkService`, `PetService`), and rebirth resets the run for permanent multipliers (`RebirthService`). This doc answers "where does X live and who talks to whom"; every structural claim carries a `file:line` against the current tree.

## Repo shape (the Rojo map)

`default.project.json:5-40` is the whole mapping; Rojo never touches `Workspace` — the map, meteor/node/pet templates and lighting are saved in the place, with `.rbxm`/`.rbxmx` backups under `assets/`.

| Repo path | Datamodel address | Cite |
|---|---|---|
| `Packages/` (vendored Knit, Fusion, Comm, Promise, Signal, Option — don't edit) | `ReplicatedStorage.Packages` | `default.project.json:11-13` |
| `src/shared/` — pure logic + `Config/` | `ReplicatedStorage.Shared` | `default.project.json:14-16` |
| `src/server/` — `Main.server.luau`, `Services/`, `Lib/` | `ServerScriptService.Server` | `default.project.json:24-27` |
| `src/client/` — `Main.client.luau`, `Controllers/`, menu/UI code | `StarterPlayerScripts.Client` | `default.project.json:29-34` |
| `tests/` — `Runner.luau` + one `*.spec.luau` per pure module | `ServerStorage.Tests` | `default.project.json:18-22` |
| `src/loading/` | `ReplicatedFirst` | `default.project.json:5-9` |
| `assets/native-ui/` — authored menu ScreenGui exports | `StarterGui` | `default.project.json:36-39` |

## Knit wiring

- Server entry: `Knit.AddServices(script.Parent.Services)` then `Knit.Start()` — `src/server/Main.server.luau:13` and `:15`. Any `*Service.luau` dropped into `src/server/Services/` loads; no registry file to edit. After start, `Main.server.luau` also binds the Studio-only `Dev*` hooks inside `RunService:IsStudio()` (`:45-194`) and the admin `/meteor`, `/pickaxe`, `/backpack`, `/give`, `/giveall` chat commands (`:196-278`) — details in the dev-hooks guide.
- Client entry: `Knit.AddControllers(script.Parent.Controllers)` (`src/client/Main.client.luau:10`) and `Knit.Start({ ServicePromises = false })` (`:12`), so client `Knit.GetService` returns the real Comm proxy synchronously.
- What Knit gives each service: every function, signal and property under the service's `Client` table is wrapped as a Comm RemoteFunction/RemoteSignal/RemoteProperty on the server (`Packages/Knit/KnitServer.luau:416-420`) and mirrored back to the client proxy (`Packages/Knit/KnitClient.luau:285`, `Packages/Comm/Client/ClientComm.luau:192-203`). Roblox passes the invoking `Player` itself as the first server argument — identity is engine-authoritative, everything after it is raw client payload the server must re-check (see `State flow`).

## Services (25, all in `src/server/Services/`)

| Service | Owns |
|---|---|
| ActivityService | who counts as active (input in the last 2 min) — meteor HP is sized from them only |
| CodesService | code redemption: normalises, checks `Config.Codes`, marks redeemed before paying |
| ContributionService | per-event contribution tally (in Mining Power, not displayed damage) |
| DailyService | daily streak, quests, badges; counts progress from the other services' signals |
| DataService | saved profiles: DataStore session lock, load, 60 s autosave, save-on-leave/shutdown |
| DebrisService | debris rocks between meteors: HP sized per active player, respawn, field teleports |
| EconomyService | selling bars at the Trading Post (rebirth × index × VIP × pet multipliers) |
| IndexService | mineral rolls on validated meteor hits and page-completion rewards |
| LeaderboardService | the OrderedDataStore leaderboards beside the Foundry |
| LevelService | player XP and level; each level-up opens a Supply Crate |
| MeteorService | the meteor schedule and its server-authoritative state machine |
| MonetizationService | game passes and developer products; receipts, dedupe, save-before-ack |
| NodeService | mineable targets: HP, swing validation, ore drops, ~10 Hz HP attribute replication (`NodeService.luau:11`) |
| PerkService | Colony Perks: permanent shard purchases, kept through rebirth |
| PetService | pet owning/equipping/XP and where each perk role acts |
| PlayerPolicyService | Roblox PolicyService lookup (paid-random / paid-trading gates; none used today) |
| PlayerStateService | the gameplay rules over the profile; replicates the `State` snapshot |
| RebirthService | rebirth: re-checks cost, resets via `Lib.RebirthReset`, grants overstay shards |
| RefineryService | the shared world refinery + each player's saved line; offline catch-up |
| RewardService | Core Shard payouts and the top-three announcement |
| ShopService | pickaxe/backpack level buys and tier evolutions; applies the tool look |
| TelemetryService | analytics — logs everything from the other services' signals, never gameplay |
| TutorialService | tutorial steps; every step completes on the real action, heard from signals |
| UpgradeService | personal production-line level buys at the refinery (`Shared.Line`) |
| WorldBoundaryService | keeps players inside the world (loop started in `KnitStart`) |

## Controllers (32, all in `src/client/Controllers/`)

| Controller | Role |
|---|---|
| ActivityController | pings ActivityService on input (throttled) so you aren't AFK |
| AtmosphereController | fog/light moods blended over the place's calm look during events |
| CodesController | the CODES button and text box → CodesService |
| CustomHudController | draws the extra buttons/labels from `Config.HudEdit.Custom` |
| DailyController | the Daily Rewards menu, claim dots, once-a-session auto-open |
| FastWalkController | the SPRINT toggle (server owns the speed) |
| FeedbackController | all sounds/FX for game events, from the client-side signal tables below |
| FieldFXController | glow/sparkle/break FX for debris rocks (purely local) |
| FieldTravelController | the ORE tile → Ore Fields menu (NativeMenus.OreFields) → field teleport |
| FoundrySignController | live hopper/storage meters on the foundry and commissary signs |
| HatchController | the egg-hatch queue and rarity reveal (input block ≤ 2 s) |
| HUDController | the Fusion HUD: timers, wallet, buttons, notices (`HudView`, `Shared.HudLayout`) |
| ImpactFXController | extra impact spectacle (pillars, rings, dust, rain) |
| IndexController | the MineralIndex menu bindings |
| IntroController | the first-join intro cinematic (a meteor crashes into the crater under the title) before the tutorial |
| LandingFXController | Ice/Crystal ground scenes driven by `MeteorService.State` |
| MeteorFXController | sky streak, shake, explosion, shockwave, knockback |
| MiningController | pickaxe input and local feedback; server validates every swing |
| MobileControlsController | the touch MINE button (`Shared.Aim`) |
| MusicController | hub/event tracks, stingers, siren, hum |
| NodeHealthController | HP bars over targets you have hit; shared bar for the core |
| OfferController | the pass/Starter-Pack offer tiles outside the Store menu |
| PerksController | the Colony Perks panel |
| PetVisualController | local pet followers from the replicated loadout |
| PetsController | the Pets menu (MY PETS / PET INDEX / eggs) |
| RebirthController | the Rebirth panel bindings |
| RefineryController | the Refinery panel bindings |
| ShopController | the Gear Shop bindings (purchases stay server-side) |
| StoreController | the Store menu bindings |
| SurfaceFXController | crater-floor scenes living as long as a meteor is down |
| TelemetryController | reports menu opens to TelemetryService (stupid on purpose) |
| TutorialController | the tutorial card, trail, outlines and pointing hand |

The main HUD and tutorial are Fusion; the internal menus are native ScreenGuis bound by instance name (`NativeUI.get`/`getOrBuild`, `src/client/NativeUI.luau:86-98`) — the workflow and restyle rules live in [native-ui.md](native-ui.md) and [hud-editing.md](hud-editing.md).

## Server signal bus

Services never call each other's internals: they `Signal.new()` a field, fire it when something happens, and interested services `:Connect` at `KnitStart`. When a feature needs "when the player does X", add or reuse a signal — e.g. TutorialService advances "meteor_lands" on `MeteorService.Landed` (`TutorialService.luau:185`) and TelemetryService resets its event tallies on the same signal (`TelemetryService.luau:287`). Definitions and fire/listen lines below are all files in `src/server/Services/` (listeners otherwise marked); traced exhaustively 2026-10-18.

| Signal | Def | Fires | Listens (line) |
|---|---|---|---|
| DataService.ProfileLoaded | DataService.luau:52 | :296 | Index :120, Refinery :293, Monetization :474, Telemetry :367, PlayerState :505, Shop :303, Tutorial :138, Daily :186, Pet :294 |
| DataService.ProfileReleasing | DataService.luau:53 | :304 | none yet (hook exists for "before the final save") |
| NodeService.Hit | NodeService.luau:74 | :353 | Index :129, Level :90, Telemetry :275, Tutorial :171, Daily :197, Pet :311 |
| MeteorService.Landed | MeteorService.luau:56 | :608 | Telemetry :287, Tutorial :185, Daily :206 |
| MeteorService.CoreUnlocked | MeteorService.luau:57 | :331 | Telemetry :294, Tutorial :177 |
| MeteorService.Ended | MeteorService.luau:60 | :635 | Telemetry :299 |
| RewardService.ShardsAwarded | RewardService.luau:35 | :90 | Telemetry :303, Tutorial :190 |
| EconomyService.BarsSold | EconomyService.luau:34 | :91 | Telemetry :320, Tutorial :207, Daily :213, Pet :315 |
| RefineryService.OreDeposited | RefineryService.luau:29 | :132 | Telemetry :311, Tutorial :193, Daily :216, Pet :316 |
| RefineryService.BarsCollected | RefineryService.luau:30 | :154 | Telemetry :312, Tutorial :204, Pet :317 |
| RefineryService.CaughtUp | RefineryService.luau:31 | :203 | Telemetry :313 |
| PlayerStateService.OreAutoDeposited | PlayerStateService.luau:37 | :375, :418, :450 | Refinery :308, Tutorial :198 |
| LevelService.LeveledUp | LevelService.luau:29 | :74 | Telemetry :374, Daily :228 |
| ShopService.ItemBought | ShopService.luau:41 | :126, and Monetization :292 (Robux tier-up) | Telemetry :328, Tutorial :210 |
| ShopService.StatUpgraded | ShopService.luau:42 | :168 | Telemetry :337, Tutorial :213 |
| UpgradeService.LineUpgraded | UpgradeService.luau:23 | :58 | Telemetry :342, Tutorial :216 |
| RebirthService.Reborn | RebirthService.luau:34 | :93 | Telemetry :348, Daily :224 |
| IndexService.PageCompleted | IndexService.luau:34 | :100 | Telemetry :395, Daily :232 |
| PetService.PetBought | PetService.luau:39 | :131, :157 | Daily :235 |
| PetService.EggHatched | PetService.luau:40 | :135 | Telemetry :379, Daily :219 |
| PerkService.PerkBought | PerkService.luau:25 | :54 | Telemetry :389 |
| DebrisService.RockBroken | DebrisService.luau:39 | :153 | Telemetry :420 |
| MonetizationService.PassBought | MonetizationService.luau:75 | :482 | Telemetry :353, Pet :306 |
| MonetizationService.PassesReady | MonetizationService.luau:76 | :191 | Pet :310 |
| MonetizationService.ProductBought | MonetizationService.luau:79 | :313 | Telemetry :357 |

Two cross-service patterns worth knowing: MonetizationService re-fires shop/pet signals after a Robux grant so listeners react once either path bought the thing (`MonetizationService.luau:291-295`), and the admin chat-command replies fire `ShopService.Client.Notice` from `src/server/Main.server.luau:214` and `:246`.

## Server → client: Knit signals and properties

Same bus, transported as Comm RemoteSignals; the server fires `:Fire(player, …)` / `:FireAll(…)` inside its own service and controllers `Connect` on the client proxy. FeedbackController connects every `*.Notice` in one loop (`FeedbackController.luau:76-85`).

| Service | Client signals (def in `src/server/Services/<service>.luau`) | Main client listeners |
|---|---|---|
| MeteorService | Impact :51, CoreCracked :52 | Atmosphere :91, Music :52, ImpactFX :179, MeteorFX :399/:465, SurfaceFX :487 |
| NodeService | OreGained :68 | Mining :518 |
| LevelService | LevelUp :25 | Feedback :54, HUD :240 |
| EconomyService | Sold :29, Notice :30 | HUD :494/:211, PetVisual :366, Feedback :83 |
| RefineryService | Deposited :21, Collected :22, WhileAway :23, Notice :24, Open :25 | HUD :189-210, Refinery :320-323, Feedback :33/:36/:83 |
| UpgradeService | Upgraded :18, Notice :19 | Feedback :41, HUD :212-213, Refinery :321 |
| ShopService | Purchased :34, Upgraded :35, Notice :36, Open :37 | HUD :216-217/:254, Shop :388-389, Feedback :45/:49/:83 |
| RewardService | Results :26, Announcement :28, Bonus :31 | HUD :148/:160/:251, Feedback :70 |
| PerkService | Notice :20, Bought :21 | Perks :117/:120, Feedback :83 |
| PetService | Notice :31, Leveled :32, Bought :33, Hatched :34, Working :35 | HUD :223-234, Pets :420-421, Hatch :307, PetVisual :346, Feedback loop |
| IndexService | Discovered :30 | Feedback :67, Index :238 |
| DailyService | Notice :25 | Daily :261 |
| RebirthService | Notice :30 | Rebirth :212 |
| MonetizationService | Notice :70, Supporter :71 | Store :304, HUD :230 |
| PlayerStateService | BackpackFull :31 | Feedback :74, HUD :186 |
| TelemetryService | MenuOpened :61 — the one client→server signal | fired `TelemetryController.luau:23`, listened server-side `TelemetryService.luau:406` |

Replicated state, as opposed to events, goes through Knit RemoteProperties: `MeteorService.State` (MeteorService.luau:50), `PlayerStateService.State` (:30), `TutorialService.Step`/`Intro` (TutorialService.luau:25/:27), `DailyService.Summary`/`TutorialDone` (DailyService.luau:24/:27), `MonetizationService.Owned`/`CallMeteor` (MonetizationService.luau:68/:69), `PlayerPolicyService.Policy` (PlayerPolicyService.luau:17), `ContributionService.Standing` (ContributionService.luau:26).

## State flow: profile → snapshot → client → back

1. **Storage.** DataService loads a profile under a session lock claimed in `UpdateAsync` (`DataService.luau` header :1-12; `claim` :161-186) and fires `ProfileLoaded` (:296) — the whole server treats that as "this player exists now". Autosave runs every 60 s (`AUTOSAVE_INTERVAL` :34, loop :361-369), leave releases via `_release` (:357-359), and `BindToClose` saves everyone (:371). Gameplay actions never write immediately; only receipt grants force a save before acknowledging (`MonetizationService.luau:343`).
2. **Rules.** `PlayerStateService` is the gameplay view of the profile (its header, :1-10): currency/pickaxe/backpack/hopper rules live here, storage does not. Anything that changes state calls `Replicate` (PlayerStateService.luau:197-198), which only marks the player dirty; a Heartbeat accumulator flushes dirty players at most once per `Config.Net.StateFlushInterval` — 0.2 s (`src/shared/Config/Net.luau:9`; loop at PlayerStateService.luau:522-527, `_flush` :323, `_sendState` :216 → `State:SetFor` :257). `ReplicateNow` (:204) skips the wait where the player is waiting on an answer.
3. **Snapshot.** The `State` table carries what the UI renders — `level`, `xp`, `pickaxeTier`, `backpackTier`, cash, shards, hopper, line rate, … (`PlayerStateService.luau:257-289`). Controllers render from the snapshot only (`ShopController.luau:391` is the canonical observer) and send intents through the service's `Client` remotes. A client number is never a fact: cash, tier and level come from the server's copy, not the call.
4. **Re-validation.** Every remote re-checks on server data: swing speed `pickaxe.Swing × Config.Meteor.SwingTolerance` (`NodeService.luau:277`) and range `pickaxe.Reach` (`:302`), with a RequestGate on the remote itself (`:368-371`; gate logic `src/shared/RequestGate.luau:12-26`); refinery Deposit/Claim require a living character near the refinery (`RefineryService.luau:247-249`, enforced at `:253`/`:262` — the 14-stud prompt at `:237` is only the convenience, not the check); shop buys re-clamp the payload (`ShopService.luau:193-205`), re-check the level cap (`:147`) and re-price every level (`:154`, `src/shared/Gear.luau:105-112`), and charge from `data.cash` against `Price.shortfall` (`:158`, `src/shared/Price.luau:35-43`). Receipts resolve the player from the engine receipt and dedupe by PurchaseId (`MonetizationService.luau:318-355`, `src/shared/Purchases.luau:158-170`).
5. **Back out.** Charge sites mutate `profile.Data` in place, call `ReplicateNow`, then fire the bus signals above — UI feedback, telemetry, tutorial and daily progress all ride those signals rather than the caller.

## Profile schema is versioned

The current schema `version` and every default live in `src/server/Lib/ProfileTemplate.luau` (its `version` field, :7 — read the file; this doc deliberately doesn't stamp the number). `DataService` migrates old profiles step by step in `migrate()` (`DataService.luau:84`, called at `:285`; the branches read `(data.version or 1) < n` — see :112, :119, :127). Adding saved data means: extend the template, bump the version, add a migration branch, and keep `src/server/Lib/RebirthReset.luau` (what survives rebirth) consistent. Full walkthrough in the profile-schema guide.

## Config is the only home for numbers; rules are `Shared.*`

`src/shared/Config/init.luau:17` onward collects the table modules (Meteor, Gear, Pickaxes, Backpacks, Pets, Levels, Rebirth, Monetization, Store, Hud, HudEdit, HudIcons, Daily, Codes, Badges, Net, …). Rules that read Config live in sibling pure modules — e.g. gear price curve and caps in `src/shared/Gear.luau:105-117`, rebirth multipliers in `src/shared/Rebirth.luau`, affordability in `src/shared/Price.luau`, meteor types in `Shared.MeteorTypes`, daily/quest math in `Shared.Daily` — which is exactly why each has a `tests/<Name>.spec.luau`. Menu sizing follows the same rule as pure `Shared.*Layout` modules plus `Shared.MenuFit`, and `Shared.Pacing` simulates a fresh player to fit the economy targets. Keep that split: tuning number → Config, reading rule → `Shared.*`.

`src/server/Lib/` is the server-side twin of the same idea: pure modules the services call — the profile template, the refinery simulation (`Refining`), shard reward math (`Rewards`), analytics helpers (`Telemetry`), rebirth inventory rules (`RebirthReset`), gear migration (`GearMigration`), admin give (`AdminGive`, `Admins`), badges and policies.

## Where to read next

- Economy model and pacing: the economy guide (rebuilt alongside this wave).
- Passes, products and receipt rules: the monetization guide.
- Menus and HUD editing: [native-ui.md](native-ui.md), [hud-editing.md](hud-editing.md), plus the HUD guide.
- Audio and the loading screen: [audio.md](audio.md), [loading-screen.md](loading-screen.md).
- Running the specs: `require(game.ServerStorage.Tests.Runner)()` in Studio Edit mode — see `tests/Runner.luau` and the testing guide.

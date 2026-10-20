# Loading screen

The cartoon sky that shows the instant a player joins, before any game content has arrived, and that destroys itself the moment the real game is ready to show. It is one self-contained LocalScript, `ReplicatedFirst.LoadingScreen`, mapped straight from `src/loading/LoadingScreen.client.luau` (`default.project.json:4-9`; the mapping is restated in `CLAUDE.md:11`). It removes Roblox's default screen on its first line (`LoadingScreen.client.luau:2`), builds its whole view from plain `Instance.new` objects so it can render before `Shared` even exists (`:4-6`), needs no Knit, Fusion or PlayerGui to build the view (`:6-418`, attach at `:490-495`), and on teardown disconnects everything, cancels its own threads, sets `LoadingDone` on the player and destroys its ScreenGui (`:452-461`). Everything tunable lives in config, and the pure maths (progress, easing, tips, finish decision) is a shared, spec-tested module.

## The set

| File | Job |
|---|---|
| `src/loading/LoadingScreen.client.luau` | the only `ReplicatedFirst` content: view construction (`buildView` `:6-418`, also evaluatable alone by Edit-mode preview tools, comment `:5`), the runtime loop, the watchdog and the teardown (`:420-627`) |
| `src/shared/LoadingProgress.luau` | pure logic: weighted monotonic stages (`:4-20`), easing (`:22-27`), status lines (`:29-42`), deterministic nonrepeating tips (`:45-52`), the finish decision (`:54-56`) |
| `src/shared/Config/Loading.luau` | timings, stage weights, art ids, status thresholds, tips (`:2-47`); exposed as `Config.Loading` (`src/shared/Config/init.luau:36`) |
| `src/shared/Config/HudIcons.luau` | the meteor and equipment art the screen reuses — the meteor sprites `:6-9`, the pickaxe icon `:13`; exposed as `Config.HudIcons` (`init.luau:37`); icons always come from this config (`CLAUDE.md:35`) |
| `tests/LoadingProgress.spec.luau` | guards the maths, including the completion-float roundoff regression (`:24-31`), high-water/clamps (`:32-44`), ease convergence (`:45-57`), status boundaries (`:58-66`), tip determinism/coverage (`:67-81`) and the min-show/deadline finish rule (`:82-89`) — run it through the Studio Runner ([testing.md](testing.md)) |

The art side of the screen is briefed in [docs/art-pipeline/store-art-plan.md](../art-pipeline/store-art-plan.md) section 11 (`:280`, deliverable roster `:24`).

## What you see on a normal join today

A full white screen (owner, 2026-10-20) with the Meteor Mining Simulator logo (`Config.Loading.Wordmark`, source `assets/loading/logo-meteor-mining-simulator.png`) as big as fits between the top and the progress card, centred in that space with a gentle bob and a shine sweep every 5 s; its shape comes from `WordmarkAspect`. Underneath: the progress card (white body on a navy lip), the rotating tip on its gold chip and, after 2 s, a gold SKIP in the corner. A pickaxe icon (`Config.HudIcons.equipment`) rides the fill edge and swings. The status line steps through `Config.Loading.StatusThresholds` ("Waking up the crater..." → ... → "Ready!"). There is no background art and no animated scene: the old space/sky backgrounds, clouds, meteor flight and the block-built fallback island were removed (they live in git history before this change).

## How progress is computed

Five weighted stages sum to the bar (`Config.Loading.Weights`: engine .1, assets .25, world .35, state .2, hud .1):

| Stage | Fires when (`src/loading/LoadingScreen.client.luau`) |
|---|---|
| `engine` | `game:IsLoaded()` flips true, checked per frame |
| `assets` | each parallel PreloadAsync batch completes (see Preload strategy); forced complete at `AssetTimeout` |
| `world` | in four steps: the character exists (.25); the streamed map around it has stopped growing (part count within 160 studs unchanged for three 0.3 s checks) (.5); the client's Knit start resolved, signalled by the player attribute `ClientStarted` set in `src/client/Main.client.luau` (.75); `ContentProvider.RequestQueueSize` quiet (≤ 2) for three 0.2 s checks, i.e. the textures and meshes the map queued have downloaded (1). Forced complete at `WorldTimeout` |
| `state` | the local player's `HudReady` attribute flips true (`HUDController`, first replicated state snapshot) |
| `hud` | one further render frame after that, confirming the HUD had a chance to draw |

`LoadingProgress` clamps each stage, keeps a high-water mark and snaps a near-one total to exactly 1; the display eases toward the target without regressing. **What gates the reveal** is `shouldFinish(elapsed, total, MinShow, MaxShow - 0.65)`: all stages at 1 **and** `MinShow` passed, or the deadline. So the screen waits for engine + art + a drawn, streamed-in world + the profile snapshot + one HUD frame, never longer than `MaxShow`. The `world` stage is why the screen is longer on real connections: before it existed the map streamed in after the screen had gone. In Studio everything is local, so a Studio join still closes at `MinShow`.

## Preload strategy

Once `Shared` appears (polled by name, because `ReplicatedFirst` can run first) the script requires `LoadingProgress`, `Config.Loading` and `Config.HudIcons`, re-reads the numbers with clamps, and builds the preload list: the logo, `Config.Loading.Preload`, every `rbxassetid://` in `Config.HudIcons` (de-duplicated), then up to `PreloadLimit` (1500) MeshParts, SpecialMeshes, Decals, Textures, SurfaceAppearances and Sounds under `ReplicatedStorage.PetModels`, `ReplicatedStorage.MeshArt` and `SoundService`: what the menus and effects show. They are requested in parallel batches of 32 and waited on for at most `AssetTimeout` (12 s, clamped 0-12). The map itself is the `world` stage's job (with streaming most of it is not on the client yet when the list is built). If `Shared` never arrives or a require fails, the screen keeps its white page and text title until the deadline, silently.

## Timing, deadline and warnings

| Number | Value |
|---|---|
| Minimum display | 4 s (`MinShow`; skippable by SKIP) |
| Hard deadline | 35 s (`MaxShow`, clamped 0.65-45) |
| Fade budget | 0.65 s reserved inside the deadline (flash 0.15 + fade 0.5) |
| SKIP appears | after 2 s (`SKIP_AFTER`) |
| Tip rotation | every 3.5 s (`TipSeconds`), first swap at 4.5 s |
| Asset wait | 12 s (`AssetTimeout`) |
| World wait | 25 s (`WorldTimeout`) |

An independent watchdog polls every 0.05 s and force-finishes at the deadline even if `Shared`, PlayerGui, require, PreloadAsync or RenderStepped have stalled. Warnings are rare: once on timeout ("Startup deadline reached"), once on a render-loop error and once on a startup error; a clean finish and a skip are silent.

## Art and fallbacks

Only two images: the logo (`Wordmark`) and the pickaxe marker (`Config.HudIcons.equipment`). Until (or if never) the logo loads, the `Title` "METEOR MINING" with a blue `Ribbon` "SIMULATOR" stands in for it; `loaded()` checks `Image ~= ""` and `IsLoaded` without hiding the ImageLabel (a hidden one is never requested). The pickaxe simply stays blank until its icon loads.

## Skip, HoldLoading and ReduceEffects

- **SKIP** (visible after 2 s, `:294`) short-circuits the finish gate at once — past the minimum display and any unfinished progress — and dismisses through the normal flash-and-fade, with no timeout warning (`:529-533`). On phones, where the panel reaches the corner, it lifts above the panel instead (`:286-293`).
- **`HoldLoading`** — `ReplicatedFirst:GetAttribute("HoldLoading") == true` suspends *every* dismissal path: the watchdog (`:479`) and the finish/skip gate (`:529`) both check it first, so a held screen cannot even be skipped (`held()` `:467-469`). Nothing in `src` ever sets it; it is a developer screenshot hook you set from Studio itself (command bar or Properties) and **must clear afterwards** — the same recipe appears in the art brief's checklist ([store-art-plan.md](../art-pipeline/store-art-plan.md) `:346`, `:362`).
- **`ReduceEffects`** is read fresh every render frame (`:499`), so the Settings toggle applies mid-screen. It freezes the logo bob, the shine sweep, the gloss animation and the pickaxe swing, and swaps the flash+fade for a plain fade. It is one of the game-wide preference attributes written by the Settings menu's toggle rows (`src/client/NativeHudMenus.luau:17-24`, writer `:125-137`); the roster with all consumers is in [ui-hud.md](ui-hud.md), and the two sound rows in the same menu belong to the audio guide.

## The self-destruct contract

`cleanup()` (`:452-461`) is the whole handoff, and it is idempotent (guard `:453`): disconnect every tracked signal (`:455`), `task.cancel` every owned helper except whichever thread is calling (`:456-458`), set the player attribute `LoadingDone` (`:459`), then `gui:Destroy()` (`:460`). The `ReplicatedFirst` script instance is *not* removed — it has simply run to completion, holding nothing. Entry points: natural fade-out (`:504`), the watchdog (`:481`), a render-loop error and a startup error — the last two warn as well (`:541-547`, `:624-627`). `LoadingDone` is the signal the rest of the client waits for: `IntroController` holds the first-join "How to play" card until it is set so the intro never shows behind the loading screen (`src/client/Controllers/IntroController.luau:155-164`; the card itself is in [architecture.md](architecture.md)'s controller roster), and `DailyController` gates the once-per-session login popup on it too, with a 30 s patience cap (`src/client/Controllers/DailyController.luau:195-202`). Both attributes are client-side only — no server code reads them (grep, 2026-10-18).

## Layout rules worth knowing before editing

The ScreenGui is full-bleed on purpose: `IgnoreGuiInset` plus `ScreenInsets = None` so the art covers the notch and rounded corners on phones (comment `:434`, props `:433-435`), `DisplayOrder = 1000` keeps it above everything (`:436`), and `ResetOnSpawn = false` means a mid-screen respawn cannot re-trigger it (`:432`). "Compact" is any window under 700 px on *either* axis (`:262`): the panel caps at 720 px and 84% width (80% and 130 px tall when compact) and is bottom-clamped (`:263-267`); the logo caps at 1100 px and 38% width (70% when compact) but drops below its nominal 360 px minimum when the screen is simply narrow, and its top is kept below the Roblox top-bar band (`:268`, `:274`). Tips truncate with an ellipsis rather than wrap (`:218`). Every one of these is recomputed each frame from `root.AbsoluteSize` (`:261`), so resizing the window relays the screen live.

## Verifying changes to the screen

- The pure maths is spec-guarded: `tests/LoadingProgress.spec.luau` pins the weight sum, the completion roundoff at fractional weights, high-water monotonicity, easing, status boundaries and tip coverage (how to run it: [testing.md](testing.md)). Spec output here: not run (no Studio this session).
- Visual checks run in Edit mode with the screen held: set `HoldLoading`, build/attach the GUI, capture desktop plus a phone-sized viewport, and check the brief's acceptance list (logo/bar/tip legible, nothing under the top bar, panel ≤ width cap — [store-art-plan.md](../art-pipeline/store-art-plan.md) `:362`).
- The loader deliberately survives everything it cannot control: missing `Shared` (`:558-562`), missing or broken config modules (`:620-621`), stalled preloads (deadline `:603`), dead render loops (`:541-547`) — each has a coded fallback above. Real-device first-frame timing and replication latency stay unverified outside Play.

## Where to read next

- Controllers, signals and the state snapshot behind `HudReady`: [architecture.md](architecture.md).
- The HUD that takes over, and the preference attributes: [ui-hud.md](ui-hud.md).
- Studio specs and the Runner: [testing.md](testing.md); Studio dev attributes and screenshot practice: [dev-hooks.md](dev-hooks.md).
- The loading-art brief and upload checklist: [docs/art-pipeline/store-art-plan.md](../art-pipeline/store-art-plan.md) section 11; the in-game sounds that start around first join belong to the audio guide.

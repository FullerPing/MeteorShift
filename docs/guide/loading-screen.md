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

With the current config (`Showpiece = true`, `LogoBaked = false` — `Config/Loading.luau:20-21`) the owner's space background is the show (`:14-15` explains the intent): the picture fills the screen, the **live** logo floats above it at `LogoWide` `.5, .16` (`:22`; placed `LoadingScreen.client.luau:273-275`), and the animated clouds, the crossing meteor, its trail, the impact ring and the hero strip all stay switched off so nothing covers the art (`:323`, `:384-389`). Underneath sit the progress panel (white card on a navy lip, `:158-221`), the rotating tip on its gold chip (`:208-221`) and, after 2 s, a gold SKIP in the corner (`:226`, `:294`). A pickaxe icon rides the fill edge of the bar and swings (`:296-297`, fallback glyph `:204-207`). The status line steps through the thresholds "Waking up the crater..." → "Polishing the pickaxes..." → "Counting your ore..." → "Firing up the foundry..." → "Ready!" (`Config/Loading.luau:24-30`; consumed `:525`, final "Ready!" painted once at finish `:534`).

## How progress is computed

Four weighted stages sum to the bar (`Config/Loading.luau:7`: engine .15, assets .45, state .25, hud .15):

| Stage | Fires when (all cites `src/loading/LoadingScreen.client.luau`) |
|---|---|
| `engine` | `game:IsLoaded()` flips true, checked per frame (`:507-508`) |
| `assets` | each parallel PreloadAsync batch of the first-screen art completes (`:591-601`, fraction `:599`); forced complete at the AssetTimeout or when the list is empty (`:602`, `:604`) |
| `state` | the local player's `HudReady` attribute flips true (`:509-511`) |
| `hud` | one further render frame after that, confirming the HUD had a chance to draw (`:512-513`, comment `:511`) |

`LoadingProgress` clamps each stage, keeps a high-water mark and snaps a near-one total to exactly 1 (`LoadingProgress.luau:9-18`), the display eases toward the target without ever regressing (`:22-27`; monotonic target `:517-518`), and until the logic module even arrives the bar self-crawls to 12% while the status shows the fallback line (`:516`, `:525`, fallback tip `:446`).

**What gates the reveal** is one boolean: `shouldFinish(elapsed, total, MinShow, MaxShow−0.65)` — done when all stages are at 1 **and** the minimum display time has passed, or when the deadline hits (`LoadingProgress.luau:54-56`, called with the fade budget subtracted at `:527-528`). The `state` stage is the real handshake with gameplay: `HUDController` sets `HudReady` the moment the first replicated player-state snapshot exists (`src/client/Controllers/HUDController.luau:488` — i.e. the profile has loaded and is being rendered; snapshot pipeline in [architecture.md](architecture.md), saved-data lifecycle in [profile-schema.md](profile-schema.md)). So the screen waits for engine download + first-screen art + profile snapshot + one drawn frame, never longer than the deadline. When the HUD genuinely draws first on a real device is Studio/Play behaviour — unverified here (no Studio this session).

## Preload strategy

Once `Shared` has appeared — the script polls for `Shared.LoadingProgress`, `Shared.Config.Loading` and `Shared.Config.HudIcons` by name instead of assuming they are there (`:549-565`, because `ReplicatedFirst` can run first) — it requires them, re-reads the config numbers with clamps (`:571-575`), swaps in the 14 real tips (`:575`; `Config/Loading.luau:31-46`) and hands `view:setAssets` the art ids (`:577`; assignment table `:240-254`). The preload list is: the four loading-art ids, then `Config.Loading.Preload` (currently empty, `:23`), then every image id in `Config.HudIcons` — de-duplicated, and only `rbxassetid://` strings count (`:578-590`). They are requested all at once in parallel batches of 8 (`:592-601`) — deliberately not one by one (comment `:587-588`). The screen waits for the batches at most `AssetTimeout` (5 s — `Config/Loading.luau:6`; clamped 0–12 at `:574`) and then completes the `assets` stage anyway (`:603-604`); the stragglers are owned threads and die with the cleanup (`:462-466`, `:456-458`). Pet and mesh art are *not* waited on: up to 300 MeshParts under `ReplicatedStorage.PetModels`/`MeshArt` are warmed in an unowned `task.spawn` that intentionally outlives the screen (`:605-618`). If `Shared` never arrives or a require fails, the screen simply keeps its built-in fallbacks until the deadline, silently (`:620-621`).

## Timing, deadline and warnings

| Number | Value | Where |
|---|---|---|
| Minimum display | 1.5 s (skippable by SKIP) | `Config/Loading.luau:3`; clamp `:572`; gate `LoadingProgress.luau:54-56` |
| Hard deadline | 20 s (config-read, clamped 0.65–25) | `Config/Loading.luau:4`; `:571` |
| Fade budget | 0.65 s reserved *inside* the deadline (flash 0.15 + group fade 0.5) | `:527-528`; fade `:500-505` |
| SKIP appears | after 2 s (`SKIP_AFTER`) | `:226`, visibility `:294` |
| Tip rotation | every 3.5 s, first swap at 4.5 s, cross-fade in/out | `Config/Loading.luau:5`; `:447`, `:519-524` |
| Asset wait | 5 s, meshes exempt | `Config/Loading.luau:6`; `:603`, `:605-618` |

An independent watchdog polls every 0.05 s and force-finishes at the deadline even if `Shared`, PlayerGui, require, PreloadAsync or RenderStepped have all stalled — it shares none of them (comment `:476`; loop `:476-486`). Warnings are deliberate and rare: once on timeout ("Startup deadline reached", `:470-475`, `:533`), once on a render-loop error (which also cleans up, `:541-547`) and once on a startup error (`:624-627`); a clean finish and a player skip are silent (`:531-533`).

## Three background modes, one screen

The view has one body and three personalities, keyed off two config flags plus whether the background has actually loaded (`:302-305`). The feature commit `9b93170` (11 Oct 2026) states the motive for the second mode: "The sky background has the logo painted in, so a LogoBaked flag hides the live logo and clouds and the meteor flies across the whole screen with a larger trail instead of landing." Commit `cc6c56d` (15 Oct 2026) then moved the live config to the third mode.

- **Crater landing (default — neither flag set).** The background renders `Crop`-centred (`:64-65`); every 4.1 s a meteor dives from the top-right into the crater spot, given as a fraction of the source image and mapped through the crop scale to screen pixels (`:329-341`, `:351`), with an expanding gold ring (`:93-98`, `:370-374`), six flying chips (`:99-105`, `:375-381`) and a logo shake on impact (`:269-271`). `Crater` and `LogoWide` in config steer it (recipe in the `Config/Loading.luau:17-18` comment).
- **`LogoBaked` painted-logo sky.** While the baked background is loaded (`:302-303`), the live logo (`:306`) and clouds (`:323`) hide, and the picture is switched from Crop to cover-the-screen, pinned to the top — because Crop would slice a painted logo off on wide phones (rationale `:307-308`; code `:309-316`). The meteor then **flies across the whole screen instead of landing** (`:335-337`): bigger, with a 6× trail, straight corner-to-corner until the tail has left too (`:340-351`), no ring/chips/shake (`:371`, `:376`, landing test `:270`); the empty middle hosts a hero strip cycling all four meteor types every 1.6 s on a turning sunburst, sized to stay clear of the painted logo (≈ its lower third, `:394`), with pop-in overshoot (`:126-157`, `:239`, `:382-415`, sprites from `Config.HudIcons` `:248-253`). The old sky background was this kind of art; the config comment at `Config/Loading.luau:16-18` documents how to switch back.
- **`Plain` (current, owner 2026-10-20).** A full white screen with the Meteor Mining Simulator logo (`Wordmark`, source `assets/loading/logo-meteor-mining-simulator.png`) as big as fits between the top and the progress card, centred in that space with a gentle bob; its shape comes from `WordmarkAspect`. No background picture, island, clouds, meteor, trail or hero strip, and only the logo is preloaded. White is also the look before the config arrives, so the first frames never flash the blue sky. `Plain = false` brings back whichever mode below the other flags pick.
- **`Showpiece` art.** The background has its own centrepiece, so clouds (`:323`), the meteor, trail, ring and chips are all forced off (`:384-389`) and the logo shake is off (`landing = not Showpiece`, `:270`); the live logo rides above at `LogoWide` (`:273-275`) and the panel/tips/skip keep working. Flags: `Config/Loading.luau:19-22`.

## Art, ids and fallbacks

The four art slots are `Background`, `Wordmark`, `Cloud`, `Trail` — their uploaded image ids live only at `Config/Loading.luau:10-13` (Image IDs, filled by the owner; the comment at `:8-9` says uploads come from `assets/marketing/v2/loading/*.png`, and that folder — currently untracked in git — holds the PNG sources named in those comments). Empty, failed or still-loading art must never blank the screen: `loaded()` checks `Image ~= ""` and `IsLoaded` without ever hiding the ImageLabel itself (hiding it would stop the load — comment `:255-259`), and every slot has hand-built vector fallbacks:

| Slot | Built-in fallback (instance names in `buildView`) | Swap rule |
|---|---|---|
| `Background` | `FallbackIsland`: sky gradient + lagoon, isle, rampart and crater frames (`:48-63`) | island visible until the backdrop loads (`:301`) |
| `Wordmark` | `Title` "METEOR MINING" + blue `Ribbon` with "SIMULATOR" (`:109-117`) | hidden once the wordmark loads (`:317-319`) |
| `Cloud` | three rounded gradient frames with a puff each (`:66-77`) | shapes hidden per-cloud once its sprite loads (`:325-327`) |
| `Trail` | plain gold tapered frame (`:78-84`) | shape alpha ramps with the flight until the sprite loads (`:369`) |
| meteor / hero sprites | rounded rock with core and ink outline (`:86-92`, `:148-151`) | rock hides when the sprite loads (`:357-360`, `:413-414`) |
| pickaxe marker | `⛏` glyph label (`:204-207`) | hidden once the icon loads (`:300`) |

The meteor-type sprites and the pickaxe icon are deliberately the same `Config.HudIcons` images the HUD uses (`:245-253`; keys `Config/HudIcons.luau:6-9`, `:13`), so nothing loads twice and the preload covers both screens.

## Skip, HoldLoading and ReduceEffects

- **SKIP** (visible after 2 s, `:294`) short-circuits the finish gate at once — past the minimum display and any unfinished progress — and dismisses through the normal flash-and-fade, with no timeout warning (`:529-533`). On phones, where the panel reaches the corner, it lifts above the panel instead (`:286-293`).
- **`HoldLoading`** — `ReplicatedFirst:GetAttribute("HoldLoading") == true` suspends *every* dismissal path: the watchdog (`:479`) and the finish/skip gate (`:529`) both check it first, so a held screen cannot even be skipped (`held()` `:467-469`). Nothing in `src` ever sets it; it is a developer screenshot hook you set from Studio itself (command bar or Properties) and **must clear afterwards** — the same recipe appears in the art brief's checklist ([store-art-plan.md](../art-pipeline/store-art-plan.md) `:346`, `:362`).
- **`ReduceEffects`** is read fresh every render frame (`:499`), so the Settings toggle applies mid-screen. It freezes cloud drift, logo bob, shine sweeps, the gloss animation, the pickaxe swing, the flight, the ring/chips and the hero motion, and swaps the flash+fade for a plain fade (`:502-503`, `:271`, `:275`, `:295`, `:297`, `:320`, `:323`, `:352`, `:368`, `:371`, `:376`, `:400-414`). It is one of the game-wide preference attributes written by the Settings menu's toggle rows (`src/client/NativeHudMenus.luau:17-24`, writer `:125-137`); the roster with all consumers is in [ui-hud.md](ui-hud.md), and the two sound rows in the same menu belong to the audio guide.

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

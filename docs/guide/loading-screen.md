# Loading screen

`ReplicatedFirst.LoadingScreen` is a standalone LocalScript mapped directly from
`src/loading/LoadingScreen.client.luau`. It builds the sky, title, island silhouette,
progress panel and fallback sprites synchronously, then attaches to PlayerGui as
soon as it exists. There is no Knit dependency and no startup wait before building
the view.

`src/shared/LoadingProgress.luau` owns weighted, monotonic progress, easing, status
thresholds, deterministic nonrepeating tips and the finish decision.
`tests/LoadingProgress.spec.luau` exercises these contracts, including floating
point roundoff at completion. `src/shared/Config/Loading.luau` holds the 14 tips,
stage weights, status text, timings and image IDs; it is also exposed as
`Config.Loading`.

After the HUD is constructed, a single observer line in HUDController sets the
local player's `HudReady` attribute when player state exists. The loading screen
counts that as the state stage, then waits one further render frame for the HUD
stage. It sets `LoadingDone` on dismissal.

## Art and owner setup

The owner uploads these files as images and fills the corresponding empty config
strings with `rbxassetid://<IMAGE_ID>` (Image IDs, not Decal IDs):

| Config key | File under `assets/marketing/v2/loading/` |
|---|---|
| `Background` | `loading-bg.png` |
| `Wordmark` | `wordmark.png` |
| `Cloud` | `cloud.png` |
| `Trail` | `trail.png` |

Empty, failed or still-loading images keep their built-in fallback visible.
The existing meteor and equipment icons are reused from HudIcons. Loading art
is preloaded before other HUD icons and up to 300 MeshParts from PetModels and
MeshArt. Duplicate image IDs are omitted. Progress counts completed input items
because a MeshPart can contain several content references. Asset failures count
as attempted; after 12 seconds the remaining preload worker is cancelled and
the assets stage completes.

The owner must inspect uploaded image IDs, save the edited Studio place, and
approve a Play session before a real client startup check. Nothing was uploaded,
published, committed or pushed by this loading-screen implementation.

## Timing and accessibility

Default minimum visibility is 2.5 seconds. The independent watchdog uses the
25-second startup deadline even if Shared, Config, PlayerGui, asset loading or
the render callback stalls. Fade time is reserved inside that deadline. Cleanup
occurs at the next scheduler tick, destroys the ScreenGui, disconnects the render
connection and cancels remaining workers. Only failures/timeouts produce warnings.

A SKIP button appears in the lower right corner 4 seconds in (`SKIP_AFTER` in `buildView`). Pressing it
starts the normal dismissal (flash, fade, cleanup, `LoadingDone`) at once, ignoring the minimum visibility
and unfinished progress. On narrow screens, where the progress panel reaches the right edge, it sits just
above the panel's top-right corner instead. `HoldLoading` still suspends dismissal, so a held screen
cannot be skipped.

`ReduceEffects` is read every render frame, so changes apply immediately. It
disables cloud drift, bob, shine sweeps, pickaxe swinging, falling/impact effects
and dismissal flash, leaving a stationary meteor and simple fade.

`ReplicatedFirst:SetAttribute("HoldLoading", true)` is a developer screenshot
hook that intentionally suspends dismissal, including the watchdog. Clear it
after use. No HoldLoading attribute was left enabled during verification.

Desktop panels cap at 720 pixels and 84% viewport width. Compact layouts use up
to 92% width and 130-pixel height. Compact also includes narrow portrait phones,
even when their height exceeds 700 pixels. The logo shrinks below its nominal
360-pixel minimum if necessary to fit a narrow screen. Landscape placement keeps
its top below the top-bar area. Long tips intentionally use a single-line ellipsis.
The meteor's landing point accounts for the background image's Crop transform.

## Verification performed (Studio Edit mode, 2026-10-09)

- Confirmed the approved place ID `113476105600560`; baseline suite: **489 passed,
  0 failed**. New tests were observed failing before implementation, including a
  regression where decimal stage weights yielded `0.9999999999999999`.
- Final suite: **497 passed, 0 failed**. All owned Luau sources compiled in Studio.
  `rojo build default.project.json -o .tmp/loading-screen-verify.rbxl` succeeded.
- Captured actual built-in fallback GUI previews in Edit mode: desktop
  **1601×875** (`loading-desktop-1601x875-fallback-final`), portrait **390×844**
  (`loading-phone-390x844-fallback`), and landscape **844×390**
  (`loading-phone-landscape-844x390`). These capture identifiers refer to the MCP
  screenshots in the task, not files committed to the repository. Logo, status,
  percent and bar remained inside bounds; portrait tips truncated as intended.
- Verified live ReduceEffects toggling hides and restores cloud/motion effects.
- Executed the actual loader against isolated service boundaries in Edit mode
  with a 10× test clock: missing Shared plus PlayerGui, a stalled preload with a
  cloned `MaxShow = 4` config, and successful readiness. Each destroyed its GUI,
  disconnected its connection and left every worker dead. Deadlines were serviced
  at the next scheduler tick (about 25.6, 4.4 and 3.6 simulated seconds respectively).
  The real config stayed at 25 seconds.
- Synced only loader-owned sources and inserted the one-line Config and HUD
  changes into existing Studio sources. Studio HUD source differed from disk, so
  its other changes were preserved. Temporary previews and probe instances were
  removed.

**Limits:** Play mode was not used. Edit previews and isolated runtime checks do
not establish actual replication latency, first-frame visibility on a real
device, real asset-fetch timing, or the complete HUD/tutorial transition. Uploaded
loading artwork remains unverified until the owner supplies its image IDs.

# HUD (the Fusion interface)

The HUD is everything on screen during play that is not an opened menu: the meteor clock, the wallet, the backpack, the foundry/SELL card, the menu tiles, MINE/SPRINT/ORE, the settings gear, toasts, and the tutorial card. It is built with **Fusion** (`Packages/Fusion`), driven by replicated state, and placed by one pure module — this doc maps that pipeline. *How to move, hide or add HUD elements* is the owner tweak workflow in [hud-editing.md](hud-editing.md) (`Config/HudEdit`); this guide covers the architecture behind it.

## Where the boundary is

The game runs two UI systems side by side (CLAUDE.md:32-36). The HUD and the tutorial are Fusion: instance trees built in code, reactively bound to values (`src/client/HudView.luau`, `src/client/UI.luau`, `src/client/Controllers/HUDController.luau`). The internal menus (Shop, Pets, Foundry, Index, Rebirth, Store, Hatch, Settings, Backpack, Daily, Codes, ...) are native ScreenGuis bound by instance name — authored under `assets/native-ui/` and restyled on the way out. The HUD borrows from that world in exactly two places: the Settings and Backpack popups are native ScreenGuis positioned by `Shared.HudLayout` rects (`src/client/NativeHudMenus.luau:35-36,82-83,118-121`), and every menu *tile* on the HUD is authored or cloned through `ExactNavButton` (`src/client/ExactNavButton.luau:11-64`), which copies the owner's StarterGui design instead of reskinning it (`:2`). The native-menu workflow lives in the native menu guide (this wave is rewriting it); the HUD never uses it.

## Placement pipeline

```
Config/Hud.luau (numbers)  ──>  Shared.HudLayout.compute(viewport, touch, inset, expanded, notice?, reward?)  ──>  Layout (all rects)
        HudEdit.luau (owner tweaks)  ──────────────>  HudLayout.applyEdits  <──────────────────────────────────┘
UI.hud(scope)  (Fusion Computed)  ·  NativeUI.hudLayout()/onLayoutChanged (non-Fusion readers)  ──>  controllers place themselves
```

- **Numbers** live in `src/shared/Config/Hud.luau` (its header says "Read by Shared.HudLayout", `:4`): top-bar inset fallback 36 (`:10`), card scale references (`:14-20`), the 44 px minimum touch target (`:23`), button orders (`:29-30`), Roblox's jump-button geometry to keep clear of (`:102-106`), thumbstick area (`:108`), MINE sizing (`:112-131`).
- **One module owns the geometry.** `HudLayout.compute` (`src/shared/HudLayout.luau:118-602`) returns one `Layout` record of rects (`:41-80`); its header explains why — "One place decides the geometry, so buttons cannot silently overlap each other, the Roblox top bar, the thumbstick area or the jump button" (`:5-7`). CLAUDE.md:33's "one function" reads as this: `compute` is the single full-screen entry; the rest are pure helpers on its output (`jumpRect :113`, `offerSlots :609`, `backpackPanel :682`, `level :720`, `panel :743`, `closeSize :768`, `applyEdits :791`).
- **Two readers.** Fusion controllers call `UI.hud(scope)` — a `Computed` that recomputes on camera viewport, `TouchEnabled`, `GuiService` inset, and the `FoundryExpanded` / `HudNotificationActive` / `HudRewardNotificationActive` player attributes (`src/client/UI.luau:328-389`). Non-Fusion code (native menus, ExactNavButton callers) reads the identical layout through `NativeUI.hudLayout()` and re-places via `NativeUI.onLayoutChanged` (`src/client/NativeUI.luau:122-154`).
- **HudEdit is layered on top, once, inside the reader** — both readers wrap `compute` in `HudLayout.applyEdits(..., HudEditConfig)` (`UI.luau:387`, `NativeUI.luau:129-131`), so Fusion cards and native tiles follow the same moves and hides. The mechanism (hidden → offscreen at -4000, nudge → offset+scale) is `HudLayout.applyEdits` (`HudLayout.luau:791-818`); the element names are the header of `src/shared/Config/HudEdit.luau:8-20`.
- **The spec is the contract.** `tests/HudLayout.spec.luau` runs `compute` across 24 phone/tablet/desktop viewports (`:13-40`) and asserts the invariants the geometry exists to keep: every button ≥ 44 px (`:520`), buttons on screen, under the top bar, never overlapping each other (`:531`), clear of the clock and event card (`:550`), touch controls clear of thumbstick/jump/MINE (`:564`), the backpack popup clearing navigation captions (`:205`), `HudEdit` only touching named elements (`:791,801`), and the offer slots landing in clean grid cells (`:822-867`). It also pins `Shared.Aim`'s target picking (`:767-786`). Change numbers in `Config/Hud`, geometry in `HudLayout`, and keep the spec green — how to run it is in [testing.md](testing.md).
- **MenuFit is menu-side only.** The HUD never scales itself through `MenuFit`; menus derive their virtual screen from the HUD's own `viewport`/`inset` via `NativeUI.menuView` → `MenuFit.view` (`NativeUI.luau:157-159`). `HudLayout.panel`/`closeSize` (`HudLayout.luau:743-770`) are the HUD's own helpers for centred panels.

## Element roster

| Element | Drawn by (controller site) | HudLayout slot | HudEdit-tweakable name |
|---|---|---|---|
| Level badge (or medal on the wallet) | `HudView.main` frame "Level" (`HudView.luau:298-317`; inline medal `:335-339`) | `HudLayout.level` (`HudLayout.luau:720-736`; nil → inline) | `Level` |
| Wallet (shards + cash) | frame "Resources" (`HudView.luau:318-340`) | `leftCards.Resources` | `Wallet` |
| Foundry card + SELL | frame "Production" (`HudView.luau:341`, contents `:246-295`) | `leftCards.Production` | `Foundry` |
| Backpack card | frame "Backpack" (`HudView.luau:342-356`) | `layout.backpack` | `Backpack` |
| Backpack ore popup (native) | `NativeHudMenus.updateBackpack` (`NativeHudMenus.luau:81-114`) | `HudLayout.backpackPanel` (`HudLayout.luau:682-715`) | follows `Backpack` |
| Meteor clock (turns into the objective) | frame "Timer" (`HudView.luau:357-391`) + the map's `SkyTimer` board hydrated with the same computeds (`HUDController.luau:340-356`, see [map-and-world.md](map-and-world.md)) | `timer`, swapped to `objective` on phones in landscape (`HudView.luau:194-200`) | `Timer` |
| Event card (fallback when the clock is hidden) | `HudView.objective` (`HudView.luau:401-426`) | `eventPanel` / `eventVisible` | `EventPanel` |
| Tutorial card | `TutorialController` (`TutorialController.luau:371`, scale `:311-313`) | `tutorial` / `tutorialVisible` (`HudLayout.luau:587-588`) | — |
| Menu tiles SHOP/PETS/INDEX/REBIRTH/STORE | each menu's own controller: `ShopController.luau:392-395`, `PetsController.luau:425-428`, `IndexController.luau:175`, `RebirthController.luau:271`, `StoreController.luau:380` — all via `ExactNavButton.layout(button, hud, KEY)` (`ExactNavButton.luau:164-170`) | `buttons[name]` | `SHOP PETS INDEX REBIRTH STORE` |
| DAILY / CODES tiles | `DailyController.luau:187` / `CodesController.luau:54`, authored at runtime (`DailyController.luau:78`, `CodesController.luau:45`); when a row has no room the Settings menu's rows are the way in (`NativeHudMenus.luau:138-168`; placement rule `HudLayout.luau:186-193`) | `buttons.DAILY` / `buttons.CODES` | `DAILY` |
| Offers (2x Ore, 2x Cash, Starter Pack) | `OfferController.luau:29-33,48-72`; desktop climbs from INDEX (`:83-90`), phones take the free grid cells (`:89`) | `layout.offers` from `HudLayout.offerSlots` (`HudLayout.luau:526-533,609-676`; count = `Hud.OfferSlots`, `Hud.luau:55`); they vanish once owned and never draw for off-sale rows (Id 0, `OfferController.luau:60`) | `Offers` |
| Settings gear (+ Daily-ready dot) | `NativeHudMenus.luau:35,118-121,141-148` | `settings` | `Settings` |
| SPRINT | `FastWalkController.luau:68-80` | `fastWalk`; nil → self-places beside jump/backpack (`:76-78`) | `FastWalk` |
| ORE | `FieldTravelController.luau:39-44,52-63` (anchors to the SPRINT button) | `ore`; nil → above SPRINT | `Ore` |
| MINE (touch) | `MobileControlsController.luau:89-107` | `mine`, sized into the gap above jump (`HudLayout.luau:171-181,386-397`) | — (not in the HudEdit name list, `HudEdit.luau:8-20`) |
| Toast + reward line | `HUDController.luau:389-435` | `notification` (heights 48, or 64 for two-line reward lines — `HudLayout.luau:124`) | `Toast` (Nudge only — messages are never hideable, `HudEdit.luau:15`) |
| Custom additions | `CustomHudController.luau:41-78` (anchors, not layout rects) | none — anchored to screen edges | `HudEdit.Custom` |

The tiles deliberately share one geometry language: `ExactNavButton` keeps an 80 px authored face and a caption to y=105, and every consumer reserves the same "personal navigation" bounds (`HudLayout.luau:30-34`; spec `:45-48`). That is why DAILY/CODES/Offers can slot into the phone row grid without special cases.

## Data flow: snapshot → computeds → labels

Controllers never poll profile data; they render the replicated snapshot (the `State` story is in [architecture.md](architecture.md), "State flow"). Representative bindings, all in `HUDController.luau` unless noted:

1. **Cash.** `PlayerStateService.State:Observe` pushes the snapshot into a Fusion `Value` (`:140-142`); the wallet number is a 0.8 s count-up `Tween` over it (`:359-365`) rendered through `Format.cash` (`HudView.luau:323`; formatting is owned by `src/shared/Format.luau:1-4`, whose suffix table runs to the vigintillion, `:9-14`). On `EconomyService.Sold` the "+$" floater and the coin burst derive their geometry from the wallet's live rect (`:494-534`).
2. **Clock.** `MeteorService.State:Observe` (`:137-139`) plus a 10 Hz poll of `GetServerTimeNow` and the core's HP attributes (`:258-275`) feed the `phase`/`secondsLeft`/`timerTitle`/`timerColor` computeds (`:277-337`), which hydrate both the HUD Timer and the crater's saved `SkyTimer` board (`:340-356`) and the objective merge (`HudView.luau:149-170,357-391`).
3. **Backpack.** `carried`/`capacity` read straight off the snapshot (`HudView.luau:178-180`) into the meter, which turns red and the label flips to "FULL!" at capacity (`:345-349`); the popup's ore/bars rows come from the same snapshot through `HudResources` (`NativeHudMenus.luau:187-193`).
4. **SELL.** `canSell`/`sellTop` computeds (`HudView.luau:216-226`) drive the pulsing green button (`:235-242,265-293`); the click calls the `EconomyService:SellAll` remote (`HUDController.luau:113-121`) — the displayed bar value is a client-side quote, and the server re-prices on the real call.

Every number on screen is the server's copy: "every action is re-validated on the server ... Never trust a client number" (CLAUDE.md:26). MINE is the same story for mining: presentation only, every swing checked by `NodeService` (`MobileControlsController.luau:5-7`).

## Notifications and layout talk to each other

`HUDController:Toast(text, color, highlighted)` is the one door other controllers use for small messages (`HUDController.luau:48-56`); the controller itself wraps the service Notices and reward signals into timed toasts (`:171-256`). Toast, announcement and personal-reward values also flip the player attributes `HudNotificationActive` / `HudRewardNotificationActive` (`:130-135`), which are inputs of `HudLayout.compute` (`HudLayout.luau:118-124`): a live notification makes the layout reserve banner space, hide the clock on the tightest portrait screens, and shorten the banner (against the event card, or between the phone's menu and button columns) rather than let text land on movement controls (`:534-586`; spec `:418-502`). The single `Toast` label splits into two rows when a reward line is present (`HUDController.luau:392,414-435`).

Player preference attributes are the other HUD input: the Settings menu's switches (`NativeHudMenus.luau:17-24`) publish `HudShowGuide` (consumed by `TutorialController.luau:307-310`), `HudShowEventTips` (the clock/objective merge, `HudView.luau:188-190,420-424`), `ReduceCameraShake`/`ReduceEffects` (also honoured inside the HUD's own confetti and pulse, `HUDController.luau:63`, `HudView.luau:238`) and the music/sound switches (consumed by the audio side — see the audio guide).

## Icons

Every HUD icon id comes from `Config.HudIcons` — "Icons always come from `Config.HudIcons`" (CLAUDE.md:35); the table is `src/shared/Config/HudIcons.luau:4-32` (PNG sources kept under `assets/hud`, header `:2-3`). `UI.hudIcon` resolves names from it (`UI.luau:81-89`), meteor-clock art resolves the type's icon through `Shared.MeteorIcon` at the call sites (`HudView.luau:358-361,407-410`), and the tiles take their glyph from the same table (`ExactNavButton.luau:76`, `OfferController.luau:29-33` pass icon keys). Never add a hard-coded asset id to a controller.

## Studio dev helpers

Under `RunService:IsStudio()` the HUD builds two playtest buttons ("Meteor now", "Away 1 hour") whose visibility is read once from `Workspace.DevHudHelpersVisible` (`HUDController.luau:437-482`), and the native layout reader honours a `PreviewViewport` player attribute to lay menus out for a previewed screen size (`NativeUI.luau:124-127`). The full attribute roster is in [dev-hooks.md](dev-hooks.md). Once the first snapshot lands the controller sets the `HudReady` player attribute (`HUDController.luau:488`) — the loading screen waits on it (see the loading-screen guide).

## History in one paragraph

The current look is the cartoon HUD restyle — glossy `Cartoon` surfaces, boardless floating icons, boxless tile glyphs (`HudView.luau:2-5`; `ExactNavButton.luau:70-71`) — which replaced the earlier charcoal-and-studs era noted as stale even in CLAUDE.md:5. Traces of the old era remain on purpose: the HUD keeps the stud texture asset (`UI.luau:50-51`) and stays blue "independently of the menus' charcoal palette" (`UI.luau:43-44`), the retired authored cash counter is disabled on sight (`HUDController.luau:86-89`), and the Fusion-era tile builder `UI.hudButton` is still in `UI.luau:394-480` with no callers in `src` (grep-verified) — read it if you touch tiles, but the live path is `ExactNavButton`. Pre-restyle phone mockups are archived under `docs/archive/hud-export/`.

# Native menus

Every internal menu (Shop, Pets, Foundry, Index, Rebirth, Store, Hatch, Settings, Backpack, Daily, Codes, Perks, WelcomeBack) is a plain, script-free `ScreenGui` whose controls controllers bind **by instance name**. The main HUD and tutorial are the other UI system — Fusion, placed by `Shared.HudLayout` (the HUD guide, and [hud-editing.md](hud-editing.md) for per-element tweaks). This doc is the workflow for the native side: how a menu comes to exist at runtime, which copy wins, what restyles it, how it is sized, and the rules when changing one. Every structural claim carries a `file:line` checked against the tree on 2026-10-18.

## One menu, three sources

Each menu exists in up to three places, and the runtime decides which one it uses:

1. **Builder code** — `src/client/NativeMenus/<Name>.luau` exposes `build(): ScreenGui`; the contract comment is `src/client/NativeUI.luau:99` ("a place that has none yet gets one built from its NativeMenus module"). 13 builders: Shop, Pets, Refinery, Index, Rebirth, Store, Hatch, Settings, Backpack, WelcomeBack, Codes, Daily, Perks (self-verified `ls src/client/NativeMenus/`).
2. **StarterGui export** — `default.project.json:36-40` maps `assets/native-ui` straight into `StarterGui`; exactly eight `.rbxmx` exports are checked in there (self-verified `ls`), the repo backup of the authored copies.
3. **Runtime binding** — controllers fetch through `NativeUI.get`, `getOrBuild` or `getFresh` (`src/client/NativeUI.luau:86-113`) and never call a builder themselves except via the latter two.

The three fetchers (`NativeUI.luau`):

- `get(name, prepare)` waits up to 15 s for the ScreenGui to reach `PlayerGui` and asserts with "Run tools/build-native-ui.luau in Edit mode" if it never arrives (`:88-89`); runs `prepare` first, so a controller can swap or mark subtrees **before** styling (`:90`, comment `:84-85`); then applies the shared cartoon skin `MenuSkin.apply` (`:91`) and wires a click sound to every button (`:92-96`).
- `getOrBuild(name, build, prepare)` builds the module's menu into `PlayerGui` first when the place has no copy (`:100-104`).
- `getFresh(name, build, layout, prepare)` adds the freshness rule: a saved copy whose `MenuLayout` attribute is not the builder's current `LAYOUT` is destroyed and rebuilt (`:107-113`), so a redesigned builder always beats an old export.

The **binding-by-name contract** is why instance names are load-bearing. Controllers reach controls with `WaitForChild` on exact names — the Store fetches `StoreButton`, `Dimmer`, `Panel`, `Close`, `Subtitle`, `List`, `Tabs` (`src/client/Controllers/StoreController.luau:100-109`), the Rebirth menu fetches `Content`, `Compare`, `Requirement`, `Confirm` and more (`RebirthController.luau:53-69`). `NativeUI.bindOpen` expects a `Dimmer` on the ScreenGui and a `Panel/Close` under it (`NativeUI.luau:194-206`, also closing on Escape / gamepad B at `:202-204`). Renaming any of these breaks its controller with a `WaitForChild` hang or an assert; `MenuSkin` itself recognises a menu body by a name ending in `Panel` or by carrying a `Header` child (`MenuSkin.luau:302-306`).

## Layout marks: when the builder wins

Menu sizing/structure numbers follow the same house rule as everything else (Config is numbers, `Shared` is rules — see [architecture.md](architecture.md)): each builder carries a `LAYOUT` constant, "bumped when the controls change", and every copy it builds stamps that number as an attribute so old copies are recognisable at runtime. Two generations run side by side:

- **`MenuLayout` + `getFresh`** (newer). Menus built with `MenuTheme.menu` store `LAYOUT` as a generic `MenuLayout` attribute (`src/client/MenuTheme.luau:101`), and the consumer calls `NativeUI.getFresh`, which destroys a stale copy and rebuilds (`NativeUI.luau:107-113`). Users: `CodesController.luau:22`, `DailyController.luau:72`, `IndexController.luau:51`, `PerksController.luau:34`, `HatchController.luau:111`, Settings via `NativeHudMenus.luau:35`, WelcomeBack via `NativeWelcomeBack.luau:32`.
- **Named marks + Panel swap** (older, used on menus whose export also carries the owner's nav tile). The builder stamps a per-menu attribute — `ShopLayout` (`NativeMenus/Shop.luau:63`), `PetsLayout` (`NativeMenus/Pets.luau:73`), `RebirthLayout` (`NativeMenus/Rebirth.luau:49`), `StoreLayout` (`NativeMenus/Store.luau:73`), `RefineryLayout` (`NativeMenus/Refinery.luau:64`) — and the controller compares it in the `prepare` callback:
  - `ShopController.luau:40-51` swaps in the fresh `Panel` **and** `EvolvePanel` (and re-thins the dimmer to 20 % alpha, `:53-54`);
  - `PetsController.luau:42-52` swaps `Panel` + `Dimmer`;
  - `RebirthController.luau:41-52` and `StoreController.luau:85-98` swap `Dimmer` + `Panel`, dimmer first so the panel draws over it;
  - `RefineryController.luau:44-46` destroys the stale copy outright, before `getOrBuild` rebuilds it.

Swapping only the panel keeps the owner's nav tile, which is authored inside the same ScreenGui (`NativeMenus/Shop.luau:78` builds `ShopButton`; `NativeMenus/Index.luau:171` authors `IndexButton`). `BackpackMenu` has no mark at all — its builder defines no `LAYOUT` and `NativeHudMenus.luau:36` uses plain `NativeUI.get`; it is the last menu still built with the legacy charcoal authoring `NativeUI.menu` (`NativeMenus/Backpack.luau:9`; the charcoal palette survives at `NativeUI.luau:14-28`). Whenever a menu's **controls** change, bump its `LAYOUT` — the marks above are the only thing that replaces stale copies.

## The menu roster

Export = a checked-in file in `assets/native-ui/` (8 total; the other five are runtime-only by design — see the Refinery story below). Bound by = the file that fetches it.

| ScreenGui | Builder | Bound by | Export | Mark = LAYOUT |
|---|---|---|---|---|
| `GearShop` | `NativeMenus/Shop.luau` | ShopController.luau:40 | `GearShop.rbxmx` | `ShopLayout` = 9 (`Shop.luau:15`) |
| `PetsMenu` | `NativeMenus/Pets.luau` | PetsController.luau:42 | — | `PetsLayout` = 4 (`Pets.luau:16`) |
| `RefineryMenu` | `NativeMenus/Refinery.luau` | RefineryController.luau:46 | — (archived, see below) | `RefineryLayout` = 4 (`Refinery.luau:14`) |
| `MineralIndex` | `NativeMenus/Index.luau` | IndexController.luau:51 | `MineralIndex.rbxmx` | `MenuLayout` = 3 (`Index.luau:23`) |
| `Rebirth` | `NativeMenus/Rebirth.luau` | RebirthController.luau:41 | `Rebirth.rbxmx` | `RebirthLayout` = 6 (`Rebirth.luau:15`) |
| `Store` | `NativeMenus/Store.luau` | StoreController.luau:85 | `Store.rbxmx` | `StoreLayout` = 4 (`Store.luau:14`) |
| `PetHatch` | `NativeMenus/Hatch.luau` | HatchController.luau:111 | `PetHatch.rbxmx` | `MenuLayout` = 3 (`Hatch.luau:13`) |
| `HudSettings` | `NativeMenus/Settings.luau` | NativeHudMenus.luau:35 | `HudSettings.rbxmx` | `MenuLayout` = 3 (`Settings.luau:13`) |
| `BackpackMenu` | `NativeMenus/Backpack.luau` | NativeHudMenus.luau:36 | `BackpackMenu.rbxmx` | none |
| `WelcomeBack` | `NativeMenus/WelcomeBack.luau` | NativeWelcomeBack.luau:32 | `WelcomeBack.rbxmx` | `MenuLayout` = 3 (`WelcomeBack.luau:11`) |
| `CodesMenu` | `NativeMenus/Codes.luau` | CodesController.luau:22 | — | `MenuLayout` = 3 (`Codes.luau:10`) |
| `DailyMenu` | `NativeMenus/Daily.luau` | DailyController.luau:72 | — | `MenuLayout` = 2 (`Daily.luau:14`) |
| `ColonyPerks` | `NativeMenus/Perks.luau` | PerksController.luau:34 | — | `MenuLayout` = 3 (`Perks.luau:16`) |

Codes, Daily and Perks are not even in the authoring tool's rebuild list (`tools/build-native-ui.luau:5` names ten builders), so they only ever exist as runtime builds; `CodesMenu`, `DailyMenu`, `ColonyPerks`, `PetsMenu` and `RefineryMenu` therefore have no export that could go stale. Settings and WelcomeBack are started from `HUDController` — `NativeHudMenus.start()` and `NativeWelcomeBack.start(...)` (`HUDController.luau:489-490`) — not by their own Knit controllers.

## Styling layers

Three layers decide how a menu looks; restyle here, not in controllers.

**`MenuSkin` restyles on the way out.** Every `NativeUI.get` hands the controller a skinned menu (`NativeUI.luau:91`). The prefabs keep their names, layout and bindings; `MenuSkin.apply` only repaints them (`src/client/MenuSkin.luau:5-6`):

- panel → white body, thick blue border, ink outline (`skinPanel` `:235-246`);
- header → a tilted glossy ribbon poking out top-left, sized from the title text (`skinHeader` `:248-300`);
- buttons → gloss, ink border and a mirrored text label (`skinButton` `:199-212`, `mirrorText` `:166-193`); bars become pills (`isBar` `:195-197`).

It is idempotent and clone-safe: a `CartoonSkinBound` guard per gui (`:371-372`), a `CartoonSkin` attribute per node (`:322-323`), and a `DescendantAdded` rebind so runtime-cloned templates are skinned too (`:378-386`).

**Colours are remapped by value — edit the palettes, not the controllers.** The old charcoal theme's colours live in `NativeUI.luau:14-28` (PANEL 43,44,49, CARD 67,69,77, CYAN, GREEN, RED …). `BUTTON_COLORS` and `TILE_COLORS` map each old value to the cartoon palette (`MenuSkin.luau:36-55`); `remap` rewrites the colour once on sight (`:155-158`) and `watch` re-maps every later assignment forever (`:160-162`, wired at `:210` for buttons and `:232` for tiles) — that is what catches the "tab active/inactive, disabled" repaints controllers still make after the skin is on. The legacy `NativeUI.enable` (`NativeUI.luau:114-121`) is one such assignment source; it has no callers in `src` today (self-verified grep). Menus migrated to `MenuTheme` paint through `Theme.state` / `Theme.tab` / `Theme.select` instead (`MenuTheme.luau:206-218`; call sites `CodesController.luau:61`, `IndexController.luau:119`, `HatchController.luau:163`).

**`MenuTheme` + `CartoonCustom` is the opt-out.** The "cartoon light" look from the owner's 2026-10-13/15 mockups is drawn, not skinned. `MenuTheme` builds:

- the navy-slab panel whose `Body` child carries the white-to-pale-blue gradient and a 7 px lip (`MenuTheme.luau:78-92`, `LIP = 7` `:82`);
- the blue title ribbon (`ribbon` `:222-238`) and the red corner Close (`closeCorner` `:241-249`);
- wallet chips (`chip` `:252-263`), pills (`:144-153`), wells (`:267-279`), bars (`:282-289`), cards (`:120-132`, `:297-315`);
- chunky buttons whose navy frame is the outline and lip while a `Face` child holds the gradient plus a gloss band (`button` `:158-183`; the per-kind faces and text colours are `KINDS` `:22-31`).

Everything it makes sits under a frame marked `CartoonCustom = true` (`panel` sets it at `:85`), and `MenuSkin` skips that subtree entirely (`MenuSkin.luau:317`) — along with the owner's tile parts `Design`, `CartoonTile`, `Tooltip`, `ReadyBadge`, `Dimmer` and any `Skin*` decoration (`:314-315`). Every current builder panel is a `MenuTheme.panel` (Shop `:67`, Pets `:76`, Rebirth `:67`, Store `:88`, Refinery `:68`), so the MenuSkin ribbon/panel path now mainly restyles the Backpack popup and any hand-authored copy. The colours themselves all live in `src/shared/MenuPalette.luau` (navy `:11`, the cartoon-light block `:44-98`), and its WCAG contrast pairs (`:116-160`) are checked by `tests/MenuPalette.spec.luau:13-14` — change looks here, not per controller. `src/client/Cartoon.luau` is the shared glossy-surface kit behind the HUD and these layers (`:1-11`). Two gotchas are code-commented: a `UIGradient` multiplies with the object's own colour, so `MenuTheme.gradient` sets the object white and lets the gradient carry the colour (`MenuTheme.luau:43-49`; same rule in CLAUDE.md "Studio and Windows gotchas"), and panel children must sit at ZIndex ≥ 2 to draw over `Body` (`MenuTheme.luau:78-81`).

## Sizing: MenuFit and the layout modules

Menu geometry is pure modules with specs, like the rest of `Shared`: `MenuFit`, `EquipmentShopLayout`, `PetsLayout`, `StoreLayout`, `RebirthLayout`, `RefineryLayout`, `IndexLayout`, `HudLayout` and `SurfaceLayout` in `src/shared/`, each with a `tests/<Name>.spec.luau` (self-verified `ls`). Change numbers there, never in a controller.

`Shared.MenuFit` is the small-screen rule (`src/shared/MenuFit.luau:2-4`): lay the menu out for a larger **virtual** screen and draw it down with a `UIScale` on the panel, so a phone shows the whole menu instead of a cramped slice of a desktop layout.

- Landscape below 860x460 or portrait below 420 wide draws smaller, never below 0.7 (`:10-12`); a screen bigger than 1080p lays out at 1080p and draws up, to 3x (`:13-14`); `view` computes the virtual rect (`:18-26`).
- `centred` reserves 28 px above the panel for the ribbon and 15 px below for the lip (`RibbonRoom`/`FootRoom` `:15-16`, `:35-40`); `whole` shrinks further so a fixed dialog is shown undiminished (`:44-50`).
- Runtime side: `NativeUI.menuView` / `place` (adds the `MenuFit` `UIScale`, `src/client/NativeUI.luau:157-172`) and the conveniences `fitCentred` / `fitWhole` (`:174-193`), which first destroy any authored `UISizeConstraint` that would fight the draw scale (`:176-178`, `:186-188`). Codes and WelcomeBack use `fitWhole` (`CodesController.luau:24`, `NativeWelcomeBack.luau:53`); Daily, Perks and Settings use `fitCentred` (`DailyController.luau:81`, `PerksController.luau:36`, `NativeHudMenus.luau:39`).

The Gear Shop and Pets share one frame ("layout parity" in CLAUDE.md), and the code matches CLAUDE.md's prose as of 2026-10-18:

- `EquipmentShopLayout.WIDE_W/WIDE_H = 760, 501` with the ribbon poking `RIBBON = 26` px above the body (`src/shared/EquipmentShopLayout.luau:31-33`; the wide panel rect is `501 − 26 = 475` tall at `:55`, matching CLAUDE.md's "body 760x475 plus the 26 px ribbon");
- drawn at 64.17 % of screen width or 75.19 % of height, whichever is smaller (`WIDE_FRACTION` `:32`, `view` `:39-47`) — CLAUDE.md's "64% / 75%";
- below a 0.75 scale (`WIDE_MIN_SCALE` `:34`) the frame is abandoned for the 560-wide single column (`SINGLE_W` `:35`) fitted by `MenuFit`;
- the builders author the body at 760x475 (`Shop.luau:67`, `Pets.luau:76`, `Rebirth.luau:67`), and Pets reuses the Gear Shop's decision verbatim: `PetsController.luau:64-65` calls `EquipmentShopLayout.view` then `PetsLayout.compute(viewport, inset, wide)`, and `PetsLayout` reads `WIDE_W/WIDE_H/RIBBON` from `EquipmentShopLayout` directly (`src/shared/PetsLayout.luau:36-39`).

Fixed natural sizes of the single-design menus:

| Menu | Size | Cite |
|---|---|---|
| CodesMenu | 560x400 | `Codes.luau:11` |
| DailyMenu | 660x640 | `Daily.luau:15` |
| ColonyPerks | 860x572 | `Perks.luau:17` |
| HudSettings | 600x540 | `Settings.luau:14` |
| PetHatch | 540x520 | `Hatch.luau:14` |
| WelcomeBack | 560x470 | `WelcomeBack.luau:12` |
| RefineryMenu | 860x572 (short variant < 520 tall) | `src/shared/RefineryLayout.luau:15-16`, `:25-32` |
| Store | 900x680 | `Store.luau:88` |
| BackpackMenu | 230x128 | `Backpack.luau:9` |

Menu placement follows the HUD's own tweaks: `NativeUI.hudLayout` computes `Shared.HudLayout` for the current viewport and applies `Config.HudEdit` (`NativeUI.luau:122-131`), and a `PreviewViewport` Vector2 attribute makes Studio QA lay menus out for an arbitrary touch screen (`:124-127`, see the dev-hooks guide).

## The owner's nav tiles

Each full menu's ScreenGui also owns its HUD button (`ShopButton` built at `NativeMenus/Shop.luau:78`; `IndexButton` authored at `NativeMenus/Index.luau:171`; `PetsController.luau:56` authors `PetsButton`). `src/client/ExactNavButton.luau`:

- `author` clones the owner's design from `StarterGui["MY index button"].Frame` when authoring (`:11-17`);
- at runtime every tile is redrawn as an 80x80 `CartoonTile` with a `Config.HudIcons` glyph and an ink-outlined caption (`cartoonTile` `:79-115`), hidden and untappable while any full menu is open, tracked through the twelve `*Open` player attributes (`MENU_ATTRIBUTES` `:10`, hide logic `:134-146`);
- `ExactNavButton.layout` positions a tile from `Shared.HudLayout`'s `buttons[key]` and scales it by `w / 80` (`:164-170`).

`MY index button` itself has no repo export (self-verified `find` over `assets/` — the eight `.rbxmx` are the only StarterGui-synced files); it lives in the place file, and the build tool keeps it `Enabled = false` so an unwired duplicate never shows (`tools/build-native-ui.luau:35-36`).

## Workflow: add a control, rebuild, export

1. **Edit the builder** in `src/client/NativeMenus/`, give the control a stable name (the controller binds by that name), and **bump `LAYOUT`** if the control set changed. Re-running the tool replaces the generated menus (`tools/build-native-ui.luau:3`), so changes that must survive rebuilds belong in builders, not in direct Studio edits.
2. **Regenerate in Studio Edit mode**: run `tools/build-native-ui.luau` (`:1-3`: "Run in Studio Edit mode after syncing source. Build once, then edit StarterGui."). It rebuilds the ten generated menus into `StarterGui` (`:5-23`), (re)authors the five nav tiles for GearShop, MineralIndex, Rebirth, Store and PetsMenu (`:26-34`), and keeps the owner's source disabled (`:36`). Codes, Daily and Perks are not in the list — they only exist as runtime builds.
3. **Export the repo copy** for the eight exported menus: capture the Studio ScreenGui hierarchy and run `node tools/export-native-ui.cjs schema.json assets/native-ui` (`tools/export-native-ui.cjs:44`), which writes one `<name>.rbxmx` per ScreenGui root from the property dump (`exportSchema` `:30-40`). A place edit alone does not update the export.
4. **Refresh in-play copies where the mark can't help**: the marked menus self-heal (`getFresh` and the Panel swaps above), but `BackpackMenu` has no mark — re-run the tool or delete it. The Foundry likewise: after editing `NativeMenus/Refinery.luau`, replace `StarterGui.RefineryMenu` from `build()` or delete it.

**The RefineryMenu exception, and why there is no RefineryMenu.rbxmx.** The Foundry window is deliberately absent from `assets/native-ui`: the old export went stale and Rojo kept restoring it over the redesign (CLAUDE.md's account), so it was moved out in commit `4a2b711` ("Update native UI exports … archive stale prefabs") and now sits at `assets/archive/stale-native-ui/RefineryMenu.rbxmx` (self-verified `git show --stat` + `ls`). The controller still recognises a pre-redesign copy in a place and destroys it (`RefineryController.luau:44-46`). Running the authoring tool does still place a fresh `RefineryMenu` in `StarterGui` (`tools/build-native-ui.luau:5`) — just never export that one back into `assets/native-ui`.

## Where to read next

- Repo map and Knit wiring: [architecture.md](architecture.md). HUD placement: the HUD guide and [hud-editing.md](hud-editing.md). Studio dev hooks (including `PreviewViewport`): [dev-hooks.md](dev-hooks.md). Running the layout specs: the testing guide. The world/`StarterGui` split (Rojo never touches `Workspace`): the map-and-world guide.

# Editable native menus

The internal menus are plain, script-free ScreenGuis authored in StarterGui. Their XML exports belong in `assets/native-ui/*.rbxmx`, which `default.project.json` maps into StarterGui. Runtime controller code stays in `StarterPlayerScripts.Client`: it obtains the replicated PlayerGui prefab through `NativeUI.get(name)`, binds named controls and updates native properties from service state. The main HUD and tutorial still use Fusion.

`src/client/NativeUI.luau` provides plain `Instance.new` authoring helpers and the runtime binding/layout helpers. Each module in `src/client/NativeMenus` exposes `build(): ScreenGui`; the authoring tool calls these builders in Studio Edit mode. Controllers use the authored menus rather than invoking builders during play. Dynamic lists use their authored templates, and shop/hatch previews retain their model content.

| Builder | StarterGui ScreenGui |
|---|---|
| `Shop` | `GearShop` (pickaxe and backpack only: name, preview, level and stat card, quantity strip and Upgrade; the next evolution is the `EvolvePanel` column on the panel's right, or stacks under the controls on a narrow screen) |
| `Pets` | `PetsMenu` (PETS, EGGS and INDEX tabs) |
| `Refinery` | `RefineryMenu` |
| `Index` | `MineralIndex` |
| `Rebirth` | `Rebirth` |
| `Store` | `Store` |
| `Hatch` | `PetHatch` |
| `Settings` | `HudSettings` |
| `Backpack` | `BackpackMenu` |
| `WelcomeBack` | `WelcomeBack` |

These ten menus and the owner's `MY index button` source form the ten ScreenGui exports. Keep their instance names and the named controls used by controllers when editing them.

`GearShop`, `PetsMenu` and `Rebirth` carry a layout mark attribute (`ShopLayout`, `PetsLayout`, `RebirthLayout`, equal to the builder's `LAYOUT`). When the saved copy lacks the current mark, its controller swaps in the `Panel` the builder makes (keeping the owner's nav button), so editing the builder is enough; bump `LAYOUT` when controls change.

`PetsMenu` is not yet authored in StarterGui: `PetsController` builds it at runtime with `NativeUI.getOrBuild("PetsMenu", Pets.build)` when the place has no authored copy. No PetsMenu export is checked in under `assets/native-ui` today, so the runtime build is what ships when the place has no authored copy. Run `tools/build-native-ui.luau` in Studio Edit mode to author it (and the PETS nav button) into StarterGui, then export it into `assets/native-ui`. Layout maths lives in `Shared.PetsLayout`.

`RefineryMenu` is titled **Foundry**. Its REFINE page is a three-card production line (ore hopper, foundry, finished bars) with Deposit and Claim buttons that carry the amount, meters, an arrow flow and the refining order below; phones and short windows fall back to two cards plus a status line (`Shared.RefineryLayout.compute(height, width)` picks `flow`). The UPGRADES page shows the wallet as two chips above the station view. `RefineryMenu` is no longer exported to `assets/native-ui`: the old export was stale and Rojo kept restoring it over the redesign (it is archived in `assets/archive/stale-native-ui/`). `RefineryController` uses `getOrBuild`, so a place without an authored copy builds it from `NativeMenus/Refinery.luau`; after editing that module, replace `StarterGui.RefineryMenu` from `require(Refinery).build()` (or delete it) to refresh the place.

`Store` is one scrolling page of titled sections (`Config.Store.Sections`: passes, shards, meteors, cash, boosts, pets, support) with a tab strip on the right that jumps to a section. Cards are "tile" (icon on top, 3 across) or "wide" (icon left, 2 across; a lone wide card is a full-width banner), coloured by section; `Shared.StoreLayout` does the sizing for phones, short landscape screens (icon-only tabs) and desktop. The authored `StarterGui.Store` keeps the owner's STORE nav button, but `StoreController` swaps its `Panel` for the one `NativeMenus/Store.luau` builds whenever the copy's `StoreLayout` attribute is older than the builder's `LAYOUT`, so editing the builder (and bumping `LAYOUT`) is enough. Setting the player's `StoreOpen` attribute opens it from other controllers. Every pass and product must be in exactly one section or in `Config.Store.Elsewhere` (tests/StoreLayout.spec); Rebirth and Keep Everything is the only one elsewhere (the "Rebirth, keep everything" button in the Rebirth menu). 2x Ore, 2x Cash and the Starter Value Pack also have small round buttons stacked above INDEX (`OfferController`, hidden once owned) that open the Store.

## Menu appearance

Menus use charcoal studded bodies, bright accent headers, modest rectangular cards, thick near-black outlines, white outlined FredokaOne headings/actions and red X close buttons. Body copy uses GothamMedium. The shared native surface helper adds one passive tiled ImageLabel per surface, using `rbxassetid://6927295847` with a 128 × 128 tile size. It sits behind content and does not receive input.

**The Gear Shop is the exception: it uses the light "toy" look** (a translucent pale body, a sky-blue header bar, one grey-blue card, pale preview wells, an orange evolution banner, navy outlines with a thick lip under each chunky button, FredokaOne text, lime for the selected quantity and for buttons you can press, a plain pale face for ones you cannot). The colours are in `Shared.MenuPalette` (with the contrast pairs `tests/MenuPalette.spec.luau` checks), the builders in `src/client/MenuTheme.luau`. `Panel` and `EvolvePanel` carry the attribute `CartoonCustom = true`, which `MenuSkin` skips, so the other menus keep the cartoon skin until they are moved over one at a time. It is a copy of the owner's Framewisp "Gear-Shop-Light" frame: one 760 x 501 panel drawn at 64% of the screen's width or 75% of its height, whichever is smaller (`EquipmentShopLayout.view`), with the evolution as its right column (`ShopController` parents `EvolvePanel` into `Panel` on a wide window). Screens too small for that (the scale would be under 0.75) get a single 560-wide column fitted by `MenuFit`, with the evolution stacked under the controls. The panel body is 72% opaque (`MenuPalette.BODY_ALPHA`) and the screen behind the menu is dimmed at 20% alpha (`Dimmer`, transparency 0.8). The next evolution's cost is on the EVOLVE button ("EVOLVE · $250"), so the body has two requirement rows (gear level with a progress bar, player level) and no Cost row.

The prefab exposes the visual properties directly in Studio. Controllers still own live text, quantities, availability, selection, visibility and responsive positioning; changes to those properties can be replaced by a runtime refresh. Button design does not change server purchase, inventory or progression rules.

## Owner navigation component

`src/client/ExactNavButton.luau` (the Index, Rebirth and Store prefabs no longer carry the "Design" frame: their icon and caption come from `Config.HudIcons` and a table in that file) clones the layers under `StarterGui["MY index button"].Frame` into the Gear, Index, Rebirth and Store button wrappers. It removes only the source canvas offset, changes the caption, and substitutes configured icons for the three non-Index buttons. It retains the original blue face, texture, fonts, outlines and shadow. The source ScreenGui stays editable with `Enabled = false`, preventing an unwired duplicate from appearing during play.

| Source detail | Authored value |
|---|---|
| Blue stud face | 80 × 80 px |
| Icon | 65 × 65 px |
| Caption | FredokaOne, 30 px; 164 × 54 px at (−42, 51) relative to the face |
| Outlines and shadow | Original square layers and 4.11 values preserved exactly |
| Index icon | `rbxassetid://127110909372919` |
| Stud texture | `rbxassetid://6927295847` |

The caption extends to 105 px below the face's top. `ExactNavButton.layout(button, hud, key)` positions the wrapper from `Shared.HudLayout` and scales the complete component by `layoutRect.w / 80`, preserving the authored relative geometry, font and strokes. Readiness badges and hover tooltips are separate bindings. Gear, Rebirth and Store currently take their icons from `Config.HudIcons`; those icon choices await the owner.

## Editing and rebuilding

Edit StarterGui in Studio Edit mode. PlayerGui changes made during Play are temporary. To keep direct visual edits in the repository, export each changed ScreenGui as XML `.rbxmx` to its file under `assets/native-ui`; a place edit alone does not update that mapped export. Include the `MY index button` export when changing the owner source.

Run `tools/build-native-ui.luau` in Studio Edit mode after syncing source when a deliberate rebuild is needed. It replaces the nine generated menus from the NativeMenus builders, then clones the current owner component into their four navigation wrappers. It preserves the original `MY index button` and keeps that source disabled. Re-running the tool overwrites direct edits inside generated menus, so put changes that must survive rebuilds into the relevant builder or shared authoring helper.

Owner component edits remain in the source, while existing clones retain their previous layers until rebuilt. To propagate an owner design change, update the source and its XML export, rebuild the generated menus, then export the affected menus. Keep controller-facing names intact. Runtime state and responsive layout remain the controllers' responsibility.

# Editable native menus

The internal menus are plain, script-free ScreenGuis authored in StarterGui. Their XML exports belong in `assets/native-ui/*.rbxmx`, which `default.project.json` maps into StarterGui. Runtime controller code stays in `StarterPlayerScripts.Client`: it obtains the replicated PlayerGui prefab through `NativeUI.get(name)`, binds named controls and updates native properties from service state. The main HUD and tutorial still use Fusion.

`src/client/NativeUI.luau` provides plain `Instance.new` authoring helpers and the runtime binding/layout helpers. Each module in `src/client/NativeMenus` exposes `build(): ScreenGui`; the authoring tool calls these builders in Studio Edit mode. Controllers use the authored menus rather than invoking builders during play. Dynamic lists use their authored templates, and shop/hatch previews retain their model content.

| Builder | StarterGui ScreenGui |
|---|---|
| `Shop` | `GearShop` |
| `Refinery` | `RefineryMenu` |
| `Index` | `MineralIndex` |
| `Rebirth` | `Rebirth` |
| `Store` | `Store` |
| `Hatch` | `PetHatch` |
| `Settings` | `HudSettings` |
| `Backpack` | `BackpackMenu` |
| `WelcomeBack` | `WelcomeBack` |

These nine menus and the owner's `MY index button` source form the ten ScreenGui exports. Keep their instance names and the named controls used by controllers when editing them.

## Menu appearance

Menus use charcoal studded bodies, bright accent headers, modest rectangular cards, thick near-black outlines, white outlined FredokaOne headings/actions and red X close buttons. Body copy uses GothamMedium. The shared native surface helper adds one passive tiled ImageLabel per surface, using `rbxassetid://6927295847` with a 128 × 128 tile size. It sits behind content and does not receive input.

The prefab exposes the visual properties directly in Studio. Controllers still own live text, quantities, availability, selection, visibility and responsive positioning; changes to those properties can be replaced by a runtime refresh. Button design does not change server purchase, inventory or progression rules.

## Owner navigation component

`src/client/ExactNavButton.luau` clones the layers under `StarterGui["MY index button"].Frame` into the Gear, Index, Rebirth and Store button wrappers. It removes only the source canvas offset, changes the caption, and substitutes configured icons for the three non-Index buttons. It retains the original blue face, texture, fonts, outlines and shadow. The source ScreenGui stays editable with `Enabled = false`, preventing an unwired duplicate from appearing during play.

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

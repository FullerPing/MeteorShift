# Meteor Mining HUD icons

These icons come from the original 64 × 64 components in [Meteor Mining - HUD Redesign](https://www.figma.com/design/QBDXyOcIZB29FdoXuE9Z4J/Meteor-Mining---HUD-Redesign?node-id=2-2).

The saved exports are 210 × 210 PNGs with alpha transparency. Figma's browser export preview included a checkerboard background. Python removed that background; white utility icons were exported against a temporary unique background to preserve their strokes and antialiasing. Temporary Figma fills were restored afterward.

Permanent Roblox asset IDs are in `src/shared/Config/HudIcons.luau`. The HUD is implemented as native Fusion controls in `src/client/HudView.luau`; the image files supply icons only. Wallet values, timer, objective, equipment and foundry remain connected to the existing Knit services.

Desktop geometry follows the 1440 × 810 reference. Touch layouts retain 44 px navigation targets, keep mining and movement controls clear, and move the foundry away from those controls. Tap the foundry row to expand its hopper and storage details. The training card temporarily hides on touch while the expanded foundry occupies its space.

The October 2 revision moves the wallet and backpack to opposite bottom corners and puts training above the bottom-centred foundry. The foundry lists carried Iron, Frost and Crystal bars separately, including their actual sale values; future types come from configuration or the inventory snapshot. Gear controls session training and objective preferences.

`rebirth-icons/rebirth-cycle.svg` is the clean 64 × 64 vector source for the new rebirth icon. Its transparent white PNG is uploaded as `rbxassetid://81918678127079` and tinted green in Roblox. Other icons retain the original Figma assets with consistent transparent navigation, scale and spacing.

`bar-stack.svg` and `bar-stack-white.png` provide three outlined ingots on a transparent 64 × 64 canvas. Roblox asset `rbxassetid://71884621343262` uses gold for Iron, cyan for Frost and purple for Crystal inside the expanded inventory.

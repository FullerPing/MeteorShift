# Editing the HUD

Everything lives in one file: `src/shared/Config/HudEdit.luau`. Edit it (Rojo carries the change into Studio), press Play, done. The edits are applied on top of the automatic layout, so they follow every screen size, phone and desktop.

## Hide something
```luau
HudEdit.Hidden = { "Level", "INDEX" }
```
Names: `Level`, `Wallet`, `Foundry`, `Backpack`, `Timer`, `EventPanel`, `SHOP`, `PETS`, `INDEX`, `REBIRTH`, `STORE`, `Settings`, `FastWalk`, `Ore`. (`Toast`, the notification line, can only be moved, so messages are never lost.)

## Move or resize something
```luau
HudEdit.Nudge = {
	Wallet = { y = -20 },                 -- 20 px up
	Timer  = { x = 40, scale = 0.9 },     -- 40 px right, 10% smaller
	FastWalk = { x = -80 },               -- ORE follows SPRINT, then has its own Ore nudge
}
```
`x` moves right, `y` moves down, `scale` multiplies the size.

## Add a button or label
```luau
HudEdit.Custom = {
	{ Id = "QuickGear", Text = "QUICK GEAR", Icon = "equipment", Color = "orange",
	  Anchor = "TopRight", X = -80, Y = 70, Width = 150, Height = 56, Open = "Shop" },
	{ Id = "Tag", Kind = "label", Text = "BETA", Color = "purple", Anchor = "BottomLeft", X = 20, Y = -140 },
}
```
- `Kind`: `"button"` (default) or `"label"`.
- `Icon`: any key of `src/shared/Config/HudIcons.luau`.
- `Color`: `blue deep green orange purple red gold white slate dark`.
- `Anchor`: `TopLeft Top TopRight Left Center Right BottomLeft Bottom BottomRight`; `X`/`Y` are pixels in from it.
- A click does `Open = "Shop" | "Rebirth" | "Refinery" | "FastWalk"`, or runs your own `Click = function(player) ... end`.

Custom elements hide while a menu is open and are never drawn smaller than a 44 px touch target.

## Remove something you added
Delete its table from `HudEdit.Custom`.

## Not covered
Moving *inside* a card (for example where the cash number sits in the wallet) is still in `src/client/HudView.luau`. The big menus (Gear, Store, Rebirth, Hatchery, Refinery, Backpack, Index, Settings) are authored in Studio: `assets/native-ui/*.rbxmx`, synced into StarterGui. Edit those visually in Studio and re-export the `.rbxmx` when you are happy.

The numbers behind the automatic layout (card sizes, gaps, margins) are in `src/shared/Config/Hud.luau`.

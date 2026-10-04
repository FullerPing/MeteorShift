--!strict
-- HUD layout and mobile controls tuning (spec §10). All numbers are in screen pixels
-- unless a name says "base" (base units are multiplied by the HUD scale).
-- Read by Shared.HudLayout, which computes where every HUD button sits.

local Hud = {}

-- Roblox reserves this strip at the top for its own top bar. Client code passes the
-- real GuiService inset to HudLayout; this is the fallback and what the specs use.
Hud.TopBarInset = 36

-- The HUD cards scale with the viewport: min(width / ScaleRefWidth, height / ScaleRefHeight),
-- kept between ScaleMin and ScaleMax
Hud.ScaleRefWidth = 1440
Hud.ScaleRefHeight = 810
Hud.ScaleMin = 0.45
Hud.ScaleMax = 1

-- Smallest touch target (spec §10). No HUD button is ever drawn smaller than this.
Hud.MinTouch = 44

-- Base screen edge gap for the event card
Hud.EdgeMargin = 31

-- HUD buttons in top-to-bottom / left-to-right order
Hud.ButtonOrder = { "SHOP", "INDEX", "REBIRTH", "STORE" }

-- Mouse layout: the Figma navigation column on the left. Base units, scaled by
-- the HUD scale, with buttons kept at least MinTouch tall.
Hud.Column = {
	Width = 72,
	Height = 72,
	Gap = 16,
	Top = 294,
	Left = 21,
}

-- Touch layout: one row along the top right, under the Roblox top bar, so the whole
-- right edge below it stays free for the MINE button and Roblox's jump button.
-- Real pixels (no scale), so the target size is exact.
Hud.TouchRow = {
	Width = 44,
	Height = 44,
	Gap = 6,
	Top = 6, -- gap under the top bar
	Right = 12, -- gap to the screen edge
	TextSize = 15,
}

-- Smallest scale of the tutorial card on touch (so its Skip button can reach MinTouch)
Hud.TouchCardScale = 0.75

-- The event card sits under the buttons (touch) or at this base offset (mouse)
Hud.EventPanel = { Width = 284, Height = 170, Top = 153, Gap = 6 }
-- Figma event clock at the top centre (base units).
Hud.Timer = { Width = 593, Height = 130, Top = 49 }

-- Figma wallet at top left, equipment at bottom centre, and foundry at bottom right.
-- On touch screens the foundry moves beside the clock to clear the touch controls.
Hud.LeftCards = {
	X = 24,
	Gap = 6,
	Resources = { Width = 336, Height = 66, Top = 84 },
	Equipment = { Width = 244, Height = 69, Bottom = 17 },
	Production = { Width = 448, Height = 113, ExpandedHeight = 282, Bottom = 16, Right = 22 },
}
Hud.Training = { Width = 332, Height = 125, Right = 27, Bottom = 154, Gap = 16 }

-- Roblox's own touch controls, which the HUD has to keep clear of. Mirrors TouchGui: the
-- jump button is 70 px on small screens (shorter side <= SmallMaxSide) and 120 px on
-- larger ones; Position is the button's top-left from the bottom-right corner. The
-- large-screen bottom offset is deliberately generous.
Hud.Jump = {
	SmallMaxSide = 500,
	Small = { Size = 70, Right = 95, Bottom = 90 },
	Large = { Size = 120, Right = 170, Bottom = 210 },
}
-- The default thumbstick area at the bottom left
Hud.Thumbstick = { Width = 220, Height = 220 }

-- MINE button (touch only): a big round button directly above the jump button,
-- right edges aligned. Holding it swings at the pickaxe's speed at the nearest target.
Hud.Mine = {
	SmallSize = 84,
	LargeSize = 104,
	-- On short screens the button shrinks (not below MinSize) to stay clear of the event
	-- card above it
	MinSize = 60,
	EventGap = 4,
	Gap = 10, -- above the jump button
	-- "In front of the character": only targets whose direction has at least this dot
	-- product with where the character faces count (0 = the front half, 90 degrees each side)
	FrontDot = 0,
	-- An exposed core is preferred over crust when they are in reach: this many studs
	-- are taken off its distance
	CoreBonus = 4,
}

-- Panels (shop, index, rebirth, store): margin kept above and below, and the smallest scale
Hud.Panel = { Margin = 8, MinScale = 0.35, SideMargin = 12 }

return Hud

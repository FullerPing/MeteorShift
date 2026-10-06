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
Hud.ScaleMin = 0.7
Hud.ScaleMax = 1

-- Smallest touch target (spec §10). No HUD button is ever drawn smaller than this.
Hud.MinTouch = 44

-- Base screen edge gap for the event card
Hud.EdgeMargin = 24

-- HUD buttons in top-to-bottom / left-to-right order
Hud.ButtonOrder = { "SHOP", "INDEX", "REBIRTH", "STORE" }
Hud.DesktopButtonOrder = { "SHOP", "REBIRTH", "STORE" }

-- Mouse layout: the Figma navigation column on the left. Base units, scaled by
-- the HUD scale, with buttons kept at least MinTouch tall.
Hud.Column = {
	Width = 88,
	Height = 88,
	Gap = 0,
	Top = 270,
	Left = 24,
}

-- Touch layout: a row below the Roblox top bar, with room for the settings gear.
-- The right side below it stays free for MINE and Roblox's jump button.
-- Real pixels (no scale), so the target size is exact.
Hud.TouchRow = {
	Width = 44,
	Height = 44,
	Gap = 6,
	Top = 6, -- gap under the top bar
	Right = 12, -- gap to the screen edge
	TextSize = 26, -- unscaled; the 0.5 navigation scale keeps labels at 13 px
}

-- Landscape training scale. Skip keeps a 44 px target through closeSize().
Hud.TouchCardScale = 0.65

-- The event card sits under the buttons (touch) or at this base offset (mouse)
Hud.EventPanel = { Width = 284, Height = 170, Top = 153, Gap = 6 }
-- Figma event clock at the top centre (base units).
Hud.Timer = { Width = 593, Height = 130, Top = 49 }

-- Transparent wallet and backpack occupy opposite bottom corners. The foundry
-- summary is centred, with training above it. Equipment aliases the SHOP rect.
Hud.LeftCards = {
	X = 24,
	Gap = 6,
	Resources = { Width = 250, Height = 116, Bottom = 18 },
	Equipment = { Width = 88, Height = 88 },
	Production = { Width = 400, Height = 82, ExpandedHeight = 322, Bottom = 16 },
}
Hud.Backpack = { Width = 230, Height = 86, Right = 24, Bottom = 18 }
Hud.Training = { Width = 332, Height = 125, Gap = 14 }
Hud.SettingsSize = 44

-- Desktop reference layout. Touch and portrait retain their authored geometry.
Hud.Desktop = {
	Timer = { Width = 560, Height = 108, Top = 28 },
	LeftCards = {
		X = 24,
		Gap = 6,
		Resources = { Width = 292, Height = 116, Bottom = 18 },
		Equipment = { Width = 88, Height = 88 },
		Production = { Width = 550, Height = 116, ExpandedHeight = 356, Bottom = 16 },
	},
	Backpack = { Width = 292, Height = 116, Right = 24, Bottom = 18 },
}

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
	-- Every swing at a target turns your character to face it (any input; not while
	-- walking or while the camera locks the mouse): how fast it turns, per second, and
	-- how long after a swing it keeps turning
	FaceTurnRate = 18,
	FaceHold = 0.35,
}

-- Panels (shop, index, rebirth, store): margin kept above and below, and the smallest scale
Hud.Panel = { Margin = 8, MinScale = 0.35, SideMargin = 12 }

return Hud

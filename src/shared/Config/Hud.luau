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
-- Past this screen size the HUD grows in proportion (min of width and height ratios), up to ScaleUpMax
Hud.ScaleUpRef = Vector2.new(1920, 1080)
Hud.ScaleUpMax = 3

-- Smallest touch target (spec §10). No HUD button is ever drawn smaller than this.
Hud.MinTouch = 44

-- Base screen edge gap for the event card
Hud.EdgeMargin = 24

-- HUD buttons in top-to-bottom / left-to-right order
Hud.ButtonOrder = { "SHOP", "PETS", "INDEX", "REBIRTH", "STORE" }
Hud.DesktopButtonOrder = { "SHOP", "PETS", "REBIRTH", "STORE" }

-- Mouse layout: the Figma navigation column on the left. Base units, scaled by
-- the HUD scale, with buttons kept at least MinTouch tall.
Hud.Column = {
	Width = 88,
	Height = 88,
	Gap = 0,
	Top = 300, -- under the level card and the desktop event card
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

-- Touch and portrait: how many cells HudLayout.offerSlots finds for the Offers buttons (2x Ore, 2x Cash, Starter Pack)
Hud.OfferSlots = 3

-- Landscape training scale. Skip keeps a 44 px target through closeSize().
Hud.TouchCardScale = 0.65

-- The event card sits under the buttons (touch) or at this base offset (mouse)
Hud.EventPanel = { Width = 284, Height = 170, Top = 153, Gap = 6 }
-- Figma event clock at the top centre (base units).
Hud.Timer = { Width = 593, Height = 130, Top = 49 }
-- A line under the clock during the countdown, for players up to MaxLevel (telemetry: most new players left while
-- waiting for the meteor, not knowing the fields are open between meteors)
Hud.CountdownTip = { Text = "TIP: Mine the ore fields while you wait - press TELEPORT!", MaxLevel = 10 }

-- Transparent wallet and backpack occupy opposite bottom corners. The foundry
-- summary is centred, with training above it. Equipment aliases the SHOP rect.
Hud.LeftCards = {
	X = 24,
	Gap = 6,
	Resources = { Width = 250, Height = 116, Bottom = 18 },
	Equipment = { Width = 88, Height = 88 },
	Production = { Width = 218, Height = 84, ExpandedHeight = 322, Bottom = 18 }, -- 18 like Resources and the backpack: one bottom line
}
Hud.Backpack = { Width = 230, Height = 86, Right = 24, Bottom = 18 }
Hud.Training = { Width = 332, Height = 125, Gap = 14 }
Hud.SettingsSize = 44
-- Mouse layouts: the player level badge in the top-left corner under the Roblox
-- top bar (base units). It shrinks to clear the clock and is dropped below
-- MinHeight px; touch and cramped screens show the level on the wallet card.
Hud.Level = { Width = 316, Height = 84, Top = 10, MinHeight = 48 }

-- Desktop reference layout. Touch and portrait retain their authored geometry.
Hud.Desktop = {
	-- the menu buttons (left column and INDEX on the right) are drawn at this share of their base size
	ButtonScale = 0.88,
	Timer = { Width = 560, Height = 108, Top = 28 },
	LeftCards = {
		X = 24,
		Gap = 6,
		Resources = { Width = 292, Height = 116, Bottom = 18 },
		Equipment = { Width = 88, Height = 88 },
		-- foundry and backpack are drawn at 0.88 of their 300 x 116 and 292 x 116 artwork
		Production = { Width = 264, Height = 102, ExpandedHeight = 313, Bottom = 18 }, -- 18 like Resources and the backpack: one bottom line
	},
	Backpack = { Width = 257, Height = 102, Right = 24, Bottom = 18 },
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

-- The round SPRINT button and the TELEPORT button stacked above it (real pixels)
Hud.SideButtons = { Size = 54, Gap = 8 }

-- Panels (shop, index, rebirth, store): margin kept above and below, and the smallest scale
Hud.Panel = { Margin = 8, MinScale = 0.35, SideMargin = 12 }

return Hud

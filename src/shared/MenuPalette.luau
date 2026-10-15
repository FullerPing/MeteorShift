--!strict
-- Colours for the light "toy" menus (the Gear Shop first), measured from the owner's "Gear Shop / Clean" mockup:
-- an opaque pale body, a sky-blue header, a white-to-blue-grey card, pale wells, a lime selected state and an orange evolution
-- banner, everything outlined in dark navy. Plain data so a spec can check that every text colour reads on what it sits on.
local MenuPalette = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

MenuPalette.NAVY = rgb(36, 60, 96) -- outlines, lips and the main text
MenuPalette.BODY = rgb(239, 247, 253) -- the panel body ...
MenuPalette.BODY_ALPHA = 1 -- ... drawn opaque, as in the owner's "Gear Shop / Clean" mockup
MenuPalette.HEADER = rgb(88, 183, 237)
MenuPalette.WALLET = rgb(255, 211, 80)
MenuPalette.CLOSE = rgb(239, 88, 114)
MenuPalette.TAB_ON = rgb(87, 200, 251)
MenuPalette.TAB_OFF = rgb(218, 233, 246)
MenuPalette.CARD_TOP = rgb(255, 255, 255) -- the main card fades from white to a pale blue-grey
MenuPalette.CARD_BOTTOM = rgb(196, 212, 228)
MenuPalette.WELL = rgb(206, 235, 251) -- the preview well on the main card
MenuPalette.WELL_SHADOW = rgb(140, 194, 227) -- the ellipse under the item
MenuPalette.STRIP = rgb(220, 231, 243) -- the quantity strip
MenuPalette.LIME = rgb(184, 239, 76) -- the selected quantity and buttons you can press
MenuPalette.FACE = rgb(197, 212, 227) -- Upgrade and Evolve while they cannot be pressed
MenuPalette.OFF_OUTLINE = rgb(51, 51, 51) -- Upgrade's outline and lip while it cannot be pressed
MenuPalette.ORANGE = rgb(254, 190, 69) -- EVOLVE NOW
MenuPalette.BANNER_TOP = rgb(255, 220, 116)
MenuPalette.BANNER_BOTTOM = rgb(248, 140, 4)
MenuPalette.BANNER_TEXT = rgb(116, 80, 34)
MenuPalette.EVO_BODY = rgb(210, 214, 220) -- the evolution column, a faint gradient ...
MenuPalette.EVO_BODY_BOTTOM = rgb(219, 223, 229) -- ... lighter at the bottom
MenuPalette.EVO_WELL = rgb(215, 234, 248)
MenuPalette.EVO_SHADOW = rgb(110, 130, 154)
MenuPalette.BAR_TRACK = rgb(204, 219, 233)
MenuPalette.BAR_FILL = rgb(255, 189, 83)
MenuPalette.WHITE = Color3.new(1, 1, 1)
MenuPalette.SECOND = rgb(86, 115, 145) -- the tier line, the quantity label and the unselected quantities
MenuPalette.VALUE = rgb(50, 120, 44) -- stat values
MenuPalette.MET = rgb(55, 116, 49) -- a requirement you meet
MenuPalette.UNMET = rgb(193, 69, 87) -- one you do not
MenuPalette.MUTED = rgb(86, 115, 145) -- notices on the body

-- The "cartoon light" mockup (Gear Shop + Pets, 2026-10-13): a white-to-pale-blue body with a title ribbon, chunky buttons with
-- a soft gloss band, a gold evolution column and a pale blue pet detail column
MenuPalette.BODY_TOP = rgb(250, 253, 255)
MenuPalette.BODY_BOTTOM = rgb(222, 237, 249)
MenuPalette.INK = rgb(29, 43, 69) -- the outline on white text (ribbon title, blue and red buttons)
MenuPalette.BLUE_TOP = rgb(106, 205, 255) -- the ribbon, the selected tab and the name banner
MenuPalette.BLUE_BOTTOM = rgb(42, 142, 228)
MenuPalette.RED_TOP = rgb(255, 120, 138) -- Close and PUT AWAY
MenuPalette.RED_BOTTOM = rgb(226, 66, 92)
MenuPalette.GOLD_TOP = rgb(255, 238, 150) -- the EVOLUTION banner and the Robux button
MenuPalette.GOLD_BOTTOM = rgb(255, 204, 82)
MenuPalette.LIME_TOP = rgb(178, 240, 104) -- the selected quantity and buttons you can press
MenuPalette.LIME_BOTTOM = rgb(104, 200, 58)
MenuPalette.OFF_TOP = rgb(232, 239, 246) -- unselected tabs and quantities
MenuPalette.OFF_BOTTOM = rgb(205, 218, 231)
MenuPalette.GREY_TOP = rgb(205, 218, 230) -- Upgrade and Evolve while they cannot be pressed
MenuPalette.GREY_BOTTOM = rgb(176, 193, 210)
MenuPalette.CASH_CHIP = rgb(255, 240, 168)
MenuPalette.SHARD_CHIP = rgb(234, 245, 255)
MenuPalette.PILL = rgb(255, 255, 255) -- "Tier 1 / 8", "LEVEL 1"
MenuPalette.LEVEL_ROW = rgb(227, 241, 252) -- the highlighted "Level 1 → 2" row
MenuPalette.LEVEL_EDGE = rgb(150, 200, 234)
MenuPalette.DIVIDER = rgb(211, 226, 239)
MenuPalette.UP = rgb(40, 128, 36) -- stat gains and "1 → 2"
MenuPalette.EVO_TOP = rgb(255, 249, 226) -- the evolution column
MenuPalette.EVO_BOTTOM = rgb(255, 234, 172)
MenuPalette.EVO_EDGE = rgb(232, 184, 74)
MenuPalette.GOLD_WELL_TOP = rgb(255, 240, 180)
MenuPalette.GOLD_WELL_BOTTOM = rgb(250, 208, 98)
MenuPalette.GOLD_TEXT = rgb(150, 98, 18) -- "Tier 2 / 8" and the captions on the gold column
MenuPalette.WELL_TOP = rgb(226, 244, 255) -- the blue preview wells
MenuPalette.WELL_BOTTOM = rgb(178, 222, 247)
MenuPalette.WELL_EDGE = rgb(150, 200, 234)
MenuPalette.DETAIL_TOP = rgb(240, 248, 255) -- the pet detail column
MenuPalette.DETAIL_BOTTOM = rgb(220, 238, 251)
MenuPalette.BOOST = rgb(236, 249, 226) -- the TEAM BOOST strip
MenuPalette.BOOST_EDGE = rgb(184, 226, 156)
MenuPalette.BOOST_TEXT = rgb(70, 112, 48)
MenuPalette.EQUIP_PILL = rgb(214, 245, 182) -- "Equipped 1 / 1"
MenuPalette.EQUIP_EDGE = rgb(104, 200, 58) -- an equipped pet's outline and tab
MenuPalette.INFO = rgb(232, 241, 250) -- the hint strip under the pets
MenuPalette.INFO_DOT = rgb(64, 160, 236)
MenuPalette.PREMIUM = rgb(244, 230, 255)
MenuPalette.PREMIUM_EDGE = rgb(185, 138, 230)
MenuPalette.PREMIUM_TEXT = rgb(118, 58, 178)
MenuPalette.XP_FILL = rgb(88, 183, 237)
MenuPalette.UNSEEN = rgb(214, 224, 234) -- the "?" cover on pets you have not found

-- WCAG relative luminance and contrast ratio of two colours
local function linear(channel: number): number
	return if channel <= 0.03928 then channel / 12.92 else ((channel + 0.055) / 1.055) ^ 2.4
end

function MenuPalette.luminance(color: Color3): number
	return 0.2126 * linear(color.R) + 0.7152 * linear(color.G) + 0.0722 * linear(color.B)
end

function MenuPalette.contrast(a: Color3, b: Color3): number
	local la, lb = MenuPalette.luminance(a), MenuPalette.luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

-- Every text colour and what it sits on, with the contrast it must reach. The owner's design is soft: the tier line and the
-- the tier line on the banner's deep orange bottom only reaches about 3:1, and that is kept on purpose.
export type Pair = { name: string, text: Color3, background: Color3, min: number }
local P = MenuPalette
MenuPalette.Pairs = {
	{ name = "title on the header", text = P.NAVY, background = P.HEADER, min = 4.5 },
	{ name = "wallet on its chip", text = P.NAVY, background = P.WALLET, min = 4.5 },
	{ name = "close X on its button", text = P.NAVY, background = P.CLOSE, min = 3 },
	{ name = "selected tab", text = P.NAVY, background = P.TAB_ON, min = 4.5 },
	{ name = "unselected tab", text = P.NAVY, background = P.TAB_OFF, min = 4.5 },
	{ name = "name on the card top", text = P.NAVY, background = P.CARD_TOP, min = 4.5 },
	{ name = "stat label on the card", text = P.NAVY, background = P.CARD_BOTTOM, min = 4.5 },
	{ name = "tier line on the card top", text = P.SECOND, background = P.CARD_TOP, min = 4.5 },
	{ name = "stat value on the card", text = P.VALUE, background = P.CARD_BOTTOM, min = 3.5 },
	{ name = "selected quantity", text = P.NAVY, background = P.LIME, min = 4.5 },
	{ name = "unselected quantity on the strip", text = P.SECOND, background = P.STRIP, min = 3.5 },
	{ name = "quantity label on the body", text = P.SECOND, background = P.BODY, min = 4 },
	{ name = "button that cannot be pressed", text = P.NAVY, background = P.FACE, min = 4.5 },
	{ name = "EVOLVE NOW", text = P.NAVY, background = P.ORANGE, min = 4.5 },
	{ name = "banner text, top", text = P.BANNER_TEXT, background = P.BANNER_TOP, min = 4.5 },
	{ name = "banner text, bottom", text = P.BANNER_TEXT, background = P.BANNER_BOTTOM, min = 2.8 },
	{ name = "banner name, top", text = P.NAVY, background = P.BANNER_TOP, min = 4.5 },
	{ name = "banner name, bottom", text = P.NAVY, background = P.BANNER_BOTTOM, min = 4.5 },
	{ name = "requirement label", text = P.NAVY, background = P.EVO_BODY, min = 4.5 },
	{ name = "requirement met", text = P.MET, background = P.EVO_BODY, min = 3.5 },
	{ name = "requirement unmet", text = P.UNMET, background = P.EVO_BODY, min = 3 },
	-- the cartoon light menus
	{ name = "dark text on the body", text = P.NAVY, background = P.BODY_BOTTOM, min = 4.5 },
	{ name = "unselected tab", text = P.NAVY, background = P.OFF_BOTTOM, min = 4.5 },
	{ name = "selected quantity", text = P.NAVY, background = P.LIME_BOTTOM, min = 4.5 },
	{ name = "button that cannot be pressed", text = P.NAVY, background = P.GREY_BOTTOM, min = 4.5 },
	{ name = "gold button", text = P.NAVY, background = P.GOLD_BOTTOM, min = 4.5 },
	{ name = "cash chip", text = P.NAVY, background = P.CASH_CHIP, min = 4.5 },
	{ name = "shard chip", text = P.NAVY, background = P.SHARD_CHIP, min = 4.5 },
	{ name = "stat gain on the body", text = P.UP, background = P.BODY_BOTTOM, min = 3.5 },
	{ name = "level gain on its row", text = P.UP, background = P.LEVEL_ROW, min = 3.5 },
	{ name = "tier on the gold column", text = P.GOLD_TEXT, background = P.EVO_BOTTOM, min = 4 },
	{ name = "requirement met on the gold column", text = P.MET, background = P.EVO_BOTTOM, min = 3.5 },
	{ name = "requirement unmet on the gold column", text = P.UNMET, background = P.EVO_BOTTOM, min = 3 },
	{ name = "team boost label", text = P.BOOST_TEXT, background = P.BOOST, min = 4.5 },
	{ name = "team boost value", text = P.UP, background = P.BOOST, min = 3.5 },
	{ name = "equipped count", text = P.NAVY, background = P.EQUIP_PILL, min = 4.5 },
	{ name = "premium pill", text = P.PREMIUM_TEXT, background = P.PREMIUM, min = 4.5 },
	{ name = "perk value in the detail", text = P.UP, background = P.DETAIL_BOTTOM, min = 3.5 },
	{ name = "hint strip", text = P.NAVY, background = P.INFO, min = 4.5 },
	{ name = "muted line on the body", text = P.MUTED, background = P.BODY_BOTTOM, min = 4 },
} :: { Pair }

return MenuPalette

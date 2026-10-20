--!strict
-- The Gear shop's geometry. On a roomy window ("wide") it is the owner's "Gear Shop / Clean" mockup: one 760 x 501
-- panel (aspect 1.517) drawn at 64% of the screen's width or 75% of its height, whichever is smaller, with the evolution as
-- a column on the right. On a small screen it is one 560-wide column with the evolution stacked under the controls.
-- Panel bounds use virtual pixels (`view`); a screen and the evolution body are local to their parent.
local MenuFit = require(script.Parent.MenuFit)

export type Rect = { x: number, y: number, w: number, h: number }
export type View = { viewport: Vector2, inset: number, scale: number, wide: boolean }
export type Layout = {
	panel: Rect,
	evolvePanel: Rect, -- the evolution column, local to the panel (zero-sized unless `popout`)
	popout: boolean, -- the wide layout: the evolution is a column
	padding: number,
	headerTop: number, -- the header bar sits this far in from the panel's top and sides
	headerH: number, -- the header bar's height
	tabsY: number,
	tabsH: number,
	carouselY: number,
	carouselH: number,
	contentW: number, -- the width of the tabs and the screens (the left column when the evolution is a column)
	footerY: number,
	footerH: number,
	gap: number,
	narrow: boolean,
	compact: boolean, -- phones in landscape: slimmer header and tabs, the footer line moves into the header
}

local EquipmentShopLayout = {}

EquipmentShopLayout.WIDE_W, EquipmentShopLayout.WIDE_H = 760, 501
EquipmentShopLayout.WIDE_FRACTION = Vector2.new(0.6417, 0.7519) -- the frame's share of the screen's width and height
EquipmentShopLayout.RIBBON = 26 -- how far the title ribbon pokes above the body
EquipmentShopLayout.WIDE_MIN_SCALE = 0.75 -- below this the text would be too small: use the single column instead
local SINGLE_W = 560
local PAD = 12

-- How big the menu is drawn: the wide panel scaled to its share of the screen, or MenuFit's small-screen fit
function EquipmentShopLayout.view(viewport: Vector2, inset: number): View
	local scale = math.min(viewport.X * EquipmentShopLayout.WIDE_FRACTION.X / EquipmentShopLayout.WIDE_W,
		viewport.Y * EquipmentShopLayout.WIDE_FRACTION.Y / EquipmentShopLayout.WIDE_H)
	if scale >= EquipmentShopLayout.WIDE_MIN_SCALE then
		return { viewport = viewport / scale, inset = inset / scale, scale = scale, wide = true }
	end
	local fit = MenuFit.view(viewport, inset)
	return { viewport = fit.viewport, inset = fit.inset, scale = fit.scale, wide = false }
end

function EquipmentShopLayout.compute(viewport: Vector2, inset: number, wide: boolean?): Layout
	if wide then
		-- the cartoon light mockup: the frame is the body plus the title ribbon poking RIBBON px above it
		local W, H = EquipmentShopLayout.WIDE_W, EquipmentShopLayout.WIDE_H
		local R = EquipmentShopLayout.RIBBON
		return {
			panel = { x = (viewport.X - W) / 2, y = (viewport.Y - H) / 2 + R, w = W, h = H - R },
			-- everything sits 6 px higher than the first mockup pass: the columns ended 5 px above the body's bottom edge
			-- against a 20 px top margin, so the menu read bottom-heavy (now about 14 top / 11 bottom)
			evolvePanel = { x = 492, y = 103, w = 245, h = 355 },
			popout = true,
			padding = 22,
			headerTop = 0,
			headerH = 46, -- the band the ribbon, the notice line and the wallet chip share
			tabsY = 55,
			tabsH = 42,
			carouselY = 107,
			carouselH = 357,
			contentW = 440,
			footerY = 14, -- notices: a line between the ribbon and the wallet chip
			footerH = 31,
			gap = 12,
			narrow = false,
			compact = false,
		}
	end
	local topInset = math.max(0, inset)
	local availableWidth = math.max(0, viewport.X - 24)
	local availableHeight = math.max(0, viewport.Y - topInset - 24)
	local panelWidth = math.min(SINGLE_W, availableWidth)
	local narrow = panelWidth < 540
	local compact = not narrow and availableHeight < 400
	local panelTop = if compact then topInset + 18 else nil
	if panelTop then availableHeight = math.max(0, viewport.Y - panelTop - 12) end
	local panelHeight = math.min(if narrow then 500 else 520, availableHeight)
	local sectionGap = 6
	-- compact keeps 44 px for the close button and the tabs (touch targets) but drops the rest of the header
	local headerTop = if compact then 6 else 10
	local headerHeight = if narrow then 80 elseif compact then 44 else 52
	local tabsY = headerTop + headerHeight + (if compact then 8 else 12)
	local tabsHeight = 44
	local carouselY = tabsY + tabsHeight + sectionGap
	local footerHeight = if compact then 0 else 22
	local footerY = if compact then panelHeight - PAD + sectionGap else panelHeight - 4 - footerHeight
	local carouselHeight = math.max(0, footerY - sectionGap - carouselY)
	local x = (viewport.X - panelWidth) / 2
	local y = panelTop or topInset + 12 + (availableHeight - panelHeight) / 2

	return {
		panel = { x = x, y = y, w = panelWidth, h = panelHeight },
		evolvePanel = { x = 0, y = 0, w = 0, h = 0 },
		popout = false,
		padding = PAD,
		headerTop = headerTop,
		headerH = headerHeight,
		tabsY = tabsY,
		tabsH = tabsHeight,
		carouselY = carouselY,
		carouselH = carouselHeight,
		contentW = panelWidth - PAD * 2,
		footerY = footerY,
		footerH = footerHeight,
		gap = 12,
		narrow = narrow,
		compact = compact,
	}
end

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = math.max(0, w), h = math.max(0, h) }
end

-- The evolution body: a banner with the heading, name and tier, then the next item's preview, two requirements (the gear
-- level and the player level, each with a progress bar under it) and the two evolve buttons. `w` is its width. Stacked (a card under the
-- shop) the banner is shorter and the preview sits in its right corner.
export type EvolveLayout = {
	card: Rect, -- the gold column behind everything but the buttons
	banner: Rect, heading: Rect, well: Rect, name: Rect, tier: Rect, rows: { Rect }, bar: Rect, bar2: Rect, evolve: Rect, alt: Rect,
	capEvolve: Rect, capAlt: Rect, -- the captions over the buttons (the column only; stacked, the buttons carry the words)
	height: number,
}

function EquipmentShopLayout.evolve(w: number, stacked: boolean, altShown: boolean): EvolveLayout
	local out = {} :: any
	if not stacked then
		-- the mockup's column (245 wide): a gold banner tab over a gold card, the next item, the two requirements, then
		-- the cash and Robux buttons side by side under the card with a caption each
		out.card = rect(0, 18, w, 284)
		out.banner = rect(19, 0, w - 38, 39)
		out.heading = out.banner
		out.name, out.tier = rect(8, 44, w - 16, 24), rect(8, 68, w - 16, 16)
		out.well = rect(31, 90, w - 62, 110)
		out.rows = { rect(16, 206, w - 32, 24), rect(16, 244, w - 32, 24) }
		out.bar, out.bar2 = rect(17, 232, w - 34, 7), rect(17, 272, w - 34, 0)
		local half = math.floor((w - 7) / 2)
		if altShown then
			out.evolve, out.alt = rect(0, 309, half, 46), rect(w - half, 309, half, 46)
			out.capEvolve, out.capAlt = rect(0, 278, half, 18), rect(w - half, 278, half, 18)
		else
			out.evolve, out.alt = rect(0, 309, w, 46), rect(0, 309, 0, 46)
			out.capEvolve, out.capAlt = rect(0, 278, w, 18), rect(0, 278, 0, 18)
		end
		out.height = 355
	else
		local pad = 12
		local iw = w - pad * 2
		local text = iw - 72
		out.banner = rect(3, 3, w - 6, 69)
		out.heading, out.name, out.tier = rect(pad, 8, text, 16), rect(pad, 24, text, 28), rect(pad, 50, text, 18)
		out.well = rect(w - pad - 60, 8, 60, 60)
		out.rows = { rect(pad, 84, iw, 24), rect(pad, 130, iw, 24) }
		out.bar, out.bar2 = rect(pad, 114, iw, 8), rect(pad, 158, iw, 6)
		local y = 172
		if altShown then
			local half = math.floor((iw - 8) / 2)
			out.evolve, out.alt = rect(pad, y, half, 44), rect(pad + half + 8, y, iw - half - 8, 44)
		else
			out.evolve, out.alt = rect(pad, y, iw, 44), rect(pad, y, 0, 44)
		end
		out.height = y + 44 + pad
		out.card = rect(0, 0, w, out.height)
		out.capEvolve, out.capAlt = rect(0, 0, 0, 0), rect(0, 0, 0, 0)
	end
	return out :: EvolveLayout
end

-- One gear screen (pickaxe or backpack): one grey-blue card holding the name, tier line, preview and an info block (the
-- level and what the upgrade gives, `rows` lines, evenly spaced), then the quantity strip and Upgrade on the body. The
-- wide layout is the owner's frame to the pixel; the single column has bigger touch targets and stacks everything on a
-- narrow screen. With `stackEvolve` the evolution card follows at the bottom (`evolve`). A screen shorter than `canvasH`
-- scrolls, and everything keeps a 4 px margin so outlines are not clipped by the scrolling area.
export type ScreenLayout = {
	card: Rect, name: Rect, tier: Rect, well: Rect,
	cap: Rect, levelPill: Rect, levelRow: Rect, dividers: { Rect }, -- the mockup's extras (zero-sized or empty off the wide layout)
	info: Rect, levelLabel: Rect, levelValue: Rect, stats: { Rect },
	qtyLabel: Rect, strip: Rect, amounts: { Rect }, upgrade: Rect,
	evolve: Rect, -- the stacked evolution card (zero-sized when it is a column instead)
	canvasH: number,
}

local MARGIN = 4
local INNER = 14 -- inside the card
local STRIP_H = 44 -- the quantity strip and the touch targets
local UPGRADE_H = 44

function EquipmentShopLayout.screen(width: number, height: number, narrow: boolean, stackEvolve: boolean, rows: number, wide: boolean?): ScreenLayout
	local w, h = width - MARGIN * 2, height - MARGIN * 2
	local gap = 8
	local count = math.max(rows, 1)
	local out = {} :: any
	-- the level row and the stat rows, one grid straight on the card
	local function infoBlock(x: number, y: number, iw: number, ih: number)
		out.info = rect(x, y, iw, ih)
		local rowH = math.clamp(math.floor(ih / (count + 1)), 24, 40)
		out.levelRow = rect(x, y, iw, rowH)
		out.levelLabel = rect(x, y, math.floor(iw * 0.4), rowH)
		out.levelValue = rect(x + iw - math.floor(iw * 0.55), y, math.floor(iw * 0.55), rowH)
		out.stats = {}
		for index = 1, count do table.insert(out.stats, rect(x, y + rowH * index, iw, rowH)) end
	end
	-- one strip with 1x, 10x and MAX in it
	local function amountRow(x: number, y: number, aw: number, sh: number, pad: number)
		out.strip = rect(x, y, aw, sh)
		local each = math.floor((aw - pad * 2 - pad * 2) / 3)
		out.amounts = {}
		for index = 1, 3 do
			local cx = x + pad + (each + pad) * (index - 1)
			table.insert(out.amounts, rect(cx, y + pad, if index == 3 then x + aw - pad - cx else each, sh - pad * 2))
		end
	end
	local mainH
	out.cap, out.levelPill, out.dividers = rect(0, 0, 0, 0), rect(0, 0, 0, 0), {}
	if wide then
		-- the cartoon light mockup, straight on the body: the name over a "Tier" pill and the level cap, the preview with
		-- a "LEVEL" pill, the highlighted level row over the stat rows with dividers, three quantity buttons and Upgrade
		mainH = 351
		out.card = rect(0, 0, w, 258)
		out.name = rect(0, 6, 300, 28)
		out.tier, out.cap = rect(0, 38, 84, 22), rect(94, 38, 200, 22)
		out.well = rect(0, 70, 186, 187) -- ends with the info card beside it
		out.levelPill = rect(42, 223, 102, 22)
		out.info = rect(199, 70, w - 199, 187)
		out.levelRow = rect(199, 70, w - 199, 40)
		out.levelLabel, out.levelValue = rect(211, 70, 110, 40), rect(w - 130, 70, 118, 40)
		out.stats = {}
		for index = 1, count do
			table.insert(out.stats, rect(207, 113 + (index - 1) * 36, w - 215, 36))
			if index > 1 then table.insert(out.dividers, rect(207, 112 + (index - 1) * 36, w - 215, 2)) end
		end
		out.qtyLabel = rect(0, 263, 140, 36)
		out.strip = rect(155, 263, w - 155, 36)
		out.amounts = { rect(155, 263, 88, 36), rect(251, 263, 90, 36), rect(349, 263, w - 349, 36) }
		out.upgrade = rect(0, 309, w, 42)
	elseif not narrow and h < 352 then
		-- short (a phone in landscape): the quantity and Upgrade move into a column right of the card, so the
		-- whole screen shows without scrolling
		local side = math.min(150, math.floor(w * 0.3))
		local cardW = w - side - 12
		local bodyY, bottom = 58, 8
		local bodyH = math.max(h - bodyY - bottom, (count + 1) * 24)
		local well = math.min(bodyH, 120)
		out.card = rect(0, 0, cardW, bodyY + bodyH + bottom)
		out.name, out.tier = rect(INNER, 4, cardW - INNER * 2, 32), rect(INNER, 36, cardW - INNER * 2, 20)
		out.well = rect(INNER, bodyY, well, well)
		infoBlock(INNER + well + 12, bodyY, cardW - INNER * 2 - well - 12, bodyH)
		out.qtyLabel = rect(0, 0, 0, 0)
		amountRow(w - side, bodyY, side, STRIP_H, 4)
		out.upgrade = rect(w - side, bodyY + STRIP_H + gap, side, UPGRADE_H)
		mainH = out.card.h
	elseif not narrow then
		mainH = math.max(h, 352)
		out.upgrade = rect(0, mainH - UPGRADE_H, w, UPGRADE_H)
		local qtyY = out.upgrade.y - gap - STRIP_H
		local cardH = qtyY - gap
		out.card = rect(0, 0, w, cardH)
		out.name, out.tier = rect(INNER, 8, w - INNER * 2, 36), rect(INNER, 44, w - INNER * 2, 20)
		local well = math.clamp(cardH - 72 - INNER, 100, 200)
		out.well = rect(INNER, 72, well, well)
		infoBlock(INNER + well + 18, 72, w - INNER * 2 - well - 18, well)
		out.qtyLabel = rect(0, qtyY, 110, STRIP_H)
		local stripW = math.floor(w * 0.52)
		amountRow(w - stripW, qtyY, stripW, STRIP_H, 4)
	else
		out.well = rect(INNER, INNER, 84, 84)
		out.name, out.tier = rect(INNER + 96, INNER + 4, w - INNER * 2 - 96, 36), rect(INNER + 96, INNER + 44, w - INNER * 2 - 96, 24)
		local infoH = (count + 1) * 30 + 4
		local infoY = INNER + 84 + 10
		infoBlock(INNER, infoY, w - INNER * 2, infoH)
		out.card = rect(0, 0, w, infoY + infoH + INNER)
		local y = out.card.h + gap
		out.qtyLabel = rect(0, 0, 0, 0)
		amountRow(0, y, w, STRIP_H, 4)
		out.upgrade = rect(0, y + STRIP_H + gap, w, UPGRADE_H)
		mainH = out.upgrade.y + UPGRADE_H
	end
	local canvasH = mainH
	if stackEvolve then
		local card = EquipmentShopLayout.evolve(w, true, true).height
		out.evolve = rect(0, mainH + 12, w, card)
		canvasH = mainH + 12 + card
	else
		out.evolve = rect(0, 0, 0, 0)
	end
	-- the margin
	for key, value in out do
		if key == "amounts" or key == "stats" or key == "dividers" then
			for _, r in value do r.x += MARGIN; r.y += MARGIN end
		elseif type(value) == "table" then
			value.x += MARGIN; value.y += MARGIN
		end
	end
	out.canvasH = canvasH + MARGIN * 2
	return out :: ScreenLayout
end

return EquipmentShopLayout

--!strict
-- The Gear shop's geometry. Panel bounds use screen pixels; everything inside a screen or the evolution body is local to it.
-- On a wide window the evolution opens as its own panel right beside the shop; on a narrow one it becomes a card
-- stacked under the controls (`popout` tells which).
export type Rect = { x: number, y: number, w: number, h: number }
export type Layout = {
	panel: Rect,
	evolvePanel: Rect, -- the pop-out panel beside the shop (its own size even when `popout` is false)
	popout: boolean,
	padding: number,
	headerH: number,
	tabsY: number,
	tabsH: number,
	carouselY: number,
	carouselH: number,
	footerY: number,
	gap: number,
	narrow: boolean,
	compact: boolean, -- phones in landscape: slimmer header and tabs, the footer line moves into the header
}

local EquipmentShopLayout = {}

local SHOP_W, EVOLVE_W, SIDE_GAP = 560, 300, 14

function EquipmentShopLayout.compute(viewport: Vector2, inset: number): Layout
	local topInset = math.max(0, inset)
	local availableWidth = math.max(0, viewport.X - 24)
	local availableHeight = math.max(0, viewport.Y - topInset - 24)
	local panelWidth = math.min(SHOP_W, availableWidth)
	local narrow = panelWidth < 540
	local compact = not narrow and availableHeight < 400
	-- the evolution pops out beside the shop only when both fit side by side
	local popout = availableWidth >= SHOP_W + SIDE_GAP + EVOLVE_W
	-- compact: the title ribbon pokes 16 px above the panel, so keep it under the top bar
	local panelTop = if compact then topInset + 18 else nil
	if panelTop then availableHeight = math.max(0, viewport.Y - panelTop - 12) end
	local panelHeight = math.min(if narrow then 500 else 560, availableHeight)
	local padding = 12
	local sectionGap = 6
	-- compact keeps 44 px for the close button and the tabs (touch targets) but drops the rest of the header
	local headerHeight = if narrow then 80 elseif compact then 44 else 54
	local tabsY = padding + headerHeight
	local tabsHeight = 44
	local carouselY = tabsY + tabsHeight + sectionGap
	local footerY = if compact then panelHeight - padding + sectionGap else panelHeight - padding - 44
	local carouselHeight = math.max(0, footerY - sectionGap - carouselY)
	-- centre the shop, or the shop and its evolution panel together
	local totalWidth = if popout then panelWidth + SIDE_GAP + EVOLVE_W else panelWidth
	local x = (viewport.X - totalWidth) / 2
	local y = panelTop or topInset + 12 + (availableHeight - panelHeight) / 2

	return {
		panel = { x = x, y = y, w = panelWidth, h = panelHeight },
		evolvePanel = { x = x + panelWidth + SIDE_GAP, y = y, w = EVOLVE_W, h = panelHeight },
		popout = popout,
		padding = padding,
		headerH = headerHeight,
		tabsY = tabsY,
		tabsH = tabsHeight,
		carouselY = carouselY,
		carouselH = carouselHeight,
		footerY = footerY,
		gap = 12,
		narrow = narrow,
		compact = compact,
	}
end

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = math.max(0, w), h = math.max(0, h) }
end

-- The evolution body: the next item, its requirements and the two evolve buttons. `w` is its width.
-- Stacked (a card under the shop) it adds a heading and a smaller preview beside the name.
export type EvolveLayout = {
	heading: Rect, well: Rect, name: Rect, tier: Rect, rows: { Rect }, evolve: Rect, alt: Rect, height: number,
}

function EquipmentShopLayout.evolve(w: number, stacked: boolean, altShown: boolean): EvolveLayout
	local out = {} :: any
	local gap = 8
	if not stacked then
		local well = math.min(150, w)
		out.heading = rect(0, 0, 0, 0)
		out.well = rect(math.floor((w - well) / 2), 0, well, well)
		out.name, out.tier = rect(0, well + 8, w, 32), rect(0, well + 40, w, 22)
		local y = well + 74
		out.rows = { rect(0, y, w, 30), rect(0, y + 32, w, 30), rect(0, y + 64, w, 30) }
		y += 108
		out.evolve = rect(0, y, w, 46)
		out.alt = rect(0, y + 54, if altShown then w else 0, 46)
		out.height = y + (if altShown then 100 else 46)
	else
		local pad = 12
		local iw = w - pad * 2
		out.heading = rect(pad, 10, iw, 20)
		out.well = rect(pad, 36, 72, 72)
		out.name, out.tier = rect(pad + 84, 38, iw - 84, 28), rect(pad + 84, 68, iw - 84, 22)
		out.rows = { rect(pad, 118, iw, 28), rect(pad, 148, iw, 28), rect(pad, 178, iw, 28) }
		if altShown then
			local half = math.floor((iw - gap) / 2)
			out.evolve, out.alt = rect(pad, 216, half, 42), rect(pad + half + gap, 216, iw - half - gap, 42)
		else
			out.evolve, out.alt = rect(pad, 216, iw, 42), rect(pad, 216, 0, 42)
		end
		out.height = 216 + 42 + pad
	end
	return out :: EvolveLayout
end

-- One gear screen (pickaxe or backpack): the name over the preview and an info card (the level and what the upgrade
-- gives, `rows` lines), then the quantity picker and Upgrade. Narrow screens stack everything in one column. With
-- `stackEvolve` the evolution card follows at the bottom (`evolve`). A screen shorter than `canvasH` scrolls, and
-- everything keeps a 4 px margin so outlines are not clipped by the scrolling area.
export type ScreenLayout = {
	name: Rect, tier: Rect, well: Rect,
	info: Rect, levelLabel: Rect, levelValue: Rect, stats: { Rect },
	qtyLabel: Rect, amounts: { Rect }, upgrade: Rect,
	evolve: Rect, -- the stacked evolution card (zero-sized when it pops out instead)
	canvasH: number,
}

local MARGIN = 4

function EquipmentShopLayout.screen(width: number, height: number, narrow: boolean, stackEvolve: boolean, rows: number): ScreenLayout
	local w, h = width - MARGIN * 2, height - MARGIN * 2
	local gap = 8
	local count = math.max(rows, 1)
	local out = {} :: any
	local function infoCard(x: number, y: number, iw: number, ih: number)
		out.info = rect(x, y, iw, ih)
		out.levelLabel = rect(x + 14, y + 8, math.floor(iw * 0.4), 36)
		out.levelValue = rect(x + iw - 14 - math.floor(iw * 0.55), y + 8, math.floor(iw * 0.55), 36)
		local rowH = math.clamp(math.floor((ih - 60) / count), 24, 40)
		out.stats = {}
		for index = 1, count do table.insert(out.stats, rect(x + 14, y + 52 + (index - 1) * rowH, iw - 28, rowH)) end
	end
	local function amountRow(x: number, y: number, aw: number)
		local each = math.floor((aw - gap * 2) / 3)
		out.amounts = { rect(x, y, each, 40), rect(x + each + gap, y, each, 40), rect(x + (each + gap) * 2, y, aw - (each + gap) * 2, 40) }
	end
	local mainH
	if not narrow then
		mainH = math.max(h, 352)
		out.name, out.tier = rect(0, 0, w, 36), rect(0, 36, w, 22)
		out.upgrade = rect(0, mainH - 52, w, 52)
		local qtyY = out.upgrade.y - gap - 40
		local well = math.clamp(qtyY - gap - 64, 120, 200)
		out.well = rect(0, 64, well, well)
		infoCard(well + 16, 64, w - well - 16, well)
		out.qtyLabel = rect(0, qtyY, 110, 40)
		amountRow(116, qtyY, w - 116)
	else
		out.well = rect(0, 0, 84, 84)
		out.name, out.tier = rect(96, 6, w - 96, 36), rect(96, 44, w - 96, 24)
		local infoH = 52 + count * 30 + 8
		infoCard(0, 96, w, infoH)
		local y = 96 + infoH + gap
		out.qtyLabel = rect(0, 0, 0, 0)
		amountRow(0, y, w)
		out.upgrade = rect(0, y + 48, w, 52)
		mainH = y + 48 + 52
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
		if key == "amounts" or key == "stats" then
			for _, r in value do r.x += MARGIN; r.y += MARGIN end
		elseif type(value) == "table" then
			value.x += MARGIN; value.y += MARGIN
		end
	end
	out.canvasH = canvasH + MARGIN * 2
	return out :: ScreenLayout
end

return EquipmentShopLayout

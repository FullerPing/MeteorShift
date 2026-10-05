--!strict
-- Panel bounds use screen pixels; all remaining positions are local to the panel.
-- Cards retain their readable dimensions when the carousel needs both scroll axes.
export type Rect = { x: number, y: number, w: number, h: number }
export type Layout = {
	panel: Rect,
	padding: number,
	headerH: number,
	tabsY: number,
	tabsH: number,
	carouselY: number,
	carouselH: number,
	footerY: number,
	cardWidth: number,
	cardHeight: number,
	gap: number,
	short: boolean,
	narrow: boolean,
	pet: boolean?,
}

local EquipmentShopLayout = {}

function EquipmentShopLayout.compute(viewport: Vector2, inset: number): Layout
	local topInset = math.max(0, inset)
	local availableWidth = math.max(0, viewport.X - 24)
	local availableHeight = math.max(0, viewport.Y - topInset - 24)
	local panelWidth = math.min(860, availableWidth)
	local narrow = panelWidth < 540
	local panelHeight = math.min(if narrow then 500 else 520, availableHeight)
	local padding = 12
	local sectionGap = 6
	local headerHeight = if narrow then 80 else 54
	local tabsY = padding + headerHeight
	local tabsHeight = 44
	local carouselY = tabsY + tabsHeight + sectionGap
	local footerY = panelHeight - padding - 44
	local carouselHeight = math.max(0, footerY - sectionGap - carouselY)
	local short = not narrow and carouselHeight < 254
	local innerWidth = math.max(0, panelWidth - padding * 2)
	local cardWidth = math.min(innerWidth, if narrow then 260 elseif short then 430 else 352)
	-- Four pixels belong to the horizontal scrollbar, plus eight to card canvas padding.
	local cardHeight = if narrow then math.max(270, math.min(300, carouselHeight - 12))
		elseif short then math.max(166, math.min(250, carouselHeight - 12))
		else math.max(242, math.min(250, carouselHeight - 12))

	return {
		panel = {
			x = (viewport.X - panelWidth) / 2,
			y = topInset + 12 + (availableHeight - panelHeight) / 2,
			w = panelWidth,
			h = panelHeight,
		},
		padding = padding,
		headerH = headerHeight,
		tabsY = tabsY,
		tabsH = tabsHeight,
		carouselY = carouselY,
		carouselH = carouselHeight,
		footerY = footerY,
		cardWidth = cardWidth,
		cardHeight = cardHeight,
		gap = 12,
		short = short,
		narrow = narrow,
	}
end

-- Every card on this carousel must share a height: the tallest pet determines
-- its vertical canvas, including when the viewer is looking at the first eggs.
function EquipmentShopLayout.petCards(layout: Layout): Layout
	local cards = table.clone(layout)
	cards.pet = true
	cards.cardHeight = if cards.short then 310 else 410
	return cards
end

return EquipmentShopLayout

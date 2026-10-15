--!strict
-- Panel and touch controls use screen pixels. Mineral cards wrap and scroll vertically. The panel is drawn in the cartoon
-- light look: its title ribbon pokes 24 px above it, its lip hangs 7 px below it and Close sits on its top right corner.
export type Rect = { x: number, y: number, w: number, h: number }
export type Layout = {
	panel: Rect, title: Rect, close: Rect, tabs: Rect, content: Rect,
	padding: number, tabWidth: number, tabGap: number, summaryWidth: number,
	columns: number, cardWidth: number, cardHeight: number, gap: number,
	cardsY: number, narrow: boolean,
}

local IndexLayout = {}
IndexLayout.RibbonRoom = 28 -- between the top bar and the panel (the ribbon is 24 px above it)
IndexLayout.FootRoom = 15 -- under the panel: the 7 px lip and a margin
IndexLayout.RibbonWidth = 278 -- the ribbon's right edge on the panel, where the subtitle starts

function IndexLayout.compute(viewport: Vector2, inset: number): Layout
	local topInset = math.max(0, inset)
	local availableWidth = math.max(0, viewport.X - 24)
	-- room for the ribbon above the panel (IndexLayout.RibbonRoom) and the lip and a margin below it (FootRoom)
	local availableHeight = math.max(0, viewport.Y - topInset - IndexLayout.RibbonRoom - IndexLayout.FootRoom)
	-- phones in landscape: wider, from just under the top bar to the bottom, so more of the scrolling page shows
	local short = availableWidth >= 540 and availableHeight < 380
	local panelTop = if short then topInset + IndexLayout.RibbonRoom else nil
	local width, height = math.min(if short then 860 else 740, availableWidth), math.min(620, availableHeight)
	local padding, tabGap, gap = 12, 8, 12
	local innerWidth = math.max(0, width - padding * 2)
	-- Four pixels of card padding on each side, plus the vertical scrollbar.
	local summaryWidth = math.max(0, innerWidth - 12)
	local columns = math.clamp(math.floor((summaryWidth + gap) / (156 + gap)), 1, 4)
	local narrow = width < 540

	return {
		panel = {
			x = (viewport.X - width) / 2,
			y = panelTop or topInset + IndexLayout.RibbonRoom + (availableHeight - height) / 2,
			w = width, h = height,
		},
		-- a subtitle right of the ribbon (none on narrow panels), Close on the corner (half outside the panel)
		title = if width - IndexLayout.RibbonWidth - 56 > 0
			then { x = IndexLayout.RibbonWidth, y = 8, w = width - IndexLayout.RibbonWidth - 56, h = 30 }
			else { x = padding, y = 8, w = 0, h = 30 },
		close = { x = width - 40, y = -14, w = 48, h = 50 },
		tabs = { x = padding, y = 52, w = innerWidth, h = 46 },
		content = { x = padding, y = 110, w = innerWidth, h = math.max(0, height - 110 - 7 - 8) },
		padding = padding, tabWidth = math.floor((innerWidth - tabGap * 2) / 3), tabGap = tabGap,
		summaryWidth = summaryWidth, columns = columns,
		cardWidth = math.max(0, math.floor((summaryWidth - (columns - 1) * gap) / columns)),
		cardHeight = 222, gap = gap, cardsY = if narrow then 208 else 132, narrow = narrow,
	}
end

function IndexLayout.gridHeight(layout: Layout, mineralCount: number): number
	local rows = math.ceil(math.max(0, math.floor(mineralCount)) / layout.columns)
	return if rows == 0 then 0 else rows * layout.cardHeight + (rows - 1) * layout.gap
end

function IndexLayout.canvasHeight(layout: Layout, mineralCount: number): number
	return layout.cardsY + IndexLayout.gridHeight(layout, mineralCount) + 80
end

return IndexLayout

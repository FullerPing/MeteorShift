--!strict
-- Panel and touch controls use screen pixels. Mineral cards wrap and scroll vertically.
export type Rect = { x: number, y: number, w: number, h: number }
export type Layout = {
	panel: Rect, title: Rect, close: Rect, tabs: Rect, content: Rect,
	padding: number, tabWidth: number, tabGap: number, summaryWidth: number,
	columns: number, cardWidth: number, cardHeight: number, gap: number,
	cardsY: number, narrow: boolean,
}

local IndexLayout = {}

function IndexLayout.compute(viewport: Vector2, inset: number): Layout
	local topInset = math.max(0, inset)
	local availableWidth = math.max(0, viewport.X - 24)
	local availableHeight = math.max(0, viewport.Y - topInset - 24)
	local width, height = math.min(740, availableWidth), math.min(620, availableHeight)
	local padding, tabGap, gap = 12, 8, 12
	local innerWidth = math.max(0, width - padding * 2)
	-- Four pixels of card padding on each side, plus the vertical scrollbar.
	local summaryWidth = math.max(0, innerWidth - 12)
	local columns = math.clamp(math.floor((summaryWidth + gap) / (156 + gap)), 1, 4)
	local narrow = width < 540

	return {
		panel = {
			x = (viewport.X - width) / 2,
			y = topInset + 12 + (availableHeight - height) / 2,
			w = width, h = height,
		},
		title = { x = padding, y = 8, w = math.max(0, innerWidth - 52), h = 36 },
		close = { x = width - padding - 44, y = 4, w = 44, h = 44 },
		tabs = { x = padding, y = 56, w = innerWidth, h = 44 },
		content = { x = padding, y = 112, w = innerWidth, h = math.max(0, height - 124) },
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

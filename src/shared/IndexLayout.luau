--!strict
-- The Mineral Index's geometry, laid out as the owner's mockup (Craterworks Menu Redesign, 2026-10-15): an 860 x 572 panel
-- in the cartoon light look (its title ribbon pokes 24 px above it, its lip hangs 7 px below it and Close sits on its top
-- right corner), the index bonus chip left of Close, one tab per meteor page, then the page's minerals as a scrolling grid
-- of wide cards on the left and a side column on the right (the page's progress and reward, your best title). Narrow
-- panels (portrait phones) drop the side column and the chip; the tabs still show each page's count.
-- Panel bounds are virtual screen pixels (MenuFit); every other rect is local to the panel.
export type Rect = { x: number, y: number, w: number, h: number }
export type Layout = {
	panel: Rect, close: Rect, chip: Rect, tabs: Rect, grid: Rect, side: Rect,
	padding: number, tabWidth: number, tabGap: number,
	columns: number, cardWidth: number, cardHeight: number, gap: number,
	narrow: boolean,
}

local IndexLayout = {}
IndexLayout.Size = Vector2.new(860, 572)
IndexLayout.RibbonRoom = 28 -- between the top bar and the panel (the ribbon is 24 px above it)
IndexLayout.FootRoom = 15 -- under the panel: the 7 px lip and a margin
IndexLayout.RibbonRight = 276 -- the ribbon's right edge on the panel; the chip stays right of it
IndexLayout.SideWidth = 236
IndexLayout.MinCard = 250 -- a card fits its gem well, the name and the odds pill
IndexLayout.CardHeight = 112
IndexLayout.Scrollbar = 12 -- the grid's scrollbar and padding

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = w, h = h }
end

function IndexLayout.compute(viewport: Vector2, inset: number): Layout
	local topInset = math.max(0, inset)
	local roomW = math.max(0, viewport.X - 24)
	local roomH = math.max(0, viewport.Y - topInset - IndexLayout.RibbonRoom - IndexLayout.FootRoom)
	local width, height = math.min(IndexLayout.Size.X, roomW), math.min(IndexLayout.Size.Y, roomH)
	local pad, tabGap, gap = 20, 8, 10
	local innerW = math.max(0, width - pad * 2)
	local narrow = width < 640
	local chipW = 170
	local chipX = width - 56 - chipW
	local chip = if chipX >= IndexLayout.RibbonRight then rect(chipX, 12, chipW, 32) else rect(0, 0, 0, 0)
	local top = 114
	local bodyH = math.max(0, height - top - 7 - 12)
	local side = if narrow then rect(0, 0, 0, 0) else rect(width - pad - IndexLayout.SideWidth, top, IndexLayout.SideWidth, bodyH)
	local grid = rect(pad, top, if narrow then innerW else innerW - IndexLayout.SideWidth - 14, bodyH)
	local cardsW = math.max(0, grid.w - IndexLayout.Scrollbar)
	local columns = math.clamp(math.floor((cardsW + gap) / (IndexLayout.MinCard + gap)), 1, 3)
	return {
		panel = rect((viewport.X - width) / 2, topInset + IndexLayout.RibbonRoom + (roomH - height) / 2, width, height),
		close = rect(width - 40, -14, 48, 50),
		chip = chip,
		tabs = rect(pad, 56, innerW, 46),
		grid = grid,
		side = side,
		padding = pad, tabGap = tabGap, tabWidth = math.min(190, math.floor((innerW - tabGap * 2) / 3)),
		columns = columns,
		cardWidth = math.max(0, math.floor((cardsW - (columns - 1) * gap) / columns)),
		cardHeight = IndexLayout.CardHeight, gap = gap, narrow = narrow,
	}
end

function IndexLayout.gridHeight(layout: Layout, mineralCount: number): number
	local rows = math.ceil(math.max(0, math.floor(mineralCount)) / layout.columns)
	return if rows == 0 then 0 else rows * layout.cardHeight + (rows - 1) * layout.gap
end

-- the grid's scrolling canvas: the cards and the odds note under them
function IndexLayout.canvasHeight(layout: Layout, mineralCount: number): number
	return IndexLayout.gridHeight(layout, mineralCount) + 8 + 56
end

return IndexLayout

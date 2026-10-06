--!strict
-- Keep shop copy readable on phones, with full-size purchase targets in a scroll grid.
-- Cards follow the cartoon store: a big icon on top, a chunky title tucked under
-- it, the description, an optional status line and a tall price button.
local StoreLayout = {}
function StoreLayout.compute(viewport: Vector2, inset: number, count: number)
	local width = math.min(900, math.max(1, viewport.X - 24))
	local height = math.min(680, math.max(1, viewport.Y - inset - 24))
	local columns = if width < 480 then 1 elseif width < 760 then 2 else 3
	local gap = if width < 480 then 10 else 16
	local paddingList = if width < 480 then 8 else 14
	local cardWidth = math.floor((width - 28 - 2 * paddingList - 6 - (columns - 1) * gap) / columns)
	local compact = cardWidth < 180
	local padding = if compact then 10 else 14
	local iconSize = math.clamp(math.floor(cardWidth * .46), 56, 128)
	local charactersPerLine = math.max(8, math.floor((cardWidth - 2 * padding) / 7))
	local descriptionHeight = if compact then math.max(96, math.ceil(130 / charactersPerLine) * 16) else 48
	local statusHeight = if compact then math.max(48, math.ceil(78 / charactersPerLine) * 16) else 22
	local buttonHeight = 52
	local kindY = 10
	local iconY = 22
	local priceY = iconY -- the price lives on the button; kept for callers that still read it
	local titleY = iconY + iconSize - 4
	local titleHeight = if compact then 30 else 38
	local descriptionY = titleY + titleHeight + 2
	local statusY = descriptionY + descriptionHeight + 2
	local cardHeight = statusY + statusHeight + 8 + buttonHeight + 14
	local rows = math.ceil(count / columns)
	return { width = width, height = height, columns = columns, gap = gap, paddingList = paddingList,
		cardWidth = cardWidth, cardHeight = cardHeight, compact = compact, padding = padding, iconSize = iconSize,
		kindY = kindY, iconY = iconY, titleHeight = titleHeight, buttonHeight = buttonHeight,
		descriptionHeight = descriptionHeight, statusHeight = statusHeight, priceY = priceY, titleY = titleY,
		descriptionY = descriptionY, statusY = statusY, canvasHeight = rows * cardHeight + math.max(0, rows - 1) * gap + 2 * paddingList }
end
return StoreLayout

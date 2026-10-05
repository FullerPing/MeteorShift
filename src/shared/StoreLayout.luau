--!strict
-- Keep shop copy readable on phones, with full-size purchase targets in a scroll grid.
local StoreLayout = {}
function StoreLayout.compute(viewport: Vector2, inset: number, count: number)
	local width = math.min(900, math.max(1, viewport.X - 24))
	local height = math.min(680, math.max(1, viewport.Y - inset - 24))
	local columns = if width < 480 then 1 elseif width < 760 then 2 else 3
	local gap = if width < 480 then 8 else 12
	local paddingList = if width < 480 then 6 else 12
	local cardWidth = math.floor((width - 28 - 2 * paddingList - 6 - (columns - 1) * gap) / columns)
	local compact = cardWidth < 180
	local padding = if compact then 8 else 12
	local iconSize = math.clamp(math.floor(cardWidth * .40), 48, 100)
	local charactersPerLine = math.max(8, math.floor((cardWidth - 2 * padding) / 6.3))
	local descriptionHeight = if compact then math.max(96, math.ceil(130 / charactersPerLine) * 15) else 64
	local statusHeight = if compact then math.max(56, math.ceil(78 / charactersPerLine) * 15) else 42
	local priceY = 28 + iconSize + 6
	local titleY = priceY + 28 + 6
	local descriptionY = titleY + 44 + 6
	local statusY = descriptionY + descriptionHeight + 4
	local cardHeight = statusY + statusHeight + 8 + 44 + 12
	local rows = math.ceil(count / columns)
	return { width = width, height = height, columns = columns, gap = gap, paddingList = paddingList,
		cardWidth = cardWidth, cardHeight = cardHeight, compact = compact, padding = padding, iconSize = iconSize,
		descriptionHeight = descriptionHeight, statusHeight = statusHeight, priceY = priceY, titleY = titleY,
		descriptionY = descriptionY, statusY = statusY, canvasHeight = rows * cardHeight + math.max(0, rows - 1) * gap + 2 * paddingList }
end
return StoreLayout

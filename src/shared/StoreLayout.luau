--!strict
-- Keep shop copy readable on phones, with full-size purchase targets in one scrolling page of
-- titled sections (Config.Store). `compute` sizes the panel, the scroll area and the tab strip
-- for a screen; `card` lays out one card at a given width for either card style:
--   tile: a big icon on top, a chunky title under it, the description, an optional status line
--         and a tall price button (centred text);
--   wide: the icon on the left with the title, description and status beside it and the price
--         button across the bottom (left-aligned text).
local StoreLayout = {}

function StoreLayout.compute(viewport: Vector2, inset: number)
	local width = math.min(900, math.max(1, viewport.X - 24))
	local narrow = width < 480
	-- phones in landscape: the panel runs from just under the top bar (its title ribbon pokes above it) to the
	-- bottom, with three smaller cards across so a whole row fits and icon-only tabs
	local short = width >= 480 and viewport.Y - inset < 400
	local top = if short then inset + 18 else nil
	local height = if top then math.max(1, viewport.Y - top - 8) else math.min(680, math.max(1, viewport.Y - inset - 24))
	local tabWidth = if narrow then 0 elseif short then 58 else 94
	local gap = if narrow then 10 elseif short then 12 else 16
	local paddingList = if narrow then 8 else 14
	local listWidth = width - 28 - (if tabWidth > 0 then tabWidth + 10 else 0)
	local inner = listWidth - 2 * paddingList - 6
	local tileColumns = if narrow then 1 elseif short or inner >= 640 then 3 else 2
	local wideColumns = if inner >= 520 then 2 else 1
	return { width = width, height = height, top = top, short = short, narrow = narrow, tabWidth = tabWidth,
		tabCaptions = not short, gap = gap, paddingList = paddingList, listWidth = listWidth, inner = inner,
		tileColumns = tileColumns, wideColumns = wideColumns }
end

-- Cards across for a section: wide cards go two across (one alone is a full-width banner)
function StoreLayout.columns(g: any, style: string, count: number): number
	if style == "wide" then
		return if count <= 1 then 1 else g.wideColumns
	end
	return g.tileColumns
end

function StoreLayout.cardWidth(g: any, columns: number): number
	return math.floor((g.inner - (columns - 1) * g.gap) / columns)
end

function StoreLayout.card(cardWidth: number, style: string, short: boolean)
	local wide = style == "wide"
	if wide then
		local compact = cardWidth < 300
		local padding = if compact or short then 10 else 14
		local iconSize = if short then 64 elseif compact then 76 else 96
		local textX = padding + iconSize + padding
		local titleY = 24
		local titleHeight = if short then 28 else 34
		local descriptionY = titleY + titleHeight
		local descriptionHeight = if short then 36 else 48
		local statusY = descriptionY + descriptionHeight
		local statusHeight = if short then 16 else 20
		local buttonHeight = if short then 42 else 50
		return { wide = true, cardWidth = cardWidth, compact = compact, padding = padding, iconSize = iconSize,
			iconX = padding, iconY = 28, textX = textX, textWidth = math.max(60, cardWidth - textX - padding),
			kindY = 8, titleY = titleY, titleHeight = titleHeight, descriptionY = descriptionY,
			descriptionHeight = descriptionHeight, statusY = statusY, statusHeight = statusHeight,
			buttonHeight = buttonHeight, cardHeight = statusY + statusHeight + 6 + buttonHeight + padding }
	end
	local compact = cardWidth < 180
	local padding = if compact then 10 else 14
	local iconSize = math.clamp(math.floor(cardWidth * .46), 56, if short then 64 else 128)
	local charactersPerLine = math.max(8, math.floor((cardWidth - 2 * padding) / 7))
	local descriptionHeight = if compact then math.max(96, math.ceil(130 / charactersPerLine) * 16) elseif short then 40 else 48
	local statusHeight = if compact then math.max(48, math.ceil(78 / charactersPerLine) * 16) else 22
	local buttonHeight = if short then 42 else 52
	local iconY = 22
	local titleY = iconY + iconSize - 4
	local titleHeight = if compact or short then 30 else 38
	local descriptionY = titleY + titleHeight + 2
	local statusY = descriptionY + descriptionHeight + 2
	return { wide = false, cardWidth = cardWidth, compact = compact, padding = padding, iconSize = iconSize,
		iconY = iconY, textX = padding, textWidth = cardWidth - 2 * padding, kindY = 10, titleY = titleY,
		titleHeight = titleHeight, descriptionY = descriptionY, descriptionHeight = descriptionHeight,
		statusY = statusY, statusHeight = statusHeight, buttonHeight = buttonHeight,
		cardHeight = statusY + statusHeight + 8 + buttonHeight + (if short then 10 else 14) }
end

return StoreLayout

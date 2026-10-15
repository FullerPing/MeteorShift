--!strict
-- The Foundry window's geometry, laid out as the owner's mockup (Craterworks Menu Redesign, 2026-10-15): REFINE / UPGRADES
-- tabs, three equal cards for the production line (ore hopper -> foundry -> finished bars, arrows between them), the
-- refining order in a soft card under them and a feedback line along the bottom. Roomy panels show each card's icon well;
-- short ones (phones in landscape) move the tabs up beside the title ribbon and drop the wells so the order keeps rows.
-- Every rect is local to the panel (whose size MenuFit decides).
export type Rect = { x: number, y: number, w: number, h: number }
export type Layout = {
	short: boolean, wells: boolean,
	tabs: Rect, cards: { Rect }, arrows: { Rect }, order: Rect, feedback: Rect, upgrades: Rect,
	cardH: number, row: number,
}

local RefineryLayout = {}
RefineryLayout.Size = Vector2.new(860, 572)
RefineryLayout.ShortHeight = 520 -- below this the tabs go up beside the ribbon and the wells go
RefineryLayout.RibbonRight = 276 -- the ribbon's right edge on the panel
RefineryLayout.Row = 38 -- a refining order row
RefineryLayout.OrderHeader = 40 -- the order card's heading row

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = w, h = h }
end

function RefineryLayout.compute(width: number, height: number): Layout
	local pad = 20
	local innerW = math.max(0, width - pad * 2)
	-- the tabs go up beside the ribbon only when there is room between it and Close
	local short = height < RefineryLayout.ShortHeight and width - 56 - RefineryLayout.RibbonRight >= 240
	local tabs = if short then rect(RefineryLayout.RibbonRight + 8, 6, math.min(300, width - 56 - RefineryLayout.RibbonRight - 16), 42)
		else rect(pad, 54, math.min(360, innerW), 46)
	local wells = height >= RefineryLayout.ShortHeight
	local cardsY = if short then 54 else 112
	local cardH = if wells then 236 else 140
	local gap = if width < 600 then 14 else 30
	local cardW = math.floor((innerW - gap * 2) / 3)
	local cards, arrows = {}, {}
	for index = 1, 3 do
		local x = pad + (index - 1) * (cardW + gap)
		table.insert(cards, rect(x, cardsY, cardW, cardH))
		if index < 3 then
			local size = math.min(26, gap - 2)
			table.insert(arrows, rect(x + cardW + (gap - size) / 2, cardsY + cardH / 2 - size / 2, size, size))
		end
	end
	local feedback = rect(pad, height - 7 - 8 - 22, innerW, 22)
	local orderY = cardsY + cardH + (if wells then 12 else 10)
	return {
		short = short, wells = wells,
		tabs = tabs, cards = cards, arrows = arrows,
		order = rect(pad, orderY, innerW, math.max(0, feedback.y - 6 - orderY)),
		feedback = feedback,
		upgrades = rect(pad, cardsY, innerW, math.max(0, feedback.y - 6 - cardsY)),
		cardH = cardH, row = RefineryLayout.Row,
	}
end

return RefineryLayout

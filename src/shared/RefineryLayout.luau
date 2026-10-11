--!strict
-- Reserve an inventory row and footer before adding secondary refinery headings.
-- Roomy windows (flow) show the production line as three cards, ore -> foundry -> bars, with the refining order below;
-- phones and short windows keep the two-card layout with a status line.
local RefineryLayout = {}

RefineryLayout.FlowMinHeight = 480
RefineryLayout.FlowMinWidth = 520

function RefineryLayout.compute(height: number, width: number?)
	local compact = height < 420
	local minimal = height < 298
	local hideStatus = height < 362
	local flow = height >= RefineryLayout.FlowMinHeight and (width or 620) >= RefineryLayout.FlowMinWidth
	local list = if minimal then 154 elseif hideStatus then 198 elseif compact then 252 elseif flow then 348 else 316
	return {
		compact = compact, minimal = minimal, hideStatus = hideStatus, flow = flow,
		title = if compact then 8 else 16, rate = if compact then 37 else 48,
		actions = if compact then 100 elseif flow then 104 else 108,
		actionH = if minimal then 44 elseif compact then 82 elseif flow then 206 else 116,
		status = if compact then 188 else 240,
		progress = if minimal then 148 elseif hideStatus then 188 elseif compact then 216 else 271,
		totals = if compact then 224 elseif flow then 324 else 284,
		list = list, inventoryHeight = math.max(0, height - list - 56),
		row = if compact then 52 elseif flow then 56 else 60,
	}
end

return RefineryLayout

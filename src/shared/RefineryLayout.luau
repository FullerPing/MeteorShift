--!strict
-- Reserve an inventory row and footer before adding secondary refinery headings.
local RefineryLayout = {}

function RefineryLayout.compute(height: number)
	local compact = height < 420
	local minimal = height < 298
	local hideStatus = height < 362
	local list = if minimal then 154 elseif hideStatus then 198 elseif compact then 252 else 316
	return {
		compact = compact, minimal = minimal, hideStatus = hideStatus,
		title = if compact then 8 else 16, rate = if compact then 37 else 48,
		actions = if compact then 100 else 108,
		actionH = if minimal then 44 elseif compact then 82 else 116,
		status = if compact then 188 else 240,
		progress = if minimal then 148 elseif hideStatus then 188 elseif compact then 216 else 271,
		totals = if compact then 224 else 284,
		list = list, inventoryHeight = math.max(0, height - list - 56),
		row = if compact then 52 else 60,
	}
end

return RefineryLayout

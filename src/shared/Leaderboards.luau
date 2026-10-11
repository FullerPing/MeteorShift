--!strict
-- Leaderboard rules shared by the server and the specs: reading a score from a profile and ranking entries.
local Leaderboards = {}

export type Entry = { userId: number, name: string, value: number }

-- The board's score in a profile: a whole, non-negative number (0 when missing or malformed)
function Leaderboards.valueOf(path: { string }, data: any): number
	local value = data
	for _, key in path do
		if typeof(value) ~= "table" then return 0 end
		value = value[key]
	end
	if typeof(value) ~= "number" or value ~= value or value == math.huge then return 0 end
	return math.max(0, math.floor(value))
end

-- The top `rows` entries, highest first; ties go to the lower user id (the earlier account), so the order is stable.
-- Zero scores are left off.
function Leaderboards.rank(entries: { Entry }, rows: number): { Entry }
	local ranked = {}
	for _, entry in entries do
		if entry.value > 0 then table.insert(ranked, entry) end
	end
	table.sort(ranked, function(a, b)
		if a.value ~= b.value then return a.value > b.value end
		return a.userId < b.userId
	end)
	while #ranked > rows do table.remove(ranked) end
	return ranked
end

return Leaderboards

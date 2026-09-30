--!strict
-- Picking the swing target when there is no pointer to aim with (spec §10, touch MINE
-- button): the nearest mineable target in reach and in front of the character. Pure, so
-- tests/Aim.spec.luau covers it. The server re-checks range on every swing whatever this
-- picks (NodeService), so this only chooses what to ask for.

local Aim = {}

export type Candidate = {
	distance: number, -- studs from the character to the nearest point of the target
	dot: number, -- dot product of the character's facing and the direction to the target
	core: boolean, -- an exposed core
}

-- Index of the best candidate, or nil. `range` is the mining range, `frontDot` the least
-- dot product that counts as "in front", `coreBonus` studs taken off a core's distance so
-- an exposed core wins over crust when both are in reach.
function Aim.nearest(candidates: { Candidate }, range: number, frontDot: number, coreBonus: number): number?
	local best: number? = nil
	local bestScore = math.huge
	for i, candidate in candidates do
		if candidate.distance <= range and candidate.dot >= frontDot then
			local score = candidate.distance - (if candidate.core then coreBonus else 0)
			if score < bestScore then
				best, bestScore = i, score
			end
		end
	end
	return best
end

return Aim

--!strict
-- Client presentation limits, independent of characters and rendering.
local Config = require(script.Parent.Config.Pets)

export type Entry = { id: string, level: number, slot: number }
export type Candidate = { userId: number, distance: number, count: number }
export type Picked = { userId: number, slot: number }

local PetVisuals = { Budget = 40, CullDistance = 150, WobbleSeconds = 1.5, BlockSeconds = 2 }
local known: { [string]: boolean } = {}
for _, def in Config.List do known[def.Id] = true end

local function finite(value: number?, fallback: number): number
	return if value and value == value and math.abs(value) < math.huge then value else fallback
end

function PetVisuals.loadout(ids: string?, levels: string?, slots: number?): { Entry }
	local out: { Entry } = {}
	if not ids or ids == "" then return out end
	local levelList = string.split(levels or "", ",")
	local seen: { [string]: boolean } = {}
	local limit = math.clamp(math.floor(finite(slots, 3)), 0, 4)
	for index, id in string.split(ids, ",") do
		if #out >= limit then break end
		if known[id] and not seen[id] then
			seen[id] = true
			local level = math.clamp(math.floor(finite(tonumber(levelList[index]), 1)), 1, Config.MaxLevel)
			table.insert(out, { id = id, level = level, slot = #out + 1 })
		end
	end
	return out
end

function PetVisuals.select(candidates: { Candidate }, localUserId: number, budget: number?): { Picked }
	local nearby: { Candidate } = {}
	for _, candidate in candidates do
		if candidate.distance >= 0 and candidate.distance <= PetVisuals.CullDistance then
			table.insert(nearby, candidate)
		end
	end
	table.sort(nearby, function(a, b)
		if a.userId == localUserId then return b.userId ~= localUserId end
		if b.userId == localUserId then return false end
		return if a.distance == b.distance then a.userId < b.userId else a.distance < b.distance
	end)
	local limit = math.clamp(math.floor(finite(budget, PetVisuals.Budget)), 0, PetVisuals.Budget)
	local out: { Picked } = {}
	for _, candidate in nearby do
		for slot = 1, math.clamp(math.floor(finite(candidate.count, 0)), 0, 4) do
			if #out >= limit then return out end
			table.insert(out, { userId = candidate.userId, slot = slot })
		end
	end
	return out
end

function PetVisuals.hatchStage(elapsed: number, reduced: boolean): string
	if elapsed >= PetVisuals.BlockSeconds then return "settled" end
	return if not reduced and elapsed < PetVisuals.WobbleSeconds then "wobble" else "reveal"
end

function PetVisuals.hatchBlocking(elapsed: number): boolean
	return elapsed < PetVisuals.BlockSeconds
end

return PetVisuals

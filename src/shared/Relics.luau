--!strict
-- Relic rules (Config.Relics): rolling a find, adding it to the saved table, and the boosts they give. Pure;
-- RelicService owns profile.relics = { owned = { [id] = true }, fragments = n } and tests/Relics.spec covers this.
local Config = require(script.Parent.Config.Relics)

local Relics = {}

export type Saved = { owned: { [string]: boolean }, fragments: number }

local byId: { [string]: Config.Relic } = {}
for _, relic in Config.List do byId[relic.Id] = relic end

function Relics.def(id: string): Config.Relic?
	return byId[id]
end

function Relics.clean(saved: any): Saved
	local owned: { [string]: boolean } = {}
	if type(saved) == "table" and type(saved.owned) == "table" then
		for id, value in saved.owned do
			if type(id) == "string" and byId[id] and value == true then owned[id] = true end
		end
	end
	local fragments = if type(saved) == "table" and type(saved.fragments) == "number" and saved.fragments == saved.fragments then math.max(0, math.floor(saved.fragments)) else 0
	return { owned = owned, fragments = fragments }
end

function Relics.count(saved: Saved): number
	local n = 0
	for _ in saved.owned do n += 1 end
	return n
end

-- One roll: `chance` of a find, then `pick` (uniform in [0, 1)) chooses which relic. Nil when nothing is found.
function Relics.roll(chance: number, roll: number, pick: number): string?
	if not (roll < chance) or #Config.List == 0 then return nil end
	return Config.List[math.min(math.floor(math.clamp(pick, 0, 1 - 1e-9) * #Config.List) + 1, #Config.List)].Id
end

-- Adds a found relic: new ones are kept, duplicates become fragments. Returns whether it was new.
function Relics.add(saved: Saved, id: string): boolean
	if not byId[id] then return false end
	if saved.owned[id] then
		saved.fragments += Config.DuplicateFragments
		return false
	end
	saved.owned[id] = true
	return true
end

-- Adds the owned relics' boosts to a bonuses table (a copy; pet totals are already capped, relics go on top)
function Relics.addTo(bonuses: { [string]: number }, saved: Saved?): { [string]: number }
	local out = table.clone(bonuses)
	if saved then
		for id in saved.owned do
			local relic = byId[id]
			if relic then out[relic.Role] = (out[relic.Role] or 0) + relic.Value end
		end
	end
	return out
end

return Relics

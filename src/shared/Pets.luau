--!strict
-- Pet rules (Config.Pets): perks by level, XP, slots, and the saved-data checks.
-- Pure functions, covered by tests/Pets.spec; PetService, PlayerStateService and
-- EconomyService use them.
--
--   perk(role, level)       what a pet of that role gives at that level
--   bonuses(pets)           the equipped pets' perks added up per role, to each role's cap
--   slots(rebirths)         how many pets can be out
--   xpToNext(level)         XP to the next level, nil at the max
--   addXp(entry, xp)        adds XP to a { level, xp } entry, levelling up; returns levels gained
--   clean(saved, rebirths)  a saved `pets` table made legal: known pets, levels in range,
--                           equipped ones owned, unique and within the slots

local Config = require(script.Parent.Config.Pets)

local Pets = {}

export type Entry = { level: number, xp: number }
export type Saved = { owned: { [string]: Entry }, equipped: { string } }
export type Bonuses = { miner: number, hauler: number, pack: number, swift: number, merchant: number }

local byId: { [string]: Config.Pet } = {}
for _, pet in Config.List do
	byId[pet.Id] = pet
end

function Pets.def(petId: string): Config.Pet?
	return byId[petId]
end

-- A role's perk at a pet level: Min at level 1 growing to Max at the max level
function Pets.perk(role: string, level: number): number
	local def = Config.Roles[role]
	if not def then
		return 0
	end
	local fraction = (math.clamp(level, 1, Config.MaxLevel) - 1) / math.max(Config.MaxLevel - 1, 1)
	return def.Min + (def.Max - def.Min) * fraction
end

function Pets.slots(rebirths: number?): number
	local slots = Config.Slots
	return math.min(slots.Base + slots.PerRebirth * math.max(math.floor(rebirths or 0), 0), slots.Max)
end

function Pets.xpToNext(level: number): number?
	if level >= Config.MaxLevel then
		return nil
	end
	return math.floor(Config.XpBase * Config.XpGrowth ^ (math.max(level, 1) - 1) + 0.5)
end

-- Adds XP to a pet entry (mutates it), carrying the overflow into the next levels. A pet at
-- the max level keeps 0 XP. Returns how many levels it gained.
function Pets.addXp(entry: Entry, xp: number): number
	if xp <= 0 or entry.level >= Config.MaxLevel then
		return 0
	end
	local gained = 0
	entry.xp += xp
	while true do
		local needed = Pets.xpToNext(entry.level)
		if not needed or entry.xp < needed then
			break
		end
		entry.xp -= needed
		entry.level += 1
		gained += 1
	end
	if entry.level >= Config.MaxLevel then
		entry.xp = 0
	end
	return gained
end

-- The equipped pets' perks, one number per role (0 when none), each capped
function Pets.bonuses(pets: Saved): Bonuses
	local totals: any = { miner = 0, hauler = 0, pack = 0, swift = 0, merchant = 0 }
	local seen: { [string]: boolean } = {}
	for _, petId in pets.equipped do
		local def = byId[petId]
		local entry = pets.owned[petId]
		if def and entry and not seen[petId] then
			seen[petId] = true
			totals[def.Role] += Pets.perk(def.Role, entry.level)
		end
	end
	for role, total in totals do
		totals[role] = math.min(total, Config.Roles[role].Cap)
	end
	return totals
end

-- A detached copy of the owned table (State snapshots must not share the saved profile's tables)
function Pets.cloneOwned(owned: { [string]: Entry }): { [string]: Entry }
	local copy = {}
	for petId, entry in owned do
		copy[petId] = { level = entry.level, xp = entry.xp }
	end
	return copy
end

local function starterOwned(): { [string]: Entry }
	local owned = {}
	for _, petId in Config.Starter do
		owned[petId] = { level = 1, xp = 0 }
	end
	return owned
end

-- A fresh `pets` table: the starter pets, owned and equipped
function Pets.fresh(): Saved
	return { owned = starterOwned(), equipped = table.clone(Config.Starter) }
end

-- Makes a saved `pets` table legal (profile loads, migrations)
function Pets.clean(saved: any, rebirths: number?): Saved
	local owned: { [string]: Entry } = {}
	if type(saved) == "table" and type(saved.owned) == "table" then
		for petId, entry in saved.owned do
			if type(petId) == "string" and byId[petId] and type(entry) == "table" then
				local level = if type(entry.level) == "number" then math.clamp(math.floor(entry.level), 1, Config.MaxLevel) else 1
				local xp = if type(entry.xp) == "number" and level < Config.MaxLevel then math.max(entry.xp, 0) else 0
				owned[petId] = { level = level, xp = xp }
			end
		end
	end
	for petId, entry in starterOwned() do
		owned[petId] = owned[petId] or entry
	end
	local equipped: { string } = {}
	local seen: { [string]: boolean } = {}
	local limit = Pets.slots(rebirths)
	if type(saved) == "table" and type(saved.equipped) == "table" then
		for _, petId in saved.equipped do
			if type(petId) == "string" and owned[petId] and not seen[petId] and #equipped < limit then
				seen[petId] = true
				table.insert(equipped, petId)
			end
		end
	elseif saved == nil then
		equipped = table.clone(Config.Starter)
	end
	return { owned = owned, equipped = equipped }
end

return Pets

--!strict
-- Pet rules (Config.Pets): perks by level, XP, slots, and the saved-data checks.
-- Pure functions, covered by tests/Pets.spec; PetService, PlayerStateService and
-- EconomyService use them.
--
--   perksOf(def, level)    a pet's ordered { role, value } perks at that level
--   roll(egg, roll, pity, pick) which pet an egg hatches (pure; PetService passes the randoms)
--   bonuses(pets)           the equipped pets' perks added up per role, to each role's cap
--   slots(rebirths, extra, bonus)  how many pets can be out, including the optional slot pass
--                           and the Pet Bond perk's bonus slots
--   minerActive(last, now)  whether a real validated swing is inside the miner window
--   xpToNext(level)         XP to the next level, nil at the max
--   addXp(entry, xp)        adds XP to a { level, xp } entry, levelling up; returns levels gained
--   clean(saved, rebirths, extra) a saved `pets` table made legal: known pets, levels in range,
--                           equipped ones owned, unique and within the slots

local Config = require(script.Parent.Config.Pets)

local Pets = {}

export type Entry = { level: number, xp: number }
export type Saved = { owned: { [string]: Entry }, equipped: { string }, hatches: { [string]: number }? }
export type PerkValue = { role: string, value: number }
export type Bonuses = {
	miner: number, hauler: number, pack: number, swift: number, merchant: number,
	yield: number, sprint: number, vault: number, crit: number, scholar: number, shards: number,
}

local byId: { [string]: Config.Pet } = {}
for _, pet in Config.List do
	byId[pet.Id] = pet
end

function Pets.def(petId: string): Config.Pet?
	return byId[petId]
end

-- Each pet carries its own range. Preserve order so the first perk stays the main role.
function Pets.perksOf(def: Config.Pet, level: number): { PerkValue }
	local fraction = (math.clamp(level, 1, Config.MaxLevel) - 1) / math.max(Config.MaxLevel - 1, 1)
	local perks: { PerkValue } = {}
	for _, perk in def.Perks do
		table.insert(perks, { role = perk.Role, value = perk.Min + (perk.Max - perk.Min) * fraction })
	end
	return perks
end

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

function Pets.minerActive(lastSwing: number?, now: number): boolean
	return lastSwing ~= nil and finite(lastSwing) and finite(now)
		and lastSwing <= now and now - lastSwing <= Config.MinerWindow
end

local function scaled(role: string, amount: number, bonus: number): number
	if not finite(amount) or amount <= 0 then
		return 0
	end
	local mult = if finite(bonus) then 1 + math.clamp(bonus, 0, Config.Roles[role].Cap) else 1
	local result = amount * mult
	return if finite(result) then result else 0
end

-- Quantity bonuses never touch a roll or its odds. Preserve fractional ore and XP;
-- their existing consumers carry fractions forward. Shards round the complete payout.
function Pets.oreYield(ore: number, bonus: number): number
	return scaled("yield", ore, bonus)
end

function Pets.playerXp(amount: number, bonus: number): number
	return scaled("scholar", amount, bonus)
end

function Pets.coreShards(amount: number, bonus: number): number
	return math.floor(scaled("shards", amount, bonus))
end

function Pets.vaultCapacity(capacity: number, bonus: number): number
	return scaled("vault", capacity, bonus)
end

local rarityIndex: { [string]: number } = {}
for index, id in Config.RarityOrder do
	rarityIndex[id] = index
end

-- The pets an egg can hatch of one rarity (pass pets are never in an egg)
function Pets.eggPets(rarity: string): { Config.Pet }
	local out = {}
	for _, pet in Config.List do
		if pet.Rarity == rarity and not pet.Pass then
			table.insert(out, pet)
		end
	end
	return out
end

function Pets.egg(eggId: string): Config.Egg?
	for _, egg in Config.Eggs do
		if egg.Id == eggId then
			return egg
		end
	end
	return nil
end

-- Hatches one egg. `roll` and `pick` are uniform in [0, 1) (math.random() on the server): roll
-- lands in the egg's odds, pick chooses among that rarity's pets. `pity` is how many hatches
-- of this egg since the last PityFrom-or-better pet; on the egg's Pity-th hatch the rarity is
-- drawn from the PityFrom-or-better odds only. Returns the pet id and the new pity count.
function Pets.roll(egg: Config.Egg, roll: number, pity: number, pick: number): (string, number)
	local floor = rarityIndex[egg.PityFrom] or 1
	local guaranteed = pity >= egg.Pity - 1
	local total = 0
	for _, id in Config.RarityOrder do
		if egg.Odds[id] and (not guaranteed or rarityIndex[id] >= floor) then
			total += egg.Odds[id]
		end
	end
	local target = math.clamp(roll, 0, 1 - 1e-9) * total
	local chosen = nil
	local acc = 0
	for _, id in Config.RarityOrder do
		if egg.Odds[id] and (not guaranteed or rarityIndex[id] >= floor) then
			acc += egg.Odds[id]
			chosen = id
			if target < acc then
				break
			end
		end
	end
	local pool = Pets.eggPets(chosen :: string)
	local pet = pool[math.min(math.floor(math.clamp(pick, 0, 1 - 1e-9) * #pool) + 1, #pool)]
	local newPity = if rarityIndex[pet.Rarity] >= floor then 0 else pity + 1
	return pet.Id, newPity
end

function Pets.slots(rebirths: number?, extraSlot: boolean?, bonusSlots: number?): number
	local slots = Config.Slots
	local count = math.max(math.floor(rebirths or 0), 0)
	return math.min(slots.Base + slots.PerRebirth * count, slots.Max)
		+ (if count >= slots.ExtraAtRebirth then 1 else 0)
		+ (if extraSlot then 1 else 0)
		+ math.max(math.floor(bonusSlots or 0), 0)
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
	local totals: any = {}
	for _, role in Config.RoleOrder do
		totals[role] = 0
	end
	local seen: { [string]: boolean } = {}
	for _, petId in pets.equipped do
		local def = byId[petId]
		local entry = pets.owned[petId]
		if def and entry and not seen[petId] then
			seen[petId] = true
			for _, perk in Pets.perksOf(def, entry.level) do
				totals[perk.role] += perk.value
			end
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
	return { owned = starterOwned(), equipped = table.clone(Config.Starter), hatches = {} }
end

-- Makes a saved `pets` table legal (profile loads, migrations)
function Pets.clean(saved: any, rebirths: number?, extraSlot: boolean?, bonusSlots: number?): Saved
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
	local limit = Pets.slots(rebirths, extraSlot, bonusSlots)
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
	local hatches: { [string]: number } = {}
	if type(saved) == "table" and type(saved.hatches) == "table" then
		for eggId, count in saved.hatches do
			if type(eggId) == "string" and Pets.egg(eggId) and type(count) == "number" and count == count then
				hatches[eggId] = math.max(math.floor(count), 0)
			end
		end
	end
	return { owned = owned, equipped = equipped, hatches = hatches }
end

return Pets

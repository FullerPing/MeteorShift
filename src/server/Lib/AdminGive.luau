--!strict
-- The admin /give command (who may use it is Lib.Admins). Reads "/give <player> <item> [amount]", finds the
-- recipient among the players in the server and adds the gift to their profile:
--   cash <n>   shards <n>   pickaxe <tier>   backpack <tier>   pet <pet> [level]
-- A gift only ever adds: a gear tier or pet level the recipient already has or beats is refused, so nothing is
-- taken away. Pure, so the rules can be tested without a running place; Main.server wires it to chat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Gear = require(ReplicatedStorage.Shared.Gear)
local Pets = require(ReplicatedStorage.Shared.Pets)
local ShardWallet = require(ReplicatedStorage.Shared.ShardWallet)

local AdminGive = {}

export type Gift = {
	kind: string, -- "cash", "shards", "pickaxe", "backpack" or "pet"
	amount: number?, -- cash and shards
	tier: number?, -- pickaxe and backpack
	petId: string?,
	level: number?, -- pet
}

export type Result = {
	changed: boolean,
	gear: boolean, -- the pickaxe tier changed, so its tool needs restyling
	text: string, -- what the recipient got, or why they got nothing
}

export type Candidate = { Name: string, DisplayName: string }

AdminGive.Usage = "Usage: /give <player|all> cash|shards <amount>, pickaxe|backpack <tier>, pet <pet> [level]"
-- Largest cash or shards gift: far above any real price, far below where multipliers could overflow to inf
AdminGive.MaxAmount = 1e30

-- The recipient names that mean everyone in the server ("/give all cash 1000", "/giveall cash 1000")
local EVERYONE = { all = true, everyone = true, ["*"] = true }
function AdminGive.isEveryone(target: string): boolean
	return EVERYONE[string.lower(target)] == true
end

local function whole(text: string?): number?
	local n = tonumber(text)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return math.floor(n)
end

-- Pets are told apart by id or name, ignoring case and spaces
local function squash(text: string): string
	return (string.lower(string.gsub(text, "%s", "")))
end

local function findPet(token: string): string?
	local want = squash(token)
	for _, pet in Config.Pets.List do
		if squash(pet.Id) == want or squash(pet.Name) == want then
			return pet.Id
		end
	end
	return nil
end

-- Reads a command into (recipient name, gift), or (nil, nil, reason) when it makes no sense.
-- Any words after the gift are a message for the announcement ("/giveall shards 500 take these!"), returned fourth
function AdminGive.parse(text: string): (string?, Gift?, string?, string?)
	local words = {}
	for word in string.gmatch(text, "%S+") do
		table.insert(words, word)
	end
	local function note(used: number): string?
		return if #words > used then table.concat(words, " ", used + 1) else nil
	end
	local target, item = words[2], words[3]
	if not target or not item then
		return nil, nil, AdminGive.Usage
	end
	local kind = string.lower(item)
	if kind == "cash" or kind == "shards" then
		local amount = whole(words[4])
		if not amount or amount < 1 then
			return nil, nil, "Give a whole amount of at least 1. " .. AdminGive.Usage
		end
		if amount > AdminGive.MaxAmount then
			return nil, nil, "Give at most " .. Format.number(AdminGive.MaxAmount) .. ". " .. AdminGive.Usage
		end
		return target, { kind = kind, amount = amount }, nil, note(4)
	elseif kind == "pickaxe" or kind == "backpack" then
		local count = if kind == "pickaxe" then #Config.Pickaxes else #Config.Backpacks
		local tier = whole(words[4])
		if not tier or tier < 1 or tier > count or tostring(tier) ~= words[4] then
			return nil, nil, string.format("The %s tier is 1-%d. %s", kind, count, AdminGive.Usage)
		end
		return target, { kind = kind, tier = tier }, nil, note(4)
	elseif kind == "pet" then
		local petId = if words[4] then findPet(words[4]) else nil
		if not petId then
			return nil, nil, "No such pet. " .. AdminGive.Usage
		end
		-- a level only when the next word is a number; anything else is the message
		local hasLevel = words[5] ~= nil and string.match(words[5], "^[%d%.]") ~= nil
		local level = if hasLevel then whole(words[5]) else 1
		if not level or level < 1 or level > Config.Pets.MaxLevel then
			return nil, nil, string.format("The pet level is 1-%d. %s", Config.Pets.MaxLevel, AdminGive.Usage)
		end
		return target, { kind = "pet", petId = petId, level = level }, nil, note(if hasLevel then 5 else 4)
	end
	return nil, nil, AdminGive.Usage
end

-- The index of the player a name points at: "me" is the giver (`selfIndex`), an exact name or display name wins,
-- then a unique prefix of either. Returns (nil, reason) when it points at nobody or at several.
function AdminGive.findPlayer(query: string, players: { Candidate }, selfIndex: number?): (number?, string?)
	local want = string.lower(query)
	if want == "me" then
		if selfIndex then
			return selfIndex, nil
		end
		return nil, "There is no one called \"me\" here"
	end
	local exact, prefix = {}, {}
	for index, player in players do
		local name, display = string.lower(player.Name), string.lower(player.DisplayName)
		if name == want or display == want then
			table.insert(exact, index)
		elseif string.sub(name, 1, #want) == want or string.sub(display, 1, #want) == want then
			table.insert(prefix, index)
		end
	end
	local found = if #exact > 0 then exact else prefix
	if #found == 1 then
		return found[1], nil
	elseif #found == 0 then
		return nil, "No player in this server matches \"" .. query .. "\""
	end
	local names = {}
	for _, index in found do
		table.insert(names, players[index].Name)
	end
	return nil, "\"" .. query .. "\" matches " .. table.concat(names, ", ")
end

-- Adds `gift` to the profile. `petSlots` is how many pets the recipient may have out. Returns whether anything
-- changed; the text names the gift, or says why there was none.
function AdminGive.apply(data: any, gift: Gift, petSlots: number): Result
	local kind = gift.kind
	if kind == "cash" then
		data.cash += gift.amount :: number
		return { changed = true, gear = false, text = Format.cash(gift.amount :: number) .. " cash" }
	elseif kind == "shards" then
		ShardWallet.add(data, gift.amount :: number) -- earned, not bought
		return { changed = true, gear = false, text = Format.number(gift.amount :: number) .. " shards" }
	elseif kind == "pickaxe" or kind == "backpack" then
		local tier = gift.tier :: number
		local list = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
		local name = list[tier].Name
		if tier <= data[kind .. "Tier"] then
			return { changed = false, gear = false, text = "already has the " .. name .. " or better" }
		end
		data[kind .. "Tier"] = tier
		data[kind .. "Level"] = Gear.levelsForTier(tier)
		return { changed = true, gear = kind == "pickaxe", text = "the " .. name }
	end
	local petId, level = gift.petId :: string, gift.level :: number
	local name = (Pets.def(petId) :: any).Name
	local pets = data.pets
	local entry = pets.owned[petId]
	if entry and entry.level >= level then
		return { changed = false, gear = false, text = "already has " .. name .. " at level " .. entry.level .. " or better" }
	end
	if entry then
		entry.level = level
	else
		pets.owned[petId] = { level = level, xp = 0 }
	end
	if not table.find(pets.equipped, petId) and #pets.equipped < petSlots then
		table.insert(pets.equipped, petId)
	end
	return { changed = true, gear = false, text = name .. " (level " .. level .. ")" }
end

return AdminGive

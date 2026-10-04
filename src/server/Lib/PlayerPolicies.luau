--!strict
-- Session-only policy cache. API failures never grant permission, and a
-- departed player's yielding lookup or delayed retry cannot restore their data.

export type PolicyInfo = {
	Status: "loading" | "ready" | "unavailable",
	ArePaidRandomItemsRestricted: boolean,
	IsPaidItemTradingAllowed: boolean,
}

type Dependencies = {
	lookup: (any) -> any,
	defer: (() -> ()) -> (),
	delay: (number, () -> ()) -> (),
	changed: (any, PolicyInfo) -> (),
}

type Entry = { policy: PolicyInfo }

local PlayerPolicies = {}
local RETRY_DELAYS = { 1, 3 }

local function conservative(status: "loading" | "unavailable"): PolicyInfo
	return {
		Status = status,
		ArePaidRandomItemsRestricted = true,
		IsPaidItemTradingAllowed = false,
	}
end

local function normalize(response: any): PolicyInfo?
	if type(response) ~= "table"
		or type(response.ArePaidRandomItemsRestricted) ~= "boolean"
		or type(response.IsPaidItemTradingAllowed) ~= "boolean"
	then
		return nil
	end
	return {
		Status = "ready",
		ArePaidRandomItemsRestricted = response.ArePaidRandomItemsRestricted,
		IsPaidItemTradingAllowed = response.IsPaidItemTradingAllowed,
	}
end

function PlayerPolicies.new(dependencies: Dependencies)
	local entries: { [any]: Entry } = {}
	local cache = {}

	local function publish(player: any, entry: Entry, policy: PolicyInfo)
		entry.policy = policy
		dependencies.changed(player, table.clone(policy))
	end

	local function lookup(player: any, entry: Entry, attempt: number)
		if entries[player] ~= entry then return end
		-- pcall also protects against the API yielding and then throwing.
		local ok, response = pcall(dependencies.lookup, player)
		if entries[player] ~= entry then return end
		local policy = if ok then normalize(response) else nil
		if policy then
			publish(player, entry, policy)
			return
		end
		local seconds = RETRY_DELAYS[attempt]
		if seconds then
			dependencies.delay(seconds, function()
				lookup(player, entry, attempt + 1)
			end)
		else
			publish(player, entry, conservative("unavailable"))
		end
	end

	function cache:Add(player: any)
		if entries[player] then return end
		local entry: Entry = { policy = conservative("loading") }
		entries[player] = entry
		publish(player, entry, entry.policy)
		dependencies.defer(function()
			lookup(player, entry, 1)
		end)
	end

	function cache:Remove(player: any)
		entries[player] = nil
	end

	function cache:Get(player: any): PolicyInfo
		local entry = entries[player]
		return if entry then table.clone(entry.policy) else conservative("loading")
	end

	function cache:CanUsePaidRandomItems(player: any): boolean
		local policy = self:Get(player)
		return policy.Status == "ready" and not policy.ArePaidRandomItemsRestricted
	end

	function cache:CanTradePaidItems(player: any): boolean
		local policy = self:Get(player)
		return policy.Status == "ready" and policy.IsPaidItemTradingAllowed
	end

	return cache
end

return PlayerPolicies

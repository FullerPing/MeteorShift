--!strict
-- The live Robux price of a pass or product (MarketplaceService, regional pricing), looked up once per id and cached.
-- Until the lookup answers, or when it fails, the dashboard price in Config.Monetization (`Robux`) stands in.
-- shortcut: the Store, Shop and Rebirth menus still run their own lookups (StoreController.loadPrice); move them here
-- when one of them changes.
local MarketplaceService = game:GetService("MarketplaceService")
local Format = require(game:GetService("ReplicatedStorage").Shared.Format)

local RobuxPrice = {}

local cache: { [number]: number } = {}
local pending: { [number]: { (number?) -> () } } = {}

-- Calls `done` with the best price known now (cached, else the Config fallback), then once more if the lookup finds
-- a different one. `done` may get nil when neither is known.
function RobuxPrice.get(kind: "pass" | "product", definition: { Id: number, Robux: number? }, done: (number?) -> ())
	local id = definition.Id
	local known = cache[id] or definition.Robux
	done(known)
	if id == 0 or cache[id] then return end
	if pending[id] then
		table.insert(pending[id], done)
		return
	end
	pending[id] = { done }
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(id, if kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
		end)
		local waiting = pending[id]
		pending[id] = nil
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			cache[id] = info.PriceInRobux
			if info.PriceInRobux ~= known then
				for _, callback in waiting do callback(info.PriceInRobux) end
			end
		end
	end)
end

-- "<robux glyph> 149", or "" without a price
function RobuxPrice.text(price: number?): string
	return if price then Format.ROBUX .. " " .. Format.number(price) else ""
end

return RobuxPrice

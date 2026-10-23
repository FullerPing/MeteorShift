--!strict
-- Spec for Shared.DebrisField and Shared.Income: what a rock pays by the ore field it stands in.

return function(t: any)
	local DebrisField = require(t.shared.DebrisField)
	local Income = require(t.shared.Income)
	local Config = require(t.shared.Config)

	t.test("rocks respawn faster in a full server, never below the floor", function()
		local debris = Config.Debris
		t.eq(DebrisField.respawnSeconds(1, 0), debris.RespawnMin)
		t.eq(DebrisField.respawnSeconds(debris.RespawnCrowd, 1), debris.RespawnMax)
		t.near(DebrisField.respawnSeconds(debris.RespawnCrowd * 2, 1), debris.RespawnMax / 2, 1e-9)
		t.eq(DebrisField.respawnSeconds(1000, 1), debris.RespawnFloor)
	end)

	local function reward(id: string): any
		return DebrisField.reward(id)
	end

	t.test("Income.grant is the seconds of income between the floor and the ceiling", function()
		t.eq(Income.grant(10, 5, 0, 1000), 50)
		t.eq(Income.grant(10, 0.001, 20, 1000), 20, "a tiny income pays the floor")
		t.eq(Income.grant(10, 1e9, 20, 1000), 1000, "a huge one pays the ceiling")
		t.eq(Income.grant(10, 5, 2000, 500), 500, "the ceiling beats the floor")
		t.eq(Income.grant(1, 2.6, 0, 100), 2, "whole cash only")
	end)

	t.test("sizedShare: a rock sized for a weaker pickaxe pays the breaker that fraction", function()
		t.eq(DebrisField.sizedShare(40, 4, 10), 1, "sized for the breaker")
		t.eq(DebrisField.sizedShare(40, 4, 1), 1, "sized for a stronger pickaxe: never more than full")
		t.near(DebrisField.sizedShare(4, 4, 100), 0.01, 1e-9, "a veteran on a newcomer rock")
		t.eq(DebrisField.sizedShare(4, 4, 0), 1, "no power: unchanged")
	end)

	t.test("every field has a reward and unknown or missing fields are filler", function()
		for _, field in Config.Debris.Fields do
			t.ok(DebrisField.reward(field.Id) ~= nil, field.Id)
		end
		t.eq(DebrisField.reward("Nowhere"), nil)
		t.eq(DebrisField.reward(nil), nil)
		t.eq(DebrisField.hits(nil), Config.Debris.Hp)
		local ore, mult = DebrisField.ore(nil, 1)
		t.eq(ore, Config.Debris.Ore)
		t.eq(mult, Config.Debris.YieldFraction)
		t.eq(DebrisField.cash(nil, 100, 1e6), 0)
	end)

	t.test("Rust Works and Frost Yard pay cash, Frost Yard for more hits and more cash", function()
		local rust, frost = reward("RustWorks"), reward("FrostYard")
		t.eq(rust.Kind, "Cash")
		t.eq(frost.Kind, "Cash")
		t.ok(DebrisField.hits(frost) > DebrisField.hits(rust), "Frost Yard is harder to break")
		t.ok(DebrisField.cash(frost, 100, 1e9) > DebrisField.cash(rust, 100, 1e9), "and pays more")
		-- a bit more per hit, not a lot more: the harder field is the better one without being a different game
		local perHitRust = DebrisField.cash(rust, 100, 1e9) / DebrisField.hits(rust)
		local perHitFrost = DebrisField.cash(frost, 100, 1e9) / DebrisField.hits(frost)
		t.ok(perHitFrost >= perHitRust and perHitFrost <= perHitRust * 1.5, "per hit " .. perHitRust .. " vs " .. perHitFrost)
		local ore = DebrisField.ore(rust, 1)
		t.eq(ore, nil, "a cash rock drops no ore")
	end)

	t.test("a cash rock pays its seconds of the breaker's income, so it grows with the player", function()
		local rust = reward("RustWorks")
		local poor, rich = DebrisField.cash(rust, 20, 1e12), DebrisField.cash(rust, 2000, 1e12)
		t.eq(poor, math.floor(rust.Seconds * 20))
		t.eq(rich, math.floor(rust.Seconds * 2000))
		t.ok(rich > poor * 50)
	end)

	t.test("a cash rock respects its floor and its share of the next rebirth", function()
		local rust = reward("RustWorks")
		t.eq(DebrisField.cash(rust, 0, 1e9), rust.CashFloor, "no income still pays the floor")
		local cost = 50000
		t.eq(DebrisField.cash(rust, 1e9, cost), math.floor(cost * rust.CeilingShare), "a huge income is capped by the rebirth cost")
	end)

	t.test("Violet Quarry and Sulfur Ridge drop better ore than iron, harder to get", function()
		local violet, sulfur = reward("VioletQuarry"), reward("SulfurRidge")
		local oreV, multV = DebrisField.ore(violet, 1)
		local oreS, multS = DebrisField.ore(sulfur, 1)
		t.ok(oreV ~= nil and oreS ~= nil and oreV ~= Config.Debris.Ore and oreS ~= Config.Debris.Ore, "not iron")
		local prices = Config.Home.BarPrices
		t.ok(prices[oreV :: string] > prices[Config.Debris.Ore], "Violet's ore is worth more than iron")
		t.ok(prices[oreS :: string] > prices[oreV :: string], "Sulfur's more than Violet's")
		t.ok(DebrisField.hits(violet) > Config.Debris.Hp and DebrisField.hits(sulfur) > DebrisField.hits(violet), "harder to break")
		t.eq(DebrisField.cash(violet, 100, 1e9), 0, "ore rocks pay no cash")
		t.ok(multV > 0 and multS > 0)
	end)

	t.test("a hit on a field rock stays below the same ore from a meteor node", function()
		for _, id in { "VioletQuarry", "SulfurRidge" } do
			local ore, mult = DebrisField.ore(reward(id), 1)
			t.ok(mult < 1, id .. " yields " .. mult .. " of a full hit")
			t.ok(Config.Home.BarPrices[ore :: string] ~= nil, id .. " has a bar price")
		end
	end)

	t.test("a level short of the ore's clearance cuts an ore rock's yield in proportion", function()
		local sulfur = reward("SulfurRidge")
		local _, full = DebrisField.ore(sulfur, 1)
		local _, short = DebrisField.ore(sulfur, 0.5)
		t.near(short, full / 2, 1e-12)
	end)
end

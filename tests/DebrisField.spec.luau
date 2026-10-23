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

	t.test("mined nonstop, a cash field pays about 1.5x the player's expected income", function()
		-- Owner, 2026-10-22: a field is a little better than the meteors, never many times better. Time per rock is its hits
		-- at the swing (HitsPerMinuteShare of swings land) plus WALK seconds between rocks; checked for every pickaxe
		-- tier at its fastest level, where the swing is shortest.
		local Gear = require(t.shared.Gear)
		local WALK = 1.5
		for tier = 1, #Config.Pickaxes do
			local swing = Gear.pickaxe(tier, Gear.cap(tier)).Swing
			for _, field in Config.Debris.Fields do
				local r = field.Reward
				if r.Kind == "Cash" then
					local seconds = (r.Seconds :: number) * swing / Config.Pickaxes[1].Swing -- DebrisField.cash scales by swing
					local perSecond = seconds / (r.Hp * swing / Config.Balance.HitsPerMinuteShare + WALK)
					t.ok(perSecond >= 0.8 and perSecond < 2, string.format("%s at tier %d pays %.2f x income", field.Id, tier, perSecond))
				end
			end
		end
	end)

	t.test("mined nonstop, an ore field pays about 1.5x the player's expected income", function()
		-- The line turns any ore into a bar at the same speed, so the ore's bar price is what a field is worth. At
		-- stages along the road (gear tiers maxed, the line, player level, rebirths), from each field's opening on.
		local Pacing = require(t.shared.Pacing)
		local Gear = require(t.shared.Gear)
		local Line = require(t.shared.Line)
		local Levels = require(t.shared.Levels)
		local Rebirth = require(t.shared.Rebirth)
		local Pets = require(t.shared.Pets)
		local balance = Config.Balance
		local stages = { { 5, 5, 5, 12, 1 }, { 5, 5, 5, 16, 2 }, { 5, 5, 5, 20, 3 }, { 6, 6, 6, 24, 6 }, { 7, 7, 7, 30, 8 }, { 8, 8, 8, 40, 12 }, { 8, 8, 8, 50, 16 } }
		for _, field in Config.Debris.Fields do
			local r = field.Reward
			if r.Kind == "Ore" then
				for _, stage in stages do
					local pickTier, packTier, line, level, rebirths = table.unpack(stage)
					local unlock = field.Unlock or {}
					if (unlock.Level or 0) <= level and (unlock.Rebirths or 0) <= rebirths then
						local pick = Gear.pickaxe(pickTier, Gear.cap(pickTier))
						local capacity = Gear.capacity(packTier, Gear.cap(packTier))
						local lineRate = math.min(Line.station("conveyor", line).Rate :: number, Line.station("refinery", line).Rate :: number)
						local mult = Rebirth.multiplier(rebirths)
						local income = Pacing.expectedIncome({ orePerHit = pick.OrePerHit, swing = pick.Swing, capacity = capacity, level = level,
							pets = Pets.bonuses(Pets.fresh()), lineRate = lineRate, saleMult = mult }).perSecond
						local perHit = pick.OrePerHit * (r.OreMult :: number) * Levels.oreYield(level, r.Ore :: string)
						local rate = capacity / (capacity / perHit * pick.Swing / balance.HitsPerMinuteShare + balance.TripSeconds)
						local ratio = math.min(rate, lineRate) * Config.Home.BarPrices[r.Ore :: string] * mult / income
						t.ok(ratio >= 0.8 and ratio < 2, string.format("%s at level %d, rebirth %d pays %.2f x income", field.Id, level, rebirths, ratio))
					end
				end
			end
		end
	end)

	t.test("a cash rock respects its floor and its share of the next rebirth", function()
		local rust = reward("RustWorks")
		t.eq(DebrisField.cash(rust, 0, 1e9), rust.CashFloor, "no income still pays the floor")
		local cost = 50000
		t.eq(DebrisField.cash(rust, 1e9, cost), math.floor(cost * rust.CeilingShare), "a huge income is capped by the rebirth cost")
	end)

	t.test("a faster swing breaks a cash rock sooner, so it pays proportionally less", function()
		local frost = reward("FrostYard")
		local base = Config.Pickaxes[1].Swing
		local full = DebrisField.cash(frost, 1000, 1e12)
		t.eq(DebrisField.cash(frost, 1000, 1e12, base), full, "the Basic Pickaxe's swing pays the full seconds")
		t.near(DebrisField.cash(frost, 1000, 1e12, base / 2), full / 2, 1)
		t.eq(DebrisField.cash(frost, 1000, 1e12, base * 3), full, "a slower swing never pays more")
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

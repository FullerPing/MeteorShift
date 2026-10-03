--!strict
-- Spec for Shared.MeteorTypes (spec §8.1): which meteor type comes next, how an
-- under-tier pickaxe mines it, and the Ice (Refreeze) and Crystal (Resonance)
-- twist math. Tuning numbers (weights, under-tier pace, twist values, bar
-- prices) are read from Config so a retune doesn't break these cases; the
-- tier gates (Iron 1, Ice 3, Crystal 5) and the 25% eligibility share are the
-- spec's rules and are used as given.

return function(t: any)
	local MeteorTypes = require(t.shared.MeteorTypes)
	local Meteor = require(t.shared.Config.Meteor)
	local Home = require(t.shared.Config.Home)
	local Types = Meteor.Types

	-- { [pickaxe tier] = players } -> one tier per active player
	local function lobby(counts: { [number]: number }): { number }
		local tiers = {}
		for tier, players in counts do
			for _ = 1, players do
				table.insert(tiers, tier)
			end
		end
		return tiers
	end

	-- Roll bands from the weights, in TypeOrder: Iron [0, iceFrom), Ice [iceFrom, crystalFrom), Crystal [crystalFrom, 1)
	local total = Types.Iron.Weight + Types.Ice.Weight + Types.Crystal.Weight
	local iceFrom = Types.Iron.Weight / total
	local crystalFrom = (Types.Iron.Weight + Types.Ice.Weight) / total
	local EPS = 1e-9
	local iceRoll = (iceFrom + crystalFrom) / 2
	local crystalRoll = (crystalFrom + 1) / 2
	local veterans = lobby({ [8] = 10 })

	t.test("config: every type in TypeOrder is complete and sellable", function()
		t.eq(#Meteor.TypeOrder, 3, "the roll bands in this spec assume Iron, Ice and Crystal only")
		for index, id in Meteor.TypeOrder do
			local meteorType = Types[id]
			t.ok(meteorType, "missing type " .. id)
			t.eq(meteorType.Id, id, "Id of " .. id)
			t.ok(Home.BarPrices[meteorType.Ore], "no bar price for " .. meteorType.Ore)
			t.ok(Home.OreNames[meteorType.Ore], "no ore name for " .. meteorType.Ore)
			t.ok(table.find(Home.OreOrder, meteorType.Ore), meteorType.Ore .. " missing from OreOrder")
			if index > 1 then
				local below = Types[Meteor.TypeOrder[index - 1]]
				t.ok(meteorType.RequiredTier > below.RequiredTier, "TypeOrder must rise in RequiredTier at " .. id)
			end
		end
		t.eq(Types[Meteor.TypeOrder[1]].RequiredTier, 1, "the lowest type must be open to everyone")
	end)

	t.test("weights split the roll Iron, Ice, Crystal in TypeOrder", function()
		t.eq(MeteorTypes.pick(veterans, 0).Id, "Iron", "roll 0")
		t.eq(MeteorTypes.pick(veterans, iceFrom - EPS).Id, "Iron", "just below the Ice band")
		t.eq(MeteorTypes.pick(veterans, iceFrom + EPS).Id, "Ice", "just inside the Ice band")
		t.eq(MeteorTypes.pick(veterans, crystalFrom - EPS).Id, "Ice", "just below the Crystal band")
		t.eq(MeteorTypes.pick(veterans, crystalFrom + EPS).Id, "Crystal", "just inside the Crystal band")
		t.eq(MeteorTypes.pick(veterans, 1 - EPS).Id, "Crystal", "roll just under 1")
	end)

	t.test("a lobby of 10 tier-1 players never gets Ice or Crystal whatever the roll", function()
		local beginners = lobby({ [1] = 10 })
		for step = 0, 99 do
			local roll = step / 100
			t.eq(MeteorTypes.pick(beginners, roll).Id, "Iron", "roll " .. roll)
		end
		t.eq(MeteorTypes.pick(beginners, 1 - EPS).Id, "Iron", "roll just under 1")
	end)

	t.test("with no active players only Iron is eligible", function()
		t.eq(MeteorTypes.pick({}, iceRoll).Id, "Iron", "Ice roll")
		t.eq(MeteorTypes.pick({}, crystalRoll).Id, "Iron", "Crystal roll")
	end)

	t.test("3 of 10 at tier 3 allows Ice; a Crystal roll drops to Ice", function()
		local mixed = lobby({ [3] = 3, [1] = 7 })
		t.eq(MeteorTypes.pick(mixed, iceRoll).Id, "Ice", "Ice roll")
		t.eq(MeteorTypes.pick(mixed, crystalRoll).Id, "Ice", "Crystal roll")
	end)

	t.test("2 of 10 at tier 3 does not allow Ice", function()
		local mixed = lobby({ [3] = 2, [1] = 8 })
		t.eq(MeteorTypes.pick(mixed, iceRoll).Id, "Iron", "Ice roll")
		t.eq(MeteorTypes.pick(mixed, crystalRoll).Id, "Iron", "Crystal roll")
	end)

	t.test("a Crystal roll falls through Ice to Iron when neither is eligible", function()
		-- 2 of 10 are tier 5: they meet Ice's tier 3 too, but 20% is under the 25% share
		t.eq(MeteorTypes.pick(lobby({ [5] = 2, [1] = 8 }), crystalRoll).Id, "Iron")
	end)

	t.test("exactly a quarter of the lobby is enough", function()
		t.eq(MeteorTypes.pick(lobby({ [5] = 1, [1] = 3 }), crystalRoll).Id, "Crystal", "1 of 4 at tier 5")
		t.eq(MeteorTypes.pick(lobby({ [5] = 3, [1] = 7 }), crystalRoll).Id, "Crystal", "3 of 10 at tier 5")
	end)

	t.test("underTier is true only below the meteor's tier", function()
		t.eq(MeteorTypes.underTier(1, Types.Ice), true, "tier 1 on Ice")
		t.eq(MeteorTypes.underTier(2, Types.Ice), true, "tier 2 on Ice")
		t.eq(MeteorTypes.underTier(3, Types.Ice), false, "tier 3 on Ice")
		t.eq(MeteorTypes.underTier(4, Types.Crystal), true, "tier 4 on Crystal")
		t.eq(MeteorTypes.underTier(8, Types.Crystal), false, "tier 8 on Crystal")
		t.eq(MeteorTypes.underTier(1, Types.Iron), false, "tier 1 on Iron")
	end)

	t.test("an under-tier pickaxe on its own clears a crust node in UnderTier.NodeSeconds", function()
		local MiningPower = require(t.shared.MiningPower)
		local Pickaxes = require(t.shared.Config.Pickaxes)
		for _, case in { { 1, Types.Ice }, { 2, Types.Ice }, { 4, Types.Crystal } } do
			local tier, meteorType = case[1], case[2]
			local pickaxe = Pickaxes[tier]
			-- A small lobby's meteor: 36 nodes sized for the floor power
			local nodeHp = MiningPower.size(MiningPower.floorPower(), 36, meteorType.HpMult)
			local power = MiningPower.power(tier)
			local mult = MeteorTypes.underTierPowerMult(power, pickaxe.Swing, nodeHp)
			t.ok(mult < 1, "tier " .. tier .. " on " .. meteorType.Id .. " is slowed")
			local seconds = nodeHp / (power * mult) * pickaxe.Swing
			t.near(seconds, Meteor.UnderTier.NodeSeconds, 1e-6, "tier " .. tier .. " on " .. meteorType.Id)
		end
	end)

	t.test("under-tier mining is never sped up", function()
		t.eq(MeteorTypes.underTierPowerMult(1, 0.6, 1e6), 1, "a huge node")
		t.eq(MeteorTypes.underTierPowerMult(0, 0.6, 10), 1, "no power")
	end)

	t.test("only every OreEvery-th under-tier hit drops ore", function()
		local every = Meteor.UnderTier.OreEvery
		local drops = 0
		for hit = 1, every * 4 do
			if MeteorTypes.underTierDropsOre(hit) then
				drops += 1
				t.eq(hit % every, 0, "hit " .. hit)
			end
		end
		t.eq(drops, 4, "drops in " .. every * 4 .. " hits")
		t.eq(MeteorTypes.underTierDropsOre(every), true, "hit " .. every)
	end)

	t.test("missed names the tier, ore and bar price an under-tier player missed", function()
		local missed = MeteorTypes.missed(2, Types.Crystal)
		t.ok(missed, "tier 2 on Crystal missed something")
		if missed then
			t.eq(missed.tier, 5, "tier")
			t.eq(missed.ore, "crystal", "ore")
			t.eq(missed.barPrice, Home.BarPrices.crystal, "bar price")
		end
		local missedIce = MeteorTypes.missed(1, Types.Ice)
		t.ok(missedIce and missedIce.tier == 3 and missedIce.ore == "frost", "tier 1 on Ice")
	end)

	t.test("missed is nil when the pickaxe meets the tier", function()
		t.eq(MeteorTypes.missed(5, Types.Crystal), nil, "tier 5 on Crystal")
		t.eq(MeteorTypes.missed(7, Types.Ice), nil, "tier 7 on Ice")
		t.eq(MeteorTypes.missed(1, Types.Iron), nil, "tier 1 on Iron")
	end)

	t.test("missedHint reads 'Tier 5 pickaxe mines Crystal at full speed: $3K bars' for the results panel", function()
		local Format = require(t.shared.Format)
		local crystal = MeteorTypes.missed(2, Types.Crystal)
		t.ok(crystal, "tier 2 on Crystal missed something")
		if crystal then
			t.eq(
				MeteorTypes.missedHint(crystal),
				"Tier 5 pickaxe mines Crystal at full speed: " .. Format.cash(Home.BarPrices.crystal) .. " bars",
				"Crystal hint"
			)
		end
		local ice = MeteorTypes.missed(1, Types.Ice)
		t.ok(ice, "tier 1 on Ice missed something")
		if ice then
			t.eq(
				MeteorTypes.missedHint(ice),
				"Tier 3 pickaxe mines Frost at full speed: " .. Format.cash(Home.BarPrices.frost) .. " bars",
				"Ice hint"
			)
		end
	end)

	t.test("resonance adds BonusPerExtra per extra hitter up to MaxBonus", function()
		local resonance = Meteor.Twists.Resonance
		t.eq(MeteorTypes.resonanceMult(1), 1, "one hitter gets no bonus")
		t.near(MeteorTypes.resonanceMult(2), 1 + resonance.BonusPerExtra, 1e-9, "two hitters")
		t.near(MeteorTypes.resonanceMult(3), 1 + math.min(2 * resonance.BonusPerExtra, resonance.MaxBonus), 1e-9, "three hitters")
		t.near(MeteorTypes.resonanceMult(50), 1 + resonance.MaxBonus, 1e-9, "a crowd is capped")
		local previous = 1
		for hitters = 1, 12 do
			local mult = MeteorTypes.resonanceMult(hitters)
			t.ok(mult >= previous - 1e-9, "never drops as hitters join (" .. hitters .. ")")
			t.ok(mult <= 1 + resonance.MaxBonus + 1e-9, "never above the cap (" .. hitters .. ")")
			previous = mult
		end
	end)

	t.test("resonance with nobody on the node is x1", function()
		t.eq(MeteorTypes.resonanceMult(0), 1)
	end)

	t.test("refreeze waits for IdleSeconds before regenerating", function()
		local refreeze = Meteor.Twists.Refreeze
		t.eq(MeteorTypes.refreezeHp(50, 100, refreeze.IdleSeconds - 0.01, 1), 50, "just under the idle gate")
		t.near(MeteorTypes.refreezeHp(50, 100, refreeze.IdleSeconds, 1), 50 + refreeze.RegenPerSecond * 100, 1e-9, "at the gate")
		t.near(MeteorTypes.refreezeHp(50, 100, refreeze.IdleSeconds + 10, 0.5), 50 + refreeze.RegenPerSecond * 100 * 0.5, 1e-9, "scales with dt")
	end)

	t.test("refreeze caps at max HP and a broken node stays broken", function()
		local refreeze = Meteor.Twists.Refreeze
		local idle = refreeze.IdleSeconds + 1
		t.eq(MeteorTypes.refreezeHp(99.9, 100, idle, 1), 100, "capped at max")
		t.eq(MeteorTypes.refreezeHp(100, 100, idle, 1), 100, "full stays full")
		t.eq(MeteorTypes.refreezeHp(0, 100, idle, 1), 0, "broken stays 0")
		t.eq(MeteorTypes.refreezeHp(-3, 100, idle, 1), 0, "overkilled stays 0")
	end)

	t.test("shard pool mult is ShardMult at or above the default interval", function()
		t.eq(MeteorTypes.shardPoolMult(Types.Crystal, 240, 240), Types.Crystal.ShardMult, "default interval")
		t.eq(MeteorTypes.shardPoolMult(Types.Crystal, 600, 240), Types.Crystal.ShardMult, "slower schedule pays no extra")
		t.eq(MeteorTypes.shardPoolMult(Types.Ice, 240, 240), Types.Ice.ShardMult, "Ice at default")
	end)

	t.test("shard pool mult scales down in proportion below the default interval", function()
		-- spec §8.1: "a 2-minute interval pays half" of the 4-minute default
		t.near(MeteorTypes.shardPoolMult(Types.Crystal, 120, 240), Types.Crystal.ShardMult / 2, 1e-9, "Crystal at half")
		t.near(MeteorTypes.shardPoolMult(Types.Iron, 60, 240), Types.Iron.ShardMult / 4, 1e-9, "Iron at a quarter")
	end)
end

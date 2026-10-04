--!strict
-- Spec for Shared.MeteorTypes (spec §8.1): which meteor type comes next, and the Ice
-- (Refreeze) and Crystal (Resonance) twist math. The type is picked by weight alone:
-- how well a player's refinery handles it is Shared.Levels' clearance (tests/Levels.spec).

return function(t: any)
	local MeteorTypes = require(t.shared.MeteorTypes)
	local Meteor = require(t.shared.Config.Meteor)
	local Home = require(t.shared.Config.Home)
	local Types = Meteor.Types

	local total = Types.Iron.Weight + Types.Ice.Weight + Types.Crystal.Weight
	local iceFrom = Types.Iron.Weight / total
	local crystalFrom = (Types.Iron.Weight + Types.Ice.Weight) / total
	local EPS = 1e-9

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
		t.eq(MeteorTypes.pick(0).Id, "Iron", "roll 0")
		t.eq(MeteorTypes.pick(iceFrom - EPS).Id, "Iron", "just below the Ice band")
		t.eq(MeteorTypes.pick(iceFrom + EPS).Id, "Ice", "just inside the Ice band")
		t.eq(MeteorTypes.pick(crystalFrom - EPS).Id, "Ice", "just below the Crystal band")
		t.eq(MeteorTypes.pick(crystalFrom + EPS).Id, "Crystal", "just inside the Crystal band")
		t.eq(MeteorTypes.pick(1 - EPS).Id, "Crystal", "roll just under 1")
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

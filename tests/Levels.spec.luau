--!strict
-- Spec for Shared.Levels: XP curve, awarding, meteor XP, evolve gates and the pace of levels.

return function(t: any)
	local Levels = require(t.shared.Levels)
	local Pacing = require(t.shared.Pacing)
	local Config = require(t.shared.Config)
	local Settings = Config.Levels

	t.test("each level needs more XP than the last and the max level needs none", function()
		local last = 0
		for level = 1, Settings.MaxLevel - 1 do
			local needed = Levels.xpToNext(level) :: number
			t.ok(needed > last, "level " .. level)
			last = needed
		end
		t.eq(Levels.xpToNext(Settings.MaxLevel), nil)
	end)

	t.test("addXp carries overflow through several levels and stops at the max", function()
		local p = { level = 1, xp = 0 }
		local gained = Levels.addXp(p, Levels.xpFor(4) + 5)
		t.eq(gained, 3)
		t.eq(p.level, 4)
		t.eq(p.xp, 5)
		Levels.addXp(p, 1e12)
		t.eq(p.level, Settings.MaxLevel)
		t.eq(p.xp, 0)
		t.eq(Levels.addXp(p, -5), 0)
		t.eq(Levels.addXp(p, 0 / 0), 0)
	end)

	t.test("meteor XP rises with effort and type, and cooled pays half", function()
		local low = Levels.meteorXp("Iron", 0, true)
		local high = Levels.meteorXp("Iron", 1, true)
		t.ok(low > 0 and high > low)
		t.ok(Levels.meteorXp("Crystal", 0.5, true) > Levels.meteorXp("Iron", 0.5, true))
		t.near(Levels.meteorXp("Iron", 0.5, false), Levels.meteorXp("Iron", 0.5, true) * Settings.CooledMult / Settings.CrackedMult, 1e-9)
		t.ok(Levels.meteorXp("Iron", 99, true) == high, "share is clamped")
	end)

	t.test("clean repairs bad saves", function()
		local p = Levels.clean("x", nil)
		t.eq(p.level, 1)
		t.eq(p.xp, 0)
		t.eq(Levels.clean(9999, 5).level, Settings.MaxLevel)
		t.eq(Levels.clean(3, Levels.xpToNext(3) :: number + 1).level, 4)
	end)

	t.test("evolve levels never fall as tiers rise and start free", function()
		t.eq(Levels.evolveLevel(2), 1)
		local last = 1
		for tier = 1, #Config.Pickaxes do
			t.ok(Levels.evolveLevel(tier) >= last)
			last = Levels.evolveLevel(tier)
		end
	end)

	t.test("an average player (70 XP a meteor) never waits on a level for the early tiers", function()
		local result = Pacing.simulate(4 * 3600)
		local perMeteor, cycle = 70, result.cycle
		for _, purchase in result.purchases do
			local tier = tonumber(string.match(purchase.id, "^pickaxe(%d+)$"))
			if tier and tier <= 6 then
				local meteors = math.max(math.floor((purchase.time - Config.Meteor.FirstCountdown) / cycle) + 1, 0)
				local level = Levels.clean(1, meteors * perMeteor).level
				t.ok(level >= Levels.evolveLevel(tier), "pickaxe " .. tier .. " bought at " .. math.floor(purchase.time / 60) .. " min needs level " .. Levels.evolveLevel(tier) .. ", has " .. level)
			end
		end
	end)
end

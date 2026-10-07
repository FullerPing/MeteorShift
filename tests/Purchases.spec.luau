--!strict
-- Fixed developer-product arithmetic and receipt retries. No grant rolls pets,
-- changes mineral odds, or creates Core Shards.

return function(t: any)
	local Purchases = require(t.shared.Purchases)
	local Config = require(t.shared.Config)
	local Rebirth = require(t.shared.Rebirth)

	local function profile(): any
		return {
			cash = 100, shards = 12, overclockLeft = 60, oreBoostLeft = 30,
			credits = { callMeteor = 2 }, receipts = {},
			pets = {
				owned = { pebblePup = { level = 1, xp = 0 }, scrapSparrow = { level = 1, xp = 0 }, packMule = { level = 1, xp = 0 } },
				equipped = { "pebblePup", "scrapSparrow" }, hatches = { meteor = 4 },
			},
		}
	end

	t.test("micro-purchases have the intended fixed prices and remain off sale", function()
		for key, price in { TipJar = 5, PocketChange = 10, PetTreat = 15, MiniOverclock = 19, OreRush = 25, PetFeast = 29, CashBundle = 39 } do
			t.eq(Config.Monetization.Products[key].Robux, price, key)
			t.eq(Config.Monetization.Products[key].Id, 0, key)
			t.ok(table.find(Config.Monetization.ProductOrder, key), key .. " listed")
		end
		t.eq(Config.Monetization.Passes.ExtraPetSlot.Robux, 49)
		t.eq(Config.Monetization.Passes.ExtraPetSlot.Id, 0)
		t.ok(table.find(Config.Monetization.PassOrder, "ExtraPetSlot"))
		t.eq(Config.Monetization.Passes.Drillbot.Robux, 99)
		t.eq(Config.Monetization.Passes.SolarPhoenix.Robux, 199)
		for _, entry in Config.Monetization.Passes do t.eq(entry.Id, 0) end
		for _, entry in Config.Monetization.Products do t.eq(entry.Id, 0) end
	end)

	t.test("cash uses minutes, current line rate, bar price and sale multiplier", function()
		t.eq(Purchases.cashGrant(10, 2, 25, 1.5, 2000, 300000), 45000)
		t.eq(Purchases.cashGrant(1, 0.25, 10.1, 1, 0, 10000), 151)
	end)

	t.test("cash floors and rebirth ceilings limit each pack", function()
		t.eq(Purchases.cashGrant(10, 0, 0, 1, 2000, 300000), 2000)
		t.eq(Purchases.cashGrant(60, 0, 0, 1, 20000, 800000), 20000)
		for rebirths = 0, 4 do
			local cost = Rebirth.cost(rebirths)
			for key, pack in Config.Monetization.CashPacks do
				local cash = Purchases.cashGrant(pack.Minutes, 1e12, 1e12, 1e12, pack.Floor, cost * pack.CeilingShare)
				t.eq(cash, math.floor(cost * pack.CeilingShare), key)
				t.ok(cash < cost, key .. " cannot buy a rebirth by itself")
			end
		end
		t.eq(Purchases.cashGrant(10, 0, 0, 1, 2000, 500), 500, "ceiling takes precedence")
	end)

	t.test("a higher level never lowers the quote, and underleveled ore counts for a fraction", function()
		local previous = 0
		for level = 1, Config.Levels.MaxLevel do
			local price = Purchases.averageBarPrice(level)
			t.ok(price >= previous - 1e-9, "level " .. level)
			previous = price
		end
		-- Level 1: weights 60, 25 x 0.4, 15 x 0.4; weighted value 7,200 / 76.
		t.near(Purchases.averageBarPrice(1), 7200 / 76, 1e-9)
	end)

	t.test("once every ore is cleared the quote uses the plain meteor weights", function()
		-- Weights 60, 25, 15; weighted value 3,000 + 3,750 + 6,750 over 100.
		t.near(Purchases.averageBarPrice(Config.Levels.OreLevel.crystal), 135, 1e-9)
		t.near(Purchases.averageBarPrice(Config.Levels.MaxLevel), 135, 1e-9)
	end)

	t.test("ore pass and timed Ore Rush use the larger multiplier", function()
		t.eq(Purchases.oreMultiplier(false, nil), 1)
		t.eq(Purchases.oreMultiplier(false, 0), 1)
		t.eq(Purchases.oreMultiplier(false, -1), 1)
		t.eq(Purchases.oreMultiplier(false, 0.1), 2)
		t.eq(Purchases.oreMultiplier(true, 0), 2)
		t.eq(Purchases.oreMultiplier(true, 1800), 2, "never multiplies to four")
	end)

	t.test("tip jar changes no gameplay profile values", function()
		local data = profile()
		t.ok(Purchases.grant(data, "TipJar"))
		t.eq(data.cash, 100)
		t.eq(data.shards, 12)
		t.eq(data.overclockLeft, 60)
		t.eq(data.oreBoostLeft, 30)
		t.eq(data.credits.callMeteor, 2)
		t.eq(data.pets.owned.pebblePup.xp, 0)
	end)

	t.test("cash packs add the computed cash grant only", function()
		for _, key in { "PocketChange", "CashBundle" } do
			local data = profile()
			local result = Purchases.grant(data, key, 2345)
			t.eq(result.cash, 2345)
			t.eq(data.cash, 2445)
			t.eq(data.shards, 12)
		end
		t.eq(Purchases.grant(profile(), "PocketChange"), nil, "requires a server-computed amount")
	end)

	t.test("pet treats and feasts give exact XP to each equipped pet once", function()
		for key, expected in { PetTreat = { level = 5, xp = 198 }, PetFeast = { level = 8, xp = 410 } } do
			local data = profile()
			-- A corrupted duplicate equipment entry cannot double the fixed grant.
			table.insert(data.pets.equipped, "pebblePup")
			local result = Purchases.grant(data, key)
			for _, id in { "pebblePup", "scrapSparrow" } do
				t.eq(data.pets.owned[id].level, expected.level, id)
				t.eq(data.pets.owned[id].xp, expected.xp, id)
				t.eq(result.leveled[id], expected.level)
			end
			t.eq(data.pets.owned.packMule.xp, 0, "unequipped pet untouched")
			t.eq(data.pets.owned.packMule.level, 1)
			t.eq(data.pets.hatches.meteor, 4, "pity unchanged")
			t.eq(data.shards, 12, "shards unchanged")
		end
	end)

	t.test("pet XP grants handle empty loadouts and max levels", function()
		local data = profile()
		table.clear(data.pets.equipped)
		t.ok(Purchases.grant(data, "PetTreat"))
		t.eq(data.pets.owned.pebblePup.level, 1)
		data.pets.equipped = { "pebblePup" }
		data.pets.owned.pebblePup = { level = Config.Pets.MaxLevel, xp = 0 }
		local result = Purchases.grant(data, "PetFeast")
		t.eq(data.pets.owned.pebblePup.xp, 0)
		t.eq(result.leveled.pebblePup, nil)
	end)

	t.test("online boosts add their exact durations", function()
		local data = profile()
		Purchases.grant(data, "MiniOverclock")
		t.eq(data.overclockLeft, 660)
		Purchases.grant(data, "Overclock")
		t.eq(data.overclockLeft, 2460, "original Overclock still grants 30 minutes")
		Purchases.grant(data, "OreRush")
		Purchases.grant(data, "OreRush")
		t.eq(data.oreBoostLeft, 3630)
		t.eq(data.shards, 12)
	end)

	t.test("Call a Meteor credit still grants once and unknown products grant nothing", function()
		local data = profile()
		t.ok(Purchases.grant(data, "CallMeteor"))
		t.eq(data.credits.callMeteor, 3)
		t.eq(Purchases.grant(data, "Shards"), nil)
		t.eq(Purchases.grant(data, "Egg"), nil)
		t.eq(data.shards, 12)
	end)

	t.test("receipt grants then remembers the PurchaseId before saving", function()
		local data = profile()
		local granted, fresh = Purchases.receipt(data, "purchase-1", function()
			t.eq(#data.receipts, 0)
			return Purchases.grant(data, "MiniOverclock") ~= nil
		end, function()
			t.eq(data.overclockLeft, 660)
			t.eq(data.receipts[1], "purchase-1")
			return true
		end)
		t.eq(granted, true)
		t.eq(fresh, true)
	end)

	t.test("failed saves retry without granting the same purchase twice", function()
		local data = profile()
		local grants, saves = 0, 0
		local function grant(): boolean
			grants += 1
			return Purchases.grant(data, "PetTreat") ~= nil
		end
		local function save(): boolean
			saves += 1
			return saves >= 2
		end
		t.eq(Purchases.receipt(data, "retry", grant, save), false)
		local level, xp = data.pets.owned.pebblePup.level, data.pets.owned.pebblePup.xp
		local granted, fresh = Purchases.receipt(data, "retry", grant, save)
		t.eq(granted, true)
		t.eq(fresh, false)
		t.eq(grants, 1)
		t.eq(saves, 2)
		t.eq(data.pets.owned.pebblePup.level, level)
		t.eq(data.pets.owned.pebblePup.xp, xp)
	end)

	t.test("saved receipts stay idempotent after more than fifty newer purchases", function()
		local data = profile()
		local grants = 0
		local function grant(): boolean grants += 1; return true end
		local function save(): boolean return true end
		for n = 1, 75 do t.eq(Purchases.receipt(data, "id-" .. n, grant, save), true) end
		t.eq(Purchases.receipt(data, "id-1", grant, save), true)
		t.eq(grants, 75)
		t.eq(#data.receipts, 75)
	end)

	t.test("missing profiles and failed grants leave receipts unacknowledged", function()
		local calls = 0
		local function unexpected(): boolean calls += 1; return true end
		t.eq(Purchases.receipt(nil, "missing", unexpected, unexpected), false)
		t.eq(Purchases.receipt(profile(), "", unexpected, unexpected), false)
		t.eq(calls, 0)
		local data = profile()
		t.eq(Purchases.receipt(data, "unknown", function() return false end, unexpected), false)
		t.eq(calls, 0, "failed grant is not saved")
		t.eq(#data.receipts, 0)
	end)
end

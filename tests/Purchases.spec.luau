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
			credits = { callMeteor = 2 }, receipts = {}, flags = {},
			pets = {
				owned = { pebblePup = { level = 1, xp = 0 }, scrapSparrow = { level = 1, xp = 0 }, packMule = { level = 1, xp = 0 } },
				equipped = { "pebblePup", "scrapSparrow" }, hatches = { meteor = 4 },
			},
		}
	end

	-- Developer products and passes created in the Creator Dashboard (id, intended Robux price)
	local LIVE = {
		OreRush = { 3717656636, 29 }, CallMeteor = { 3717657480, 19 }, BossMeteor = { 3717656947, 99 },
		Shards50 = { 3717688986, 19 }, Shards250 = { 3717689098, 69 }, Shards1000 = { 3717689250, 199 },
		RebirthKeep = { 3717690498, 99 }, StarterPack = { 3717709173, 49 }, PetMax = { 3717721195, 49 }, PetSlot = { 3717720944, 49 },
		PocketChange = { 3717721006, 19 }, CashBundle = { 3717721086, 59 }, MiniOverclock = { 3717721310, 19 }, Overclock = { 3717721351, 39 },
		PickaxeT1 = { 3717713942, 5 }, PickaxeT2 = { 3717691265, 9 }, PickaxeT3 = { 3717691317, 19 }, PickaxeT4 = { 3717691348, 49 },
		PickaxeT5 = { 3717712309, 89 }, PickaxeT6 = { 3717712401, 179 }, PickaxeT7 = { 3717712495, 259 },
		BackpackT1 = { 3717714256, 5 }, BackpackT2 = { 3717714331, 9 }, BackpackT3 = { 3717714409, 19 }, BackpackT4 = { 3717714516, 39 },
		BackpackT5 = { 3717714654, 89 }, BackpackT6 = { 3717714797, 179 }, BackpackT7 = { 3717714979, 259 },
	}
	local PASSES = {
		TwoXOre = { 2026934474, 149 }, TwoXCash = { 2026760484, 129 }, BiggerBackpack = { 2025488489, 99 },
		AutoDeposit = { 2026682466, 129 }, VIP = { 2027090469, 199 }, Drillbot = { 2026256458, 129 }, SolarPhoenix = { 2026178485, 249 },
	}

	t.test("products without a dashboard entry have the intended prices and stay off sale", function()
		for key, price in { TipJar = 5 } do
			t.eq(Config.Monetization.Products[key].Robux, price, key)
			t.eq(Config.Monetization.Products[key].Id, 0, key)
			t.ok(table.find(Config.Monetization.ProductOrder, key), key .. " listed")
		end
	end)

	t.test("the dashboard passes carry their ids and prices; Offline Hours+ is not created yet", function()
		for key, entry in Config.Monetization.Passes do
			local live = PASSES[key]
			t.eq(entry.Id, if live then live[1] else 0, key .. " id")
			if live then t.eq(entry.Robux, live[2], key .. " price") end
		end
		for key in PASSES do t.ok(table.find(Config.Monetization.PassOrder, key), key .. " listed") end
		t.eq(Config.Monetization.Passes.OfflineHours.Id, 0)
		t.eq(Config.Monetization.Passes.ExtraPetSlot, nil, "the pet slot is a product now")
		t.eq(Config.Monetization.Passes.TwoXCash.Robux, 129)
	end)

	t.test("the dashboard products carry their ids and prices; every other product is off sale", function()
		local seen: { [number]: string } = {}
		for key, entry in Config.Monetization.Products do
			local live = LIVE[key]
			t.eq(entry.Id, if live then live[1] else 0, key .. " id")
			if live then t.eq(entry.Robux, live[2], key .. " price") end
			if entry.Id ~= 0 then
				t.eq(seen[entry.Id], nil, key .. " shares an id")
				seen[entry.Id] = key
			end
		end
		for key in LIVE do t.ok(Config.Monetization.Products[key], key .. " exists") end
	end)

	t.test("tier-ups are sold in the gear shop only, never in the Store", function()
		for _, key in Config.Monetization.GearOrder do
			local product = Config.Monetization.Products[key]
			t.ok(product and product.Kind and product.From, key .. " is a tier-up")
			t.eq(table.find(Config.Monetization.ProductOrder, key), nil, key .. " is not a Store card")
		end
		for _, key in Config.Monetization.ProductOrder do
			t.eq(Config.Monetization.Products[key].Kind, nil, key .. " is a Store product")
		end
		t.eq(#Config.Monetization.GearOrder, 14, "tiers 1 to 7 of both items")
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

	t.test("shard packs add exactly their shards and nothing else", function()
		for key, amount in { Shards50 = 50, Shards250 = 250, Shards1000 = 1000 } do
			local data = profile()
			local result = Purchases.grant(data, key)
			t.eq(result.shards, amount, key)
			t.eq(data.shards, 12 + amount, key)
			t.eq(data.cash, 100)
			t.eq(data.credits.callMeteor, 2)
			t.eq(data.pets.hatches.meteor, 4, "pity unchanged")
		end
	end)

	t.test("level up pets to max takes only the equipped pets to the top level", function()
		local data = profile()
		table.insert(data.pets.equipped, "pebblePup") -- a duplicated entry counts once
		local result = Purchases.grant(data, "PetMax")
		local top = Config.Pets.MaxLevel
		t.eq(data.pets.owned.pebblePup.level, top)
		t.eq(data.pets.owned.scrapSparrow.level, top)
		t.eq(data.pets.owned.pebblePup.xp, 0)
		t.eq(result.leveled.pebblePup, top)
		t.eq(data.pets.owned.packMule.level, 1, "unequipped pet untouched")
		t.eq(data.shards, 12)
		t.eq(data.pets.hatches.meteor, 4, "pity unchanged")
		-- already maxed pets report no change
		local again = Purchases.grant(data, "PetMax")
		t.eq(again.leveled.pebblePup, nil)
	end)

	t.test("the extra pet slot is saved as a permanent profile flag", function()
		local data = profile()
		t.ok(Purchases.grant(data, "PetSlot"))
		t.eq(data.flags.extraPetSlot, true)
		t.eq(data.cash, 100)
		local bare = profile()
		bare.flags = nil
		t.ok(Purchases.grant(bare, "PetSlot"))
		t.eq(bare.flags.extraPetSlot, true, "creates the flags table when an old profile has none")
	end)

	t.test("the starter pack gives cash, two Mini Overclocks and pet XP once and marks the profile", function()
		local data = profile()
		local result = Purchases.grant(data, "StarterPack", 4321)
		t.eq(result.cash, 4321)
		t.eq(data.cash, 4421)
		t.eq(data.overclockLeft, 60 + 2 * 600)
		t.eq(data.pets.owned.pebblePup.level, 5)
		t.eq(data.pets.owned.pebblePup.xp, 198)
		t.eq(data.pets.owned.packMule.xp, 0, "unequipped pet untouched")
		t.eq(data.flags.starterPack, true)
		t.eq(data.shards, 12)
		t.eq(Purchases.grant(profile(), "StarterPack"), nil, "needs a server-computed cash amount")
	end)

	t.test("boss meteor and keep-everything add one credit each", function()
		local data = profile()
		t.ok(Purchases.grant(data, "BossMeteor"))
		t.ok(Purchases.grant(data, "BossMeteor"))
		t.eq(data.credits.bossMeteor, 2)
		t.ok(Purchases.grant(data, "RebirthKeep"))
		t.eq(data.credits.rebirthKeep, 1)
		t.eq(data.credits.callMeteor, 2, "the Call a Meteor credits are separate")
		t.eq(data.shards, 12)
	end)

	t.test("a tier-up evolves one tier, starts it over at level 1 and keeps the cash and shards", function()
		local data = profile()
		data.pickaxeTier, data.pickaxeLevel, data.backpackTier, data.backpackLevel = 3, 30, 3, 12
		local result = Purchases.gearSkip(data, "PickaxeT3", 3)
		t.eq(result.evolved, true)
		t.eq(result.tier, 4)
		t.eq(data.pickaxeTier, 4)
		t.eq(data.pickaxeLevel, 1)
		t.eq(data.backpackLevel, 12, "the other item keeps its level")
		t.eq(data.backpackTier, 3, "the other item is untouched")
		t.eq(data.cash, 100)
		t.eq(data.shards, 12)
		local backpack = profile()
		backpack.pickaxeTier, backpack.backpackTier = 5, 2
		t.eq(Purchases.gearSkip(backpack, "BackpackT2", 1).evolved, true)
		t.eq(backpack.backpackTier, 3)
		t.eq(backpack.pickaxeTier, 5)
	end)

	t.test("a tier-up for a tier already passed pays back that evolve's value instead", function()
		local Price = require(t.shared.Price)
		local data = profile()
		data.pickaxeTier = 5
		local target = Config.Pickaxes[3]
		local result = Purchases.gearSkip(data, "PickaxeT2", 3)
		t.eq(result.evolved, false)
		t.eq(data.pickaxeTier, 5, "never goes backwards or twice")
		t.eq(result.cash, Price.scaled(target.Cost, 3))
		t.eq(result.shards, target.Shards)
		t.eq(data.cash, 100 + result.cash)
		t.eq(data.shards, 12 + target.Shards)
	end)

	t.test("tier-ups reject non-tier-up keys and the top tier has nothing to skip to", function()
		local data = profile()
		t.eq(Purchases.gearSkip(data, "OreRush", 1), nil)
		t.eq(Purchases.gearSkip(data, "Nothing", 1), nil)
		data.pickaxeTier = #Config.Pickaxes
		local result = Purchases.gearSkip(data, "PickaxeT4", 1)
		t.eq(result.evolved, false)
		t.eq(data.pickaxeTier, #Config.Pickaxes)
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
			return Purchases.grant(data, "PetSlot") ~= nil
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

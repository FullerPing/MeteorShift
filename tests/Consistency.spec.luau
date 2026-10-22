--!strict
-- Consistency spec (from the LEDGER-B B1 display inventory, phase run 2026-10-18): every
-- duplicated player-visible number must equal its Config source. Controllers cannot be
-- required from specs, so each pair is asserted at the data layer the controller reads
-- verbatim (Store cards print Pass/Product Name+Description as-is, NativeMenus/Store.luau):
-- if the data agrees, the display agrees. Specs not run this phase (no Studio in session).

return function(t: any)
	local Config = require(t.shared.Config)
	local Format = require(t.shared.Format)
	local Pets = require(t.shared.Pets)

	-- B0 / B2-6 (the B1 DIFFERENT rows and the deleted mirror): the pet menu shows
	-- Monetization.Passes[def.Pass].Robux (PetsController), so the price must FLOW from
	-- Monetization (Pets.spec flow style, no number restated) and no pet may re-grow a
	-- local price copy (the stale 99/199 mirror removed in B2-6).
	t.test("premium pet prices flow from Config.Monetization through the Pass key", function()
		for _, petId in { "drillbot", "solarPhoenix" } do
			local def = Pets.def(petId) :: any
			t.eq(def.Rarity, "premium", petId .. " stays the premium pass line")
			local pass = if def.Pass then Config.Monetization.Passes[def.Pass] else nil
			t.ok(pass ~= nil, petId .. " Pass key resolves in Config.Monetization.Passes")
			t.ok(pass ~= nil and (pass.Robux or 0) > 0, petId .. " price lives in the pass, not on the pet")
		end
		for _, def in Config.Pets.List do
			t.ok((def :: any).Robux == nil, def.Name .. " must not mirror a price locally")
		end
	end)

	-- B2-5 (B1 Daily row): Config/Daily.luau fills every %d in a Title from that quest's own
	-- Target at load, so title==Target is structural there and restating the prose in a spec
	-- would re-create the duplication it guards. Pinned instead: the source (a positive
	-- integer Target exists to format from), the format actually ran (no raw %d survives a
	-- Title), and the only number a player reads in a formatted Title is that quest's Target.
	t.test("quest titles carry exactly their Target number", function()
		for _, list in { Config.Daily.Quests, Config.Daily.Weekly } do
			for _, def in list do
				t.eq(type(def.Target), "number", def.Id .. " has a Target to format from")
				t.ok(def.Target >= 1 and math.floor(def.Target) == def.Target, def.Id .. " Target is a positive integer")
				t.ok(string.find(def.Title, "%d") == nil or tonumber(string.match(def.Title, "%d+")) == def.Target,
					def.Id .. " the number the player reads equals Target")
				t.ok(string.find(def.Title, "%%d", 1, false) == nil, def.Id .. " Title was formatted at load")
			end
		end
	end)

	-- B2-1/2/3/4: the strings the controllers now render straight from Config (the Rebirth
	-- footer via Format.number, the two OfferController tile captions, StoreController's
	-- "You own" line). Anchors on purpose, tests/Purchases.spec price style: changing
	-- CashMult or a pass Name must re-fit this line, never drift from the display quietly.
	t.test("the B2 display sites still render from their Config fields", function()
		t.eq(Format.number(Config.Rebirth.CashMult), "5", "rebirth footer reads x" .. Config.Rebirth.CashMult)
		t.eq(Config.Monetization.Passes.TwoXCash.Name, "2x Cash", "offer tile caption")
		t.eq(Config.Monetization.Passes.TwoXOre.Name, "2x Ore", "offer tile caption + the You-own line")
	end)

	-- B2 skips + (d) equal rows readable without a controller: the number inside a Store
	-- card's text must equal its own numeric field. Extraction direction for leading amounts
	-- (thousands comma stripped, so "550" can never pass for 50); the find side follows the
	-- tostring idiom of tests/Daily.spec.luau:22.
	local function leadingAmount(text: string): number?
		local digits = string.match(text, "^([%d,]+)")
		if not digits then
			return nil
		end
		return tonumber((string.gsub(digits, ",", "")))
	end

	t.test("shard pack cards state the ShardPacks amount", function()
		for _, key in { "Shards50", "Shards250", "Shards1000" } do
			local pack = Config.Monetization.ShardPacks[key]
			local product = Config.Monetization.Products[key]
			t.ok(product ~= nil and pack ~= nil, key .. " exists on both sides")
			if product ~= nil and pack ~= nil then
				t.eq(leadingAmount(product.Name), pack, key .. " card title amount")
				t.eq(leadingAmount(product.Description), pack, key .. " card description amount")
			end
		end
	end)

	t.test("timed and boosted Store texts match their own fields", function()
		local M = Config.Monetization
		t.ok(string.find(M.Products.OreRush.Description, "×" .. M.OreRush.Multiplier, 1, true) ~= nil, "OreRush multiplier")
		t.ok(string.find(M.Products.OreRush.Description, "for " .. M.OreRush.Duration // 60 .. " minutes", 1, true) ~= nil, "OreRush duration")
		t.ok(string.find(M.Products.Overclock.Description, "×" .. M.Overclock.SpeedMult, 1, true) ~= nil, "Overclock multiplier")
		t.ok(string.find(M.Products.Overclock.Description, "for " .. M.Overclock.Duration // 60 .. " minutes", 1, true) ~= nil, "Overclock duration")
		t.ok(string.find(M.Products.MiniOverclock.Description, "×" .. M.Overclock.SpeedMult, 1, true) ~= nil, "Mini sells the shared Overclock speed (B1 p11)")
		t.ok(string.find(M.Products.MiniOverclock.Description, "for " .. M.MiniOverclock.Duration // 60 .. " minutes", 1, true) ~= nil, "MiniOverclock duration")
		t.ok(string.find(M.Products.CallMeteor.Description, "in " .. M.CallMeteor.SetCountdownTo .. " seconds", 1, true) ~= nil, "CallMeteor countdown")
		t.ok(string.find(M.Products.BossMeteor.Description, "in " .. M.CallMeteor.SetCountdownTo .. " seconds", 1, true) ~= nil, "BossMeteor countdown")
		t.ok(string.find(M.Products.BossMeteor.Description, "rebirth " .. Config.Meteor.Boss.MinRebirths, 1, true) ~= nil, "BossMeteor rebirth gate")
		t.ok(string.find(M.Passes.BiggerBackpack.Description, "×" .. M.BackpackMult, 1, true) ~= nil, "BiggerBackpack multiplier")
		t.ok(string.find(M.Passes.VIP.Description, "+" .. math.floor(M.VIPBarBonus * 100 + 0.5) .. "% bar", 1, true) ~= nil, "VIP bar bonus")
		t.ok(string.find(M.Passes.OfflineHours.Description, "up to " .. Config.Home.OfflineCapPass // 3600 .. " hours", 1, true) ~= nil, "OfflineHours pass cap (Config.Home)")
		t.ok(string.find(M.Passes.OfflineHours.Description, "instead of " .. Config.Home.OfflineCap // 3600, 1, true) ~= nil, "OfflineHours free cap (Config.Home)")
	end)

	-- Rebirth.luau Unlocks: every rank's "+N pet slot" is the slots that rank really adds (Shared.Pets.slots; rank 2 used
	-- to add one unannounced), and every field a rebirth opens is named on its rank.
	t.test("rebirth unlock lines announce the pet slots and fields each rank opens", function()
		local Pets = require(t.shared.Pets)
		for rank = 1, 8 do
			local line = Config.Rebirth.Unlocks[rank] or ""
			local shown = tonumber(string.match(line, "%+(%d+) pet slot")) or 0
			t.eq(shown, Pets.slots(rank) - Pets.slots(rank - 1), "pet slots at rank " .. rank)
		end
		for _, field in Config.Debris.Fields do
			local rank = field.Unlock and field.Unlock.Rebirths
			if rank then
				t.ok(string.find(Config.Rebirth.Unlocks[rank] or "", field.Name, 1, true) ~= nil, field.Name .. " at rank " .. rank)
			end
		end
	end)
end

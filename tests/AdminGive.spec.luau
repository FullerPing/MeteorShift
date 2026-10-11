--!strict
-- Spec for Lib.AdminGive, the admin /give command: reading the command, finding the recipient and
-- handing out cash, shards, gear tiers and pets without ever taking anything away.

return function(t: any)
	local AdminGive = require(t.lib.AdminGive)
	local Config = require(t.shared.Config)
	local Gear = require(t.shared.Gear)

	local function profile(): any
		return {
			cash = 100, shards = 5,
			pickaxeTier = 2, pickaxeLevel = 7, backpackTier = 3, backpackLevel = 4,
			pets = { owned = {}, equipped = {}, hatches = {} },
		}
	end

	local function gift(text: string): any
		local target, parsed, err = AdminGive.parse(text)
		t.ok(parsed ~= nil, text .. " -> " .. tostring(err))
		return { target = target, gift = parsed }
	end

	local function refuses(text: string)
		local target, parsed, err = AdminGive.parse(text)
		t.eq(target, nil, text)
		t.eq(parsed, nil, text)
		t.ok(err ~= nil and string.find(err, "Usage", 1, true) ~= nil, text .. " explains itself: " .. tostring(err))
	end

	t.test("cash and shards parse with the recipient, plain numbers and exponents", function()
		local a = gift("/give Bob cash 1500")
		t.eq(a.target, "Bob")
		t.eq(a.gift.kind, "cash")
		t.eq(a.gift.amount, 1500)
		t.eq(gift("/give Bob cash 1e6").gift.amount, 1000000)
		t.eq(gift("/give Bob shards 12.9").gift.amount, 12, "whole shards only")
		t.eq(gift("/GIVE bob SHARDS 5").gift.kind, "shards", "case does not matter")
	end)

	t.test("gear tiers parse within the tiers that exist", function()
		t.eq(gift("/give Bob pickaxe 5").gift.tier, 5)
		t.eq(gift("/give Bob backpack " .. #Config.Backpacks).gift.tier, #Config.Backpacks)
		refuses("/give Bob pickaxe 0")
		refuses("/give Bob pickaxe " .. (#Config.Pickaxes + 1))
		refuses("/give Bob backpack 2.5")
		refuses("/give Bob backpack x")
	end)

	t.test("pets parse by id or name, with an optional level", function()
		local plain = gift("/give Bob pet packMule")
		t.eq(plain.gift.petId, "packMule")
		t.eq(plain.gift.level, 1)
		t.eq(gift("/give Bob pet packmule 7").gift.level, 7, "ids ignore case")
		t.eq(gift("/give Bob pet PackMule 10").gift.petId, "packMule")
		refuses("/give Bob pet nothing")
		refuses("/give Bob pet packMule 0")
		refuses("/give Bob pet packMule " .. (Config.Pets.MaxLevel + 1))
	end)

	t.test("bad commands change nothing and say how to use /give", function()
		for _, text in { "/give", "/give Bob", "/give Bob cash", "/give Bob cash -5", "/give Bob cash 0", "/give Bob cash abc",
			"/give Bob cash 1e999", "/give Bob gold 5", "/give Bob cash 0.4" } do
			refuses(text)
		end
		local _, _, err = AdminGive.parse("/give")
		t.ok(string.find(err :: string, "Usage", 1, true) ~= nil, "the usage line")
	end)

	t.test("the recipient is found by name or display name, exactly or by prefix", function()
		local players = {
			{ Name = "Alice", DisplayName = "Ali" },
			{ Name = "Bobby", DisplayName = "Robert" },
			{ Name = "Alan", DisplayName = "Alan" },
		}
		t.eq(AdminGive.findPlayer("alice", players, 3), 1, "exact name, any case")
		t.eq(AdminGive.findPlayer("Robert", players, 3), 2, "display name")
		t.eq(AdminGive.findPlayer("bob", players, 3), 2, "prefix")
		t.eq(AdminGive.findPlayer("me", players, 3), 3, "me is the giver")
		t.eq(AdminGive.findPlayer("Ali", players, 3), 1, "an exact match beats a longer prefix")
		local none, noneErr = AdminGive.findPlayer("zed", players, 3)
		t.eq(none, nil)
		t.ok(string.find(noneErr :: string, "zed", 1, true) ~= nil, "names who it could not find")
		local many, manyErr = AdminGive.findPlayer("al", players, 3)
		t.eq(many, nil)
		t.ok(string.find(manyErr :: string, "Alice", 1, true) ~= nil and string.find(manyErr :: string, "Alan", 1, true) ~= nil, "lists the candidates")
		t.eq(AdminGive.findPlayer("me", players, nil), nil, "no giver, no me")
	end)

	t.test("cash and shards are added", function()
		local data = profile()
		local result = AdminGive.apply(data, gift("/give Bob cash 1000").gift, 3)
		t.eq(result.changed, true)
		t.eq(data.cash, 1100)
		t.ok(string.len(result.text) > 0)
		AdminGive.apply(data, gift("/give Bob shards 20").gift, 3)
		t.eq(data.shards, 25)
	end)

	t.test("a higher gear tier is given at its first level, a lower or equal one is refused", function()
		local data = profile()
		local up = AdminGive.apply(data, gift("/give Bob pickaxe 5").gift, 3)
		t.eq(up.changed, true)
		t.eq(up.gear, true, "the pickaxe tool needs restyling")
		t.eq(data.pickaxeTier, 5)
		t.eq(data.pickaxeLevel, Gear.levelsForTier(5))
		local same = AdminGive.apply(data, gift("/give Bob pickaxe 5").gift, 3)
		local lower = AdminGive.apply(data, gift("/give Bob pickaxe 1").gift, 3)
		for _, refused in { same, lower } do
			t.eq(refused.changed, false)
			t.eq(refused.gear, false)
		end
		t.eq(data.pickaxeTier, 5, "never downgraded")
		t.eq(data.pickaxeLevel, Gear.levelsForTier(5))
		local pack = AdminGive.apply(data, gift("/give Bob backpack 6").gift, 3)
		t.eq(pack.changed, true)
		t.eq(pack.gear, false, "a backpack needs no restyle")
		t.eq(data.backpackTier, 6)
		t.eq(data.backpackLevel, Gear.levelsForTier(6))
	end)

	t.test("a new pet is owned at its level and equipped while a slot is free", function()
		local data = profile()
		AdminGive.apply(data, gift("/give Bob pet packMule 10").gift, 2)
		t.eq(data.pets.owned.packMule.level, 10)
		t.eq(data.pets.owned.packMule.xp, 0)
		t.eq(#data.pets.equipped, 1)
		AdminGive.apply(data, gift("/give Bob pet pebblePup").gift, 2)
		AdminGive.apply(data, gift("/give Bob pet sparkHare 3").gift, 2)
		t.eq(#data.pets.equipped, 2, "the slots are full")
		t.eq(data.pets.owned.sparkHare.level, 3, "owned all the same")
		t.eq(table.find(data.pets.equipped, "sparkHare"), nil)
	end)

	t.test("a pet already owned only rises in level and keeps its XP", function()
		local data = profile()
		data.pets.owned.packMule = { level = 4, xp = 33 }
		data.pets.equipped = { "packMule" }
		local up = AdminGive.apply(data, gift("/give Bob pet packMule 8").gift, 3)
		t.eq(up.changed, true)
		t.eq(data.pets.owned.packMule.level, 8)
		t.eq(data.pets.owned.packMule.xp, 33)
		t.eq(#data.pets.equipped, 1, "not equipped twice")
		local down = AdminGive.apply(data, gift("/give Bob pet packMule 2").gift, 3)
		t.eq(down.changed, false)
		t.eq(data.pets.owned.packMule.level, 8, "never lowered")
	end)
end

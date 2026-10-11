--!strict
-- Spec for Config.Sounds, Config.Music and Config.RewardFX: every entry is playable as configured.

return function(t: any)
	local Config = require(t.shared.Config)

	local function isAsset(id: any): boolean
		return typeof(id) == "string" and (id:match("^rbxassetid://%d+$") ~= nil or id:match("^rbxasset://") ~= nil)
	end

	t.test("every sound has an asset id, a volume in 0..1 and a known group", function()
		for name, entry in Config.Sounds do
			t.ok(isAsset(entry.Id), name .. " Id")
			t.ok(entry.Volume > 0 and entry.Volume <= 1, name .. " Volume")
			t.ok(entry.Group == nil or entry.Group == "SFX" or entry.Group == "UI", name .. " Group")
		end
	end)

	t.test("pitch ranges are ordered and variants are non-empty asset ids", function()
		for name, entry in Config.Sounds do
			if entry.PitchMin or entry.PitchMax then
				t.ok(entry.PitchMin and entry.PitchMax and entry.PitchMin <= entry.PitchMax, name .. " pitch range")
			end
			if entry.Variants then
				t.ok(#entry.Variants > 0, name .. " Variants")
				for _, id in entry.Variants do t.ok(isAsset(id), name .. " variant id") end
			end
			if entry.Duck then t.ok(entry.Duck > 0 and entry.Duck <= 8, name .. " Duck") end
		end
	end)

	t.test("every sound the game plays by name is configured", function()
		for _, name in {
			"Swing", "CritHit", "CritSparkle", "OrePickup", "BackpackFull", "Deposit", "Collect", "CollectCoins",
			"Sell", "SellCoins", "Upgrade", "EvolveRise", "Evolve", "LevelUp", "PetChime", "Bonus", "RebirthWarp",
			"Rebirth", "Teleport", "HatchTick", "HatchCrack", "RevealCommon", "RevealRare", "RevealEpic",
			"RevealLegendary", "Click", "MenuOpen", "MenuClose", "Deny", "TutorialStep", "MeteorSiren", "MeteorBuild",
			"CoreStinger",
		} do
			t.ok(Config.Sounds[name] ~= nil, name)
		end
	end)

	t.test("music tracks and beds are asset ids at quiet volumes", function()
		for _, key in { "Hub", "Event", "Ambience", "CraterHum" } do
			local spec = Config.Music[key]
			t.ok(isAsset(spec.Id), key .. " Id")
			t.ok(spec.Volume > 0 and spec.Volume <= 0.5, key .. " Volume")
		end
		t.ok(Config.Music.DuckTo > 0 and Config.Music.DuckTo < 1, "DuckTo")
		t.ok(Config.Music.WarnAt > 2 and Config.Music.WarnAt <= Config.Atmosphere.ApproachLead, "WarnAt")
	end)

	t.test("reward effect sprites are asset ids", function()
		for name, id in Config.RewardFX.Sprites do
			t.ok(isAsset(id), name)
		end
	end)
end

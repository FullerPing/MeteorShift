--!strict
-- Spec for Shared.EquipmentModels: the shop/worn gear builders. Structural
-- invariants only: everything a returned Model must satisfy whether it came
-- from a MeshArt clone or the part-built fallback. Child part names are NOT
-- asserted -- the MeshArt path can replace the fallback's geometry wholesale.
-- `applyToTool` / `applyToCharacter` mutate a real Tool or character and stay
-- out of headless specs; they are verified in Studio.

return function(t: any)
	local EquipmentModels = require(t.shared.EquipmentModels)
	local Config = require(t.shared.Config)

	local function checkBuilt(label: string, model: Model, item: any)
		t.eq(model.ClassName, "Model", label)
		t.eq(model.Name, item.Name, label .. " is named for its config item")
		t.eq(model:GetAttribute("EquipmentTier"), item.Tier, label .. " records its tier")
		t.eq(model.Parent, nil, label .. " comes back unparented")
		local parts = 0
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				parts += 1
				t.ok(descendant.Anchored, label .. "/" .. descendant.Name .. " is anchored")
				t.eq(descendant.CanCollide, false, label .. "/" .. descendant.Name .. " has no physics")
				t.eq(descendant.CanTouch, false, label .. "/" .. descendant.Name)
				t.eq(descendant.CanQuery, false, label .. "/" .. descendant.Name)
				t.eq(descendant.CastShadow, false, label .. "/" .. descendant.Name .. " casts no shadow")
				t.eq(descendant.Massless, true, label .. "/" .. descendant.Name)
			end
		end
		t.ok(parts >= 1, label .. " carries at least one BasePart")
		if model.PrimaryPart == nil then
			-- Only the fallback path leaves PrimaryPart unset (meshModel requires a
			-- source PrimaryPart), and it pins WorldPivot to the origin explicitly.
			t.eq(model.WorldPivot, CFrame.identity, label .. " pivots at the origin")
		end
	end

	t.test("the config roster the builders index into is well-formed", function()
		t.ok(#Config.Pickaxes >= 1, "there are pickaxe tiers")
		t.ok(#Config.Backpacks >= 1, "there are backpack tiers")
		t.ok(#Config.Pickaxes >= #Config.Backpacks,
			"backpack() tints from Config.Pickaxes[tier].Color, so it needs a pickaxe colour per backpack tier")
		for _, group in { { label = "pickaxe", items = Config.Pickaxes }, { label = "backpack", items = Config.Backpacks } } do
			local seen = {}
			for index, item in group.items do
				t.eq(item.Tier, index, group.label .. " entry " .. index .. " records its own tier")
				t.ok(type(item.Name) == "string" and #item.Name > 0, group.label .. " entry " .. index .. " has a name")
				t.eq(seen[item.Name], nil, group.label .. " reuses the name " .. item.Name)
				seen[item.Name] = true
			end
		end
	end)

	t.test("every pickaxe tier builds its config item", function()
		for tier = 1, #Config.Pickaxes do
			checkBuilt("pickaxe " .. tier, EquipmentModels.pickaxe(tier), Config.Pickaxes[tier])
		end
	end)

	t.test("every backpack tier builds its config item", function()
		for tier = 1, #Config.Backpacks do
			checkBuilt("backpack " .. tier, EquipmentModels.backpack(tier), Config.Backpacks[tier])
		end
	end)

	t.test("an out-of-range tier falls back to the first item", function()
		-- both builders index `Config.<List>[tier] or Config.<List>[1]`, then re-derive
		-- the tier from item.Tier, so a bad tier builds tier 1, not the top tier
		local firstPick, firstPack = Config.Pickaxes[1], Config.Backpacks[1]
		t.eq(firstPick.Tier, 1, "the roster's first pickaxe is tier 1")
		t.eq(firstPack.Tier, 1, "the roster's first backpack is tier 1")
		checkBuilt("pickaxe 0", EquipmentModels.pickaxe(0), firstPick)
		checkBuilt("pickaxe 99", EquipmentModels.pickaxe(99), firstPick)
		checkBuilt("backpack 0", EquipmentModels.backpack(0), firstPack)
		checkBuilt("backpack 999", EquipmentModels.backpack(999), firstPack)
	end)
end

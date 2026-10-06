--!strict
-- Uses actual authored EquipmentModels and real mounts; no UI or service mocks.
return function(t: any)
	local module = t.shared:FindFirstChild("WorldEquipmentDisplay")
	t.test("local world equipment display exists", function() t.ok(module, "WorldEquipmentDisplay missing") end)
	if not module then return end
	local Display = require(module)
	local Config = require(t.shared.Config)
	local function fixture(offset: Vector3): Model
		local hall = Instance.new("Model")
		local walls = Instance.new("Folder"); walls.Name = "TierWalls"; walls.Parent = hall
		local stands = Instance.new("Folder"); stands.Name = "CurrentStands"; stands.Parent = hall
		for _, kind in { "pickaxe", "backpack" } do
			local list = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
			for _, item in list do
				local card = Instance.new("Part"); card.Name = kind .. item.Tier; card.CFrame = CFrame.new(offset + Vector3.new(item.Tier * 12, 20, 0))
				card:SetAttribute("EquipmentKind", kind); card:SetAttribute("EquipmentTier", item.Tier)
				card:SetAttribute("DisplayOffset", CFrame.new(0, 1, 4)); card:SetAttribute("DisplayScale", 1.5); card.Parent = walls
				local gui = Instance.new("SurfaceGui"); gui.Name = "TierLabel"; gui.Parent = card
				local text = Instance.new("TextLabel"); text.Name = "Status"; text.Parent = gui
			end
			local stand = Instance.new("Model"); stand.Name = kind; stand:SetAttribute("EquipmentKind", kind); stand.Parent = stands
			local foot = Instance.new("Part"); foot.CFrame = CFrame.new(offset + Vector3.new(if kind == "pickaxe" then 10 else 40, 1, 20)); foot.Parent = stand; stand.PrimaryPart = foot
			stand:SetAttribute("DisplayOffset", CFrame.new(0, 10, 0)); stand:SetAttribute("DisplayBottomOffset", Vector3.new(0, 5, 0)); stand:SetAttribute("DisplayScale", 2.2)
			local gui = Instance.new("SurfaceGui"); gui.Parent = foot
			local text = Instance.new("TextLabel"); text.Name = "Stats"; text.Parent = gui
		end
		return hall
	end
	t.test("incomplete streamed mounts cannot leave a partial local display", function()
		local hall = fixture(Vector3.zero)
		hall.TierWalls.pickaxe8:Destroy()
		local ok = pcall(function() Display.mount(hall) end)
		t.eq(ok, false)
		t.eq(hall:FindFirstChild("LocalEquipment"), nil)
		hall:Destroy()
	end)
	t.test("readiness detects missing mounts and recovers when they stream back", function()
		local hall = fixture(Vector3.zero)
		t.eq(Display.ready(nil), false)
		t.eq(Display.ready(hall), true)
		local card = hall.TierWalls.backpack8; card.Parent = nil
		t.eq(Display.ready(hall), false)
		card.Parent = hall.TierWalls
		t.eq(Display.ready(hall), true)
		local foot = hall.CurrentStands.pickaxe.PrimaryPart; foot.Parent = nil
		t.eq(Display.ready(hall), false)
		foot.Parent = hall.CurrentStands.pickaxe; hall.CurrentStands.pickaxe.PrimaryPart = foot
		t.eq(Display.ready(hall), true)
		hall:Destroy()
	end)
	t.test("local display integrity detects streamed equipment loss while authored mounts survive", function()
		local hall = fixture(Vector3.zero); local view = Display.mount(hall)
		t.ok(type(view.intact) == "function", "view:intact must detect missing local equipment")
		t.eq(view:intact(), true)
		for _, name in { "Tier_pickaxe_1", "Tier_backpack_1", "Current_pickaxe", "Current_backpack" } do
			local model = view.folder:FindFirstChild(name)
			t.ok(model, "missing local fixture " .. name)
			model.Parent = nil
			t.eq(Display.ready(hall), true, "authored mounts still available")
			t.eq(view:intact(), false, "missing local model " .. name)
			model.Parent = view.folder
			t.eq(view:intact(), true)
			local part: BasePart? = nil
			for _, candidate in model:GetDescendants() do
				if candidate:IsA("BasePart") and candidate ~= model.PrimaryPart then part = candidate; break end
			end
			assert(part, "equipment fixture needs a non-primary part")
			local parent = part.Parent
			part.Parent = nil
			t.eq(Display.ready(hall), true, "authored mounts survive individual part loss")
			t.eq(view:intact(), false, "missing local part in " .. name)
			part.Parent = parent
			t.eq(view:intact(), true)
		end
		view:update({ pickaxeTier = 4, backpackTier = 8 })
		t.eq(view:intact(), true, "normal tier replacement keeps the display complete")
		view:destroy()
		t.eq(view:intact(), false, "destroyed views cannot remain intact")
		hall:Destroy()
	end)
	t.test("builds exactly eighteen local noncolliding anchored models within budget", function()
		local hall = fixture(Vector3.zero)
		local view = Display.mount(hall)
		t.eq(#view.folder:GetChildren(), 18)
		local count = 0
		for _, part in view.folder:GetDescendants() do
			if part:IsA("BasePart") then count += 1; t.ok(part.Anchored); t.eq(part.CanCollide, false); t.eq(part.CanTouch, false); t.eq(part.CanQuery, false) end
		end
		t.ok(count > 0 and count <= 650, "world equipment part budget")
		view:destroy(); t.eq(hall:FindFirstChild("LocalEquipment"), nil); t.eq(#hall.TierWalls:GetChildren(), 16)
		hall:Destroy()
	end)
	t.test("State replaces changed tiers immediately but preserves unchanged models", function()
		local hall = fixture(Vector3.zero); local view = Display.mount(hall)
		local first = view.folder.Current_pickaxe
		view:update({ pickaxeTier = 1, backpackTier = 1, capacity = 99 })
		t.eq(view.folder.Current_pickaxe, first)
		t.eq(view.folder.Current_backpack:GetAttribute("Capacity"), 99)
		view:update({ pickaxeTier = 4, backpackTier = 8, swing = 0.33, reach = 19, capacity = 2400 })
		t.eq(first.Parent, nil)
		t.eq(view.folder.Current_pickaxe:GetAttribute("EquipmentTier"), 4)
		t.eq(view.folder.Current_backpack:GetAttribute("EquipmentTier"), 8)
		t.eq(view.folder.Current_pickaxe:GetAttribute("Swing"), 0.33)
		t.eq(view.folder.Current_pickaxe:GetAttribute("Reach"), 19)
		t.eq(hall.TierWalls.pickaxe4.TierLabel.Status.Text, "CURRENT")
		t.eq(hall.TierWalls.pickaxe3.TierLabel.Status.Text, "UNLOCKED")
		t.eq(hall.TierWalls.pickaxe5.TierLabel.Status.Text, "LOCKED")
		t.eq(#view.folder:GetChildren(), 18)
		view:destroy(); hall:Destroy()
	end)
	t.test("rotates only the two live models and mounts correctly at staging offset", function()
		local hall = fixture(Vector3.new(0, 0, 3000)); local view = Display.mount(hall)
		local wall, current = view.folder.Tier_pickaxe_1, view.folder.Current_pickaxe
		local fixed, moving = wall:GetPivot(), current:GetPivot()
		t.near(wall:GetPivot().Position.Z, 3004, 1e-3)
		t.near(current:GetPivot().Position.Z, 3020, 1e-3)
		view:step(1)
		t.eq(wall:GetPivot(), fixed)
		t.ok(current:GetPivot().LookVector:Dot(moving.LookVector) < 0.999, "current display rotates")
		view:destroy(); hall:Destroy()
	end)
end

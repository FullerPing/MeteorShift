-- Studio edit-mode tool: rebuilds ReplicatedStorage.PetModels.<id> from the Blender meshes in
-- ReplicatedStorage.MeshArt.pets (made by RobloxImport.luau), keeping what the game reads from the
-- part-built models: the model attributes (PetColor, PetName, Rarity, Flying, WorkingStyle) and the
-- effects (particles, lights, trails, beams and their attachments), moved to the same-named mesh part.
-- The level 10 look goes in a Level10 folder, as PetModel.clone expects. The part-built models are
-- kept in ServerStorage.SwapRollback.PetModels_parts (only on the first run).
--
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8124/tools/blender-assets/ApplyPetMeshes.luau", true))()()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local EFFECTS = { "ParticleEmitter", "Light", "Trail", "Beam", "Attachment" }

local function isEffect(x: Instance): boolean
	for _, class in EFFECTS do
		if x:IsA(class) then return true end
	end
	return false
end

-- Move the effects under `from` (a set of parts) onto the same-named parts in `to`, keeping each
-- attachment's offset from the model pivot.
local function moveEffects(fromParts: { Instance }, fromPivot: CFrame, to: Instance, toPivot: CFrame, body: BasePart)
	for _, part in fromParts do
		if not part:IsA("BasePart") then continue end
		local target = to:FindFirstChild(part.Name)
		if not (target and target:IsA("BasePart")) then target = body end
		for _, child in part:GetChildren() do
			if isEffect(child) then
				local copy = child:Clone()
				if copy:IsA("Attachment") then
					copy.Parent = target
					copy.WorldCFrame = toPivot * fromPivot:ToObjectSpace((child :: Attachment).WorldCFrame)
				else
					copy.Parent = target
				end
			end
		end
	end
	-- re-point trails and beams at the moved attachments
	for _, x in to:GetDescendants() do
		if x:IsA("Trail") or x:IsA("Beam") then
			for _, key in { "Attachment0", "Attachment1" } do
				local old = (x :: any)[key]
				if old then
					local match = nil
					for _, a in to:GetDescendants() do
						if a:IsA("Attachment") and a.Name == old.Name and a.Parent.Name == old.Parent.Name then match = a break end
					end
					if not match then
						for _, a in to:GetDescendants() do
							if a:IsA("Attachment") and a.Name == old.Name then match = a break end
						end
					end
					(x :: any)[key] = match
				end
			end
		end
	end
end

local function prepare(source: Model): Model
	local model = source:Clone()
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = true, false, false, false, true
			p.CastShadow = false
			if p.Name == "Pannier" then p:SetAttribute("Pannier", true) end
		end
	end
	return model
end

return function(): string
	local meshes = ReplicatedStorage:FindFirstChild("MeshArt") and ReplicatedStorage.MeshArt:FindFirstChild("pets")
	local pets = ReplicatedStorage:FindFirstChild("PetModels")
	assert(meshes and pets, "need ReplicatedStorage.MeshArt.pets and ReplicatedStorage.PetModels")

	local rollback = ServerStorage:FindFirstChild("SwapRollback") or Instance.new("Folder")
	rollback.Name = "SwapRollback"
	rollback.Parent = ServerStorage
	if not rollback:FindFirstChild("PetModels_parts") then
		local copy = pets:Clone()
		copy.Name = "PetModels_parts"
		copy.Parent = rollback
	end
	local partsSource = rollback.PetModels_parts

	local report = {}
	for _, old in partsSource:GetChildren() do
		local base, upgraded = meshes:FindFirstChild(old.Name), meshes:FindFirstChild(old.Name .. "_lv10")
		if not (old:IsA("Model") and base and upgraded) then
			table.insert(report, old.Name .. ": no mesh, kept parts")
			continue
		end
		local model = prepare(base)
		model.Name = old.Name
		for key, value in old:GetAttributes() do
			model:SetAttribute(key, value)
		end
		model:SetAttribute("PartCount", nil)
		model:SetAttribute("MeshPets", true)
		local body = model:FindFirstChild("Body") :: BasePart
		model.PrimaryPart = body

		-- level 1 effects come from the old model's own parts, level 10 ones from its Level10 folder
		local oldPivot = old:GetPivot()
		local oldTop, oldLevel10 = {}, {}
		local oldFolder = old:FindFirstChild("Level10")
		for _, x in old:GetDescendants() do
			if x:IsA("BasePart") then
				if oldFolder and x:IsDescendantOf(oldFolder) then table.insert(oldLevel10, x) else table.insert(oldTop, x) end
			end
		end
		moveEffects(oldTop, oldPivot, model, model:GetPivot(), body)

		local folder = Instance.new("Folder")
		folder.Name = "Level10"
		local up = prepare(upgraded)
		local upBody = up:FindFirstChild("Body") :: BasePart
		up.PrimaryPart = upBody
		up:PivotTo(model:GetPivot())
		moveEffects(if #oldLevel10 > 0 then oldLevel10 else oldTop, oldPivot, up, up:GetPivot(), upBody)
		for _, child in up:GetChildren() do
			child.Parent = folder
		end
		up:Destroy()
		folder.Parent = model

		local current = pets:FindFirstChild(old.Name)
		local where = if current then current:GetPivot() else oldPivot
		model:PivotTo(where)
		-- PetModel reads AnimationPivot in world space: move the stored joints with the model
		for _, p in model:GetDescendants() do
			local pivot = p:GetAttribute("AnimationPivot")
			if typeof(pivot) == "Vector3" then p:SetAttribute("AnimationPivot", where:PointToWorldSpace(pivot)) end
		end
		if current then current:Destroy() end
		model.Parent = pets
		local count = 0
		for _, p in model:GetDescendants() do if p:IsA("BasePart") then count += 1 end end
		table.insert(report, ("%s: %d mesh parts"):format(old.Name, count))
	end
	table.sort(report)
	return table.concat(report, "\n")
end

-- Studio edit-mode tool: turns the 3D-Importer output of blender/roblox-import/*.fbx into
-- ready-to-use Models in ReplicatedStorage.MeshArt.<group>.<asset>.
--
-- Run from the command bar (with `python -m http.server 8124` serving the repo root):
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8124/tools/blender-assets/RobloxImport.luau"))()()
--
-- Every imported MeshPart is named "<group>__<asset>#<i>" (combine_for_roblox.py), where i indexes
-- the asset's "objects" in blender/manifest.json. From that JSON this restores:
--   names (roblox_name), Neon material, white tintable surfaces (attribute Tint), hidden work props,
--   AnimationGroup / AnimationPivot (world Vector3, as PetModel expects), stud scale, the asset's
--   pivot (Blender origin), and the meteor core's 36 NodeSlot attachments.
-- The 3D Importer brings these files in lying on their back; FIX stands them up and turns them so the
-- Blender front (-Y) faces Roblox -Z, like every part-built model in the game. Blender (x, y, z) is
-- then Roblox (-x, z, y). Rerunnable: models already in MeshArt from an older run (attribute
-- Orientation ~= 2, still in importer orientation) are redone, finished ones are left alone.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BASE = "http://127.0.0.1:8124/blender/"

-- Neon colours the JSON does not carry (metadata.preview_neon is used when it does).
local GLOW = {
	["eggs/egg_meteor"] = "#FF963C",
	["eggs/egg_crystal"] = "#6DEFFF",
	["eggs/egg_aurora"] = "#C8FFF0",
}

local FIX = CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.pi / 2, math.pi, 0)
local ORIENTATION = 2

local function rb(v: { number }): Vector3
	return Vector3.new(-v[1], v[3], v[2])
end

local function folder(parent: Instance, name: string): Instance
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function fetchJson(path: string)
	return HttpService:JSONDecode(HttpService:GetAsync(BASE .. path))
end

return function(): string
	local manifest = fetchJson("manifest.json")
	local extra = {} -- optional assets are not in the manifest: load their JSON on demand
	local function meta(group: string, asset: string)
		local key = group:gsub("_", "/", 1) .. "/" .. asset -- meteor_minerals -> meteor/minerals
		if group == "meteor_minerals" then key = "meteor/minerals/" .. asset end
		if manifest[key] then return manifest[key] end
		if extra[key] == nil then
			local ok, data = pcall(fetchJson, key .. ".json")
			extra[key] = if ok then data else false
		end
		return extra[key] or nil
	end

	-- gather imported parts by asset
	local byAsset: { [string]: { [number]: MeshPart } } = {}
	local found = 0
	for _, root in { workspace, game:GetService("ServerStorage"), ReplicatedStorage } do
		for _, d in root:GetDescendants() do
			if d:IsA("MeshPart") then
				local holder, index = d.Name:match("^(.-)#(%d+)$")
				if holder and holder:find("__", 1, true) then
					byAsset[holder] = byAsset[holder] or {}
					byAsset[holder][tonumber(index) :: number] = d
					found += 1
				end
			end
		end
	end
	local store = folder(ReplicatedStorage, "MeshArt")
	for _, groupFolder in store:GetChildren() do
		for _, old in groupFolder:GetChildren() do
			if old:IsA("Model") and old:GetAttribute("Orientation") ~= ORIENTATION then
				local holder = groupFolder.Name .. "__" .. old.Name
				byAsset[holder] = byAsset[holder] or {}
				for _, d in old:GetChildren() do
					local index = d:GetAttribute("BlenderIndex")
					if d:IsA("MeshPart") and index then
						byAsset[holder][index] = d
						found += 1
					end
				end
			end
		end
	end

	local report, problems = {}, {}
	for holder, parts in byAsset do
		local group, asset = holder:match("^(.-)__(.+)$")
		local info = meta(group, asset)
		if not info then
			table.insert(problems, holder .. ": no JSON")
			continue
		end
		local model = Instance.new("Model")
		model.Name = asset
		local first: MeshPart? = nil
		for i, o in info.objects do
			local part = parts[i - 1]
			if not part then
				table.insert(problems, holder .. ": missing #" .. (i - 1) .. " " .. o.roblox_name)
				continue
			end
			part.Parent = model
			part.Name = o.roblox_name
			part.Anchored = true
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			part:SetAttribute("BlenderIndex", i - 1)
			if o.neon then
				part.Material = Enum.Material.Neon
				part.TextureID = ""
				local glow = GLOW[info.id] or (info.metadata and info.metadata.preview_neon)
				if glow then part.Color = Color3.fromHex(glow) end
			else
				part.Material = Enum.Material.SmoothPlastic
			end
			if o.runtime_tint then
				part:SetAttribute("Tint", true)
				part.Color = Color3.new(1, 1, 1)
				part.TextureID = ""
			end
			if o.work_prop then
				part:SetAttribute("WorkProp", true)
				part.Transparency = 1
			end
			if o.animation_group then part:SetAttribute("AnimationGroup", o.animation_group) end
			first = first or part
		end
		if not first then
			model:Destroy()
			continue
		end

		for _, a in model:GetDescendants() do
			if a:IsA("Attachment") then a:Destroy() end -- rebuilt below
		end
		local center = model:GetBoundingBox().Position
		model.WorldPivot = CFrame.new(center)
		model:PivotTo(CFrame.new(center) * FIX)
		model.WorldPivot = CFrame.new(center)

		-- stud scale from the JSON height (Blender Z), then the asset origin from the bounds centre
		local lo, hi = rb(info.bounds[1]), rb(info.bounds[2])
		local jsonMin, jsonMax = lo:Min(hi), lo:Max(hi)
		local jsonSize, jsonCenter = jsonMax - jsonMin, (jsonMax + jsonMin) / 2
		local box, size = model:GetBoundingBox()
		local axis = if jsonSize.Y > 0.05 then "Y" elseif jsonSize.X > 0.05 then "X" else "Z"
		local scale = jsonSize[axis] / size[axis]
		if math.abs(scale - 1) > 0.01 then
			model.WorldPivot = box
			model:ScaleTo(scale)
			box, size = model:GetBoundingBox()
		end
		local origin = box.Position - jsonCenter
		model.WorldPivot = CFrame.new(origin)
		for _, a in info.attachments or {} do
			local att = Instance.new("Attachment")
			att.Name = a.name
			local p, n = origin + rb(a.position), rb(a.normal).Unit
			att.WorldCFrame = CFrame.lookAt(p, p + n) -- LookVector points out of the surface
			att.Parent = model:FindFirstChild("Core") or first
		end
		model:SetAttribute("BlenderId", info.id)
		model:SetAttribute("Orientation", ORIENTATION)
		model:SetAttribute("Triangles", info.triangles)
		if info.metadata and info.metadata.PetColor then
			model:SetAttribute("PetColor", Color3.fromHex(info.metadata.PetColor))
		end
		model.PrimaryPart = (model:FindFirstChild("Body") or model:FindFirstChild("Core") or first) :: BasePart
		-- keep the Blender origin as the pivot: with a PrimaryPart the pivot is PrimaryPart.PivotOffset
		local primary = model.PrimaryPart :: BasePart
		primary.PivotOffset = primary.CFrame:ToObjectSpace(CFrame.new(origin))
		model:PivotTo(CFrame.new())
		-- world-space joint positions, as PetModel reads them; the stored model sits at the origin
		for i, o in info.objects do
			local part = parts[i - 1]
			if part and o.animation_pivot then
				part:SetAttribute("AnimationPivot", rb(o.animation_pivot))
			end
		end

		local dest = folder(store, group)
		local old = dest:FindFirstChild(asset)
		if old then old:Destroy() end
		model.Parent = dest
		table.insert(report, group .. "/" .. asset .. string.format(" x%.3f", scale))
	end

	table.sort(report)
	return string.format("%d parts, %d assets\n", found, #report)
		.. (if #problems > 0 then "PROBLEMS:\n" .. table.concat(problems, "\n") .. "\n" else "")
		.. table.concat(report, "\n")
end

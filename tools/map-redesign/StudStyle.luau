-- Standalone Edit-time visual pass; no saved scripts or new BaseParts.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before authoring")
local map = assert(workspace:FindFirstChild("Map_Redesign"), "Staged map required")
assert(map:GetAttribute("MapRedesignOwned"), "Unowned staged map")
local textureId = "rbxassetid://6927295847"
local normals = {
	{Enum.NormalId.Top, Vector3.yAxis, "Y", "X", "Z"},
	{Enum.NormalId.Bottom, -Vector3.yAxis, "Y", "X", "Z"},
	{Enum.NormalId.Right, Vector3.xAxis, "X", "Y", "Z"},
	{Enum.NormalId.Left, -Vector3.xAxis, "X", "Y", "Z"},
	{Enum.NormalId.Front, -Vector3.zAxis, "Z", "X", "Y"},
	{Enum.NormalId.Back, Vector3.zAxis, "Z", "X", "Y"},
}
local excludedAncestors = {
	FurnaceAssembly = true, FeedConveyor = true, OreHopper = true,
	Exhibits = true, TierWalls = true, CurrentStands = true,
	meteorEgg = true, crystalEgg = true,
}
local before, original = {}, {}
local function snapshot(root, into)
	for _,part in root:GetDescendants() do
		if part:IsA("BasePart") then
			into[part] = {part.CFrame, part.Size, part.Anchored, part.CanCollide,
				part.CanTouch, part.CanQuery, part.Transparency, part.Material, part.Color}
		end
	end
end
snapshot(map, before)
snapshot(assert(workspace:FindFirstChild("Map")), original)
local function category(part)
	if part.Transparency > 0.05 or part:FindFirstChildWhichIsA("SurfaceGui") then return nil end
	if part.Material == Enum.Material.Neon or part.Material == Enum.Material.Glass
		or part.Material == Enum.Material.Rubber then return nil end
	local ancestor = part.Parent
	while ancestor and ancestor ~= map do
		if excludedAncestors[ancestor.Name] then return nil end
		ancestor = ancestor.Parent
	end
	local root = part
	while root.Parent ~= map do root = root.Parent end
	if root.Name == "Ground" then return "Ground" end
	if root.Name == "Roads" then return "Roads" end
	if root.Name == "Crater" then return "Crater" end
	if root.Name == "TownSquare" then return "Town" end
	if root.Name == "DebrisFields" then return "Fields" end
	if root.Name == "Boundary" then return "Boundary" end
	if root.Name == "Scenery" and part.Name == "Crown" then return "Scenery" end
	return nil
end
local desired, counts, targets, created, updated = {}, {}, 0, 0, 0
for part in before do
	local group = category(part)
	if not group then continue end
	if part:IsA("Part") and part.Shape == Enum.PartType.Ball then continue end
	if part:IsA("WedgePart") then continue end
	local block = part:IsA("Part") and part.Shape == Enum.PartType.Block
	local selected = {}
	for _,face in normals do
		local up = part.CFrame:VectorToWorldSpace(face[2]).Y
		local u, v = part.Size[face[4]], part.Size[face[5]]
		local architecturalSide = (group == "Town" or group == "Boundary") and block and up > -0.1
		if (up > 0.6 or architecturalSide) and u >= 2 and v >= 2 and u*v >= 24 then
			local name = "WorldStuds_" .. face[1].Name
			local texture = part:FindFirstChild(name)
			if texture then
				assert(texture:IsA("Texture") and texture:GetAttribute("MapRedesignStudOwned"),
					"Unowned stud texture: " .. part:GetFullName())
				updated += 1
			else
				texture = Instance.new("Texture")
				texture.Name = name
				texture:SetAttribute("MapRedesignStudOwned", true)
				texture.Parent = part
				created += 1
			end
			texture.Face = face[1]
			texture.Texture = textureId
			texture.Color3 = part.Color
			texture.StudsPerTileU, texture.StudsPerTileV = 4, 4
			texture.OffsetStudsU, texture.OffsetStudsV = 0, 0
			texture.Transparency = if group == "Ground" then 0.2
				elseif group == "Roads" then 0.3 elseif group == "Crater" then 0.4 else 0.35
			selected[name] = true
			desired[texture] = true
			counts[group] = (counts[group] or 0) + 1
		end
	end
	if next(selected) then targets += 1 end
end
for _,item in map:GetDescendants() do
	if item:IsA("Texture") and item:GetAttribute("MapRedesignStudOwned") and not desired[item] then
		item:Destroy()
	end
end
local function unchanged(root, baseline)
	local n = 0
	for _,part in root:GetDescendants() do
		if part:IsA("BasePart") then
			n += 1
			local expected = assert(baseline[part], "Added geometry")
			local actual = {part.CFrame, part.Size, part.Anchored, part.CanCollide,
				part.CanTouch, part.CanQuery, part.Transparency, part.Material, part.Color}
			for i,value in actual do assert(value == expected[i], "Geometry/collision changed") end
		end
	end
	local expectedCount = 0
	for _ in baseline do expectedCount += 1 end
	assert(n == expectedCount, "Removed geometry")
	return n
end
local parts = unchanged(map, before)
local originalParts = unchanged(workspace.Map, original)
local loaded = {}
local sample = next(desired)
if sample then
	game:GetService("ContentProvider"):PreloadAsync({sample}, function(id,status)
		table.insert(loaded, {asset=id, status=status.Name})
	end)
end
map:SetAttribute("StudStyleVersion", 1)
map:SetAttribute("StudTexture", textureId)
map:SetAttribute("StudTileSize", 4)
return {stage="StudStyle", texturedParts=targets, faces=counts, created=created,
	updated=updated, parts=parts, originalParts=originalParts, addedParts=0,
	geometryAndCollisionPreserved=true, textureLoad=loaded}

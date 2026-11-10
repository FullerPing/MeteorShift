-- Map dressing meshes into ServerStorage.MapArt.Dress (2026-10-21). Built in Blender by tools/blender-assets/map_dress.py,
-- uploaded with upload_open_cloud.py (ids below, from blender/upload/asset-ids.json). Run once in Edit from the command bar or
-- MCP; the result is saved with the place, and tools/map-v3/MeshDress.luau places it.
-- Each entry becomes one MeshPart named after the asset with the other pieces under it: rocks keep DebrisService's shape
-- (the Root collides; OreFleck children are white Neon the server tints by tier; Glow is fixed Neon), lamps and trees the
-- same with their Glow / Canopy pieces. `Ground` is the drop from the Root's centre to the asset's base.
local IDS = {
	props_street_lamp = 104372790346697,
	props_wall_lantern = 104474551270466,
	rocks_ember_0 = 92357599297567,
	rocks_ember_1 = 110775464926148,
	rocks_ember_2 = 123308667584771,
	rocks_frost_0 = 108125905926645,
	rocks_frost_1 = 74042307435801,
	rocks_frost_2 = 92349314384484,
	rocks_glass_0 = 101488090055370,
	rocks_glass_1 = 100168335884672,
	rocks_glass_2 = 88752487260824,
	rocks_halo_0 = 101356975885004,
	rocks_halo_1 = 95616575860362,
	rocks_halo_2 = 140608078481012,
	rocks_rust_0 = 132366592209038,
	rocks_rust_1 = 87318576443970,
	rocks_rust_2 = 104868951529176,
	rocks_star_0 = 77475113677200,
	rocks_star_1 = 137166107455069,
	rocks_star_2 = 95067606383066,
	rocks_sulfur_0 = 102490525106664,
	rocks_sulfur_1 = 103912656379399,
	rocks_sulfur_2 = 110779614807151,
	rocks_violet_0 = 122304480455964,
	rocks_violet_1 = 121771053005354,
	rocks_violet_2 = 118530585540522,
	trees_palm_0 = 138620861586107,
	trees_palm_1 = 85872488532514,
	trees_pine_0 = 138311637658414,
	trees_pine_1 = 122816464960175,
	trees_round_0 = 109799929987131,
	trees_round_1 = 77314804389586,
	trees_round_2 = 124990021878344,
}
local GLOW = { ember = Color3.fromRGB(255, 122, 46), lamp = Color3.fromRGB(255, 214, 120), lantern = Color3.fromRGB(255, 214, 120) }

local art = game:GetService("ServerStorage"):WaitForChild("MapArt")
local dress = art:FindFirstChild("Dress") or Instance.new("Folder")
dress.Name, dress.Parent = "Dress", art
local made = 0
for name, id in IDS do
	local model = game:GetObjects("rbxassetid://" .. id)[1]
	local parts = {}
	for _, p in model:GetDescendants() do
		if p:IsA("MeshPart") then parts[(p.Name:match("__(%w+)$") or p.Name)] = p end
	end
	local root = assert(parts.Root, name .. ": no Root")
	local base = math.huge
	for _, p in parts do base = math.min(base, p.Position.Y - p.Size.Y / 2) end
	for piece, p in parts do
		p.Name, p.Anchored = piece, true
		if p ~= root then
			p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, piece == "Canopy"
			p.Parent = root
		end
		if piece == "OreFleck" then
			p.Material, p.Color, p.TextureID = Enum.Material.Neon, Color3.new(1, 1, 1), ""
		elseif piece == "Glow" then
			local kind = name:match("ember") or name:match("lamp") or name:match("lantern") or "lamp"
			p.Material, p.Color, p.TextureID = Enum.Material.Neon, GLOW[kind] or GLOW.lamp, ""
		end
	end
	root.Name = name
	root:SetAttribute("Ground", root.Position.Y - base)
	local old = dress:FindFirstChild(name)
	if old then old:Destroy() end
	root.Parent = dress
	model:Destroy()
	made += 1
	task.wait()
end
return ("Dress: %d meshes"):format(made)

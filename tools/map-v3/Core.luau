-- Map v3 core. Load Common first. The contract models, cloned from the archived v2 map (SwapRollback.Map_v8) and
-- placed on their v3 zones. Each v2 model's pivot sits on its zone centre with its look vector out of its front, so a
-- model goes to lookAt(zone centre, zone centre + facing) at its old pivot height.
-- Owns Map_Redesign.Crater, CraterApron and TownSquare:
--   Crater (whole, untouched); CraterApron (pieces inside r 124 only)
--   TownSquare: Refinery (same place), the six spawn points (same grid), Commissary, GearHall, Hatchery and the two
--   Leaderboards boards on their zones. GearHall and Hatchery stay under TownSquare: their controllers look there.
--   TradingPost and PickaxeShop are left out (selling and the shop open from the HUD; their services expect none).
local A = assert(_G.MapRedesignArt, "Run Common first")
local G = A.geometry
local source = game:GetService("ServerStorage").SwapRollback.Map_v8

local function own(x: Instance): Instance
	x:SetAttribute("MapRedesignOwned", true)
	for _, v in x:GetDescendants() do v:SetAttribute("MapRedesignOwned", true) end
	return x
end
local function clone(x: Instance, parent: Instance): Instance
	local copy = own(x:Clone())
	copy.Parent = parent
	return copy
end
local function place(model: Model, zoneId: string)
	local zone = A.zone(zoneId)
	local at = Vector3.new(zone.x, model:GetPivot().Y, zone.z)
	model:PivotTo(CFrame.lookAt(at, at + zone.facing))
end

local crater = A.map:FindFirstChild("Crater")
if crater then assert(crater:GetAttribute("MapRedesignOwned"), "Refusing to replace unowned Crater"); crater:Destroy() end
clone(source.Crater, A.map)
local apron = A.group(A.map, "CraterApron")
for _, piece in source.CraterApron:GetChildren() do
	local copy = clone(piece, apron)
	for _, part in (if copy:IsA("BasePart") then { copy } else copy:GetDescendants()) do
		if part:IsA("BasePart") and Vector3.new(part.Position.X, 0, part.Position.Z).Magnitude > 124 then part:Destroy() end
	end
end

local town = A.group(A.map, "TownSquare")
local v2 = source.TownSquare
clone(v2.Refinery, town)
for _, spawn in v2:GetChildren() do
	if spawn:IsA("SpawnLocation") then clone(spawn, town) end
end
place(clone(v2.Commissary, town) :: Model, "Commissary")
place(clone(v2.GearHall, town) :: Model, "GearHall")
place(clone(v2.Hatchery, town) :: Model, "Hatchery")
local boards = clone(v2.Leaderboards, town)
place(boards:FindFirstChild("BarsSold") :: Model, "LeaderboardEast")
place(boards:FindFirstChild("Rebirths") :: Model, "LeaderboardWest")

return { stage = "Core", parts = A.count(A.map.Crater) + A.count(apron) + A.count(town), town = A.count(town), apron = A.count(apron) }

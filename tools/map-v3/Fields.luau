-- Map v3 ore fields. Load Common, Brick and Toon first, and pass the plan: L("../map-v3/Fields", L("../map-v3/PlanData")).
-- Owns Map_Redesign.Debris, DebrisFields, Gates and Chutes, all from PlanData rows with a `field`:
--   Debris: one rock per plan rock, cloned from an archived v2 rock (root Part + RockChunk/OreFleck children) of the
--     field's look, turned at random, standing on its tier, attribute Field = <id>.
--   DebrisFields.<Id>: one FieldFloor per block (PlanData `block`; thin, invisible, non-colliding; block 1's is the
--     PrimaryPart) under the block's rocks plus a margin, in the field's own frame; Entrance (the zone's entrance, facing
--     the gate). The locked-field eject treats every floor box as "inside", so the Entrance is asserted outside them all.
--   Gates.<Id>: per block the FieldGate mesh facing out of the side it stands on (the avenue, for the fields beside
--     one), a Barrier (not on fields without an Unlock) and the Rule label. A locked block is also ringed by glass
--     `Wall`s 2.5 studs outside its floor (Shared.FieldWalls), open in front of the gate with two short walls running out
--     to the barrier's ends, so the gate is the one way in. FieldGateController shows and hides walls and barrier together.
--     The Crown fields have no plan gate; theirs stands 4 studs past their entrance, as on the other tiers.
--   Chutes.<Id>: the OreChute mesh facing the crater and its UsePoint 9 studs in front of its pivot.
local A = assert(_G.MapRedesignArt, "Run Common first")
local T = assert(A.toon, "Run Toon first")
local plan = assert(..., "Pass the plan: L(\"../map-v3/PlanData\")")
local G = A.geometry
local Config = A.config -- a fresh copy: a plain require in Edit can return a stale cached module
local FieldWalls = require(game:GetService("ReplicatedStorage").Shared.FieldWalls:Clone() :: ModuleScript)
local v2 = game:GetService("ServerStorage").SwapRollback.Map_v8.Debris

local BAND_Y = { T0 = G.Tiers[1].y, T1 = G.Tiers[2].y, T2 = G.Tiers[3].y, CROWN = G.Crown.y }
-- which archived field's rocks each field borrows, and the tint for the new ones (nil keeps the v2 colours)
local LOOK = { RustWorks = "RustWorks", FrostYard = "FrostYard", VioletQuarry = "VioletQuarry", SulfurRidge = "SulfurRidge",
	EmberShelf = "RustWorks", GlassScar = "FrostYard", Starfall = "VioletQuarry", HaloLedge = "SulfurRidge" }
local MARGIN = 2 -- past the rocks' footprints; more and the eject box reaches the avenue kerbs beside Rust and Frost

local debris = A.group(A.map, "Debris", "Folder")
local fieldsGroup = A.group(A.map, "DebrisFields")
local gates = A.group(A.map, "Gates")
local chutes = A.group(A.map, "Chutes")

local byField: { [string]: { rocks: { any }, blocks: { { rocks: { any }, gate: any? } }, chute: any? } } = {}
for _, row in plan.footprints do
	if row.field then
		local f = byField[row.field] or { rocks = {}, blocks = {} }
		byField[row.field] = f
		local block = f.blocks[row.block or 1] or { rocks = {} }
		f.blocks[row.block or 1] = block
		if row.kind == "rock" then table.insert(f.rocks, row); table.insert(block.rocks, row)
		elseif row.kind == "gate" then block.gate = row elseif row.kind == "chute" then f.chute = row end
	end
end

-- move a rock root and its welded-by-position children together (PivotTo on a Part moves only that part)
local function moveRock(root: BasePart, cf: CFrame)
	local rel = {}
	for _, child in root:GetChildren() do
		if child:IsA("BasePart") then rel[child] = root.CFrame:ToObjectSpace(child.CFrame) end
	end
	root.CFrame = cf
	for child, offset in rel do child.CFrame = cf * offset end
end

local function face(part: BasePart, toward: Vector3): Enum.NormalId
	local best, bestDot = Enum.NormalId.Front, -2
	for _, id in Enum.NormalId:GetEnumItems() do
		local d = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(id)):Dot(toward)
		if d > bestDot then best, bestDot = id, d end
	end
	return best
end

local summary = {}
for index, field in Config.Debris.Fields do
	local id = field.Id
	local f = assert(byField[id], "No plan rows for " .. id)
	local zone = A.zone(id)
	local first = f.rocks[1]
	local y = BAND_Y[first.band]
	local yaw = math.rad(first.yaw)
	local out = Vector3.new(math.cos(yaw), 0, math.sin(yaw)) -- the field's depth axis, away from the crater
	local across = Vector3.new(-out.Z, 0, out.X)
	local rng = Random.new(index)

	-- rocks
	local pool = {}
	for _, rock in v2:GetChildren() do if rock:GetAttribute("Field") == LOOK[id] then table.insert(pool, rock) end end
	local tint = if LOOK[id] ~= id then field.Color:Lerp(Color3.new(0, 0, 0), .35) else nil
	for k, row in f.rocks do
		local rock = pool[rng:NextInteger(1, #pool)]:Clone()
		rock.Name = id .. "Rock" .. k
		rock:SetAttribute("Field", id)
		rock:SetAttribute("MapRedesignOwned", true)
		for _, v in rock:GetDescendants() do v:SetAttribute("MapRedesignOwned", true) end
		if tint then
			rock.Color = tint
			for _, chunk in rock:GetChildren() do if chunk:IsA("BasePart") and chunk.Name == "RockChunk" then chunk.Color = tint:Lerp(Color3.new(1, 1, 1), .12) end end
		end
		moveRock(rock, CFrame.new(row.x, y + rock.Size.Y / 2, row.z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		rock.Parent = debris
	end

	-- per block: floor, gate (mesh, barrier, walls, sign)
	local model = A.group(fieldsGroup, id)
	local e = zone.entrance
	local entranceAt = Vector3.new(e.X, y, e.Z)
	local firstFacing: Vector3? = nil
	local gateModel = A.group(gates, id) -- once: A.group replaces a group of the same name
	for b, block in f.blocks do
		local dMin, dMax, uMin, uMax = math.huge, -math.huge, math.huge, -math.huge
		for _, row in block.rocks do
			local p = Vector3.new(row.x, 0, row.z)
			local d, u = p:Dot(out), p:Dot(across)
			local half = math.max(row.w, row.d) / 2
			dMin, dMax, uMin, uMax = math.min(dMin, d - half), math.max(dMax, d + half), math.min(uMin, u - half), math.max(uMax, u + half)
		end
		local dMid, uMid = (dMin + dMax) / 2, (uMin + uMax) / 2
		local centre = out * dMid + across * uMid
		local floorCf = CFrame.lookAt(Vector3.new(centre.X, y + .1, centre.Z), Vector3.new(centre.X, y + .1, centre.Z) + out)
		local floor = A.part(model, "FieldFloor", Vector3.new(uMax - uMin + MARGIN * 2, .2, dMax - dMin + MARGIN * 2), floorCf, field.Color, nil, false)
		floor.Transparency, floor.CanQuery, floor.CastShadow = 1, false, false
		floor:SetAttribute("Block", b)
		if b == 1 then model.PrimaryPart = floor end
		local hx, hz = floor.Size.X / 2 + 2.5, floor.Size.Z / 2 + 2.5 -- the wall line
		local l = floor.CFrame:PointToObjectSpace(entranceAt)
		assert(math.abs(l.X) > floor.Size.X / 2 + 2 or math.abs(l.Z) > floor.Size.Z / 2 + 2,
			id .. ": the Entrance is inside the field's eject box; a locked player would be put back forever")

		-- gate: the plan's, or for the Crown fields one in front of the first rocks; it faces out of the side it is on
		local gatePos = if block.gate then Vector3.new(block.gate.x, y, block.gate.z) else entranceAt + out * 4
		local g = floor.CFrame:PointToObjectSpace(gatePos)
		local onX = math.abs(g.X) - hx > math.abs(g.Z) - hz
		local side = (if onX then "x" else "z") .. (if (if onX then g.X else g.Z) < 0 then "-" else "+")
		local facing = floor.CFrame:VectorToWorldSpace(if onX then Vector3.new(math.sign(g.X), 0, 0) else Vector3.new(0, 0, math.sign(g.Z)))
		firstFacing = firstFacing or facing
		-- the eject puts a locked player on the Entrance, so it must stand clear of the (solid for them) barrier
		assert(math.abs((entranceAt - gatePos):Dot(facing)) >= 3, id .. ": the Entrance is inside the gate's barrier")
		local mesh = T.mesh(gateModel, "FieldGate", CFrame.lookAt(gatePos, gatePos + facing), 25.2, function() error("ServerStorage.MapArt.FieldGate is missing; run Props") end)
		if field.Unlock then
			local barrier = A.part(gateModel, "Barrier", Vector3.new(24, 16, 1), CFrame.lookAt(gatePos + Vector3.new(0, 8, 0), gatePos + Vector3.new(0, 8, 0) + facing), Color3.fromRGB(111, 240, 224), Enum.Material.Glass, true)
			barrier.Transparency, barrier.CanQuery, barrier.CastShadow = .5, false, false
			local H = 12
			for _, seg in FieldWalls.segments(hx, hz, side, if onX then g.Z else g.X, math.abs(if onX then g.X else g.Z)) do
				local a, c = Vector3.new(seg.x0, 0, seg.z0), Vector3.new(seg.x1, 0, seg.z1)
				local length = (c - a).Magnitude + seg.grow
				if length >= 1 then
					local mid = floor.CFrame * ((a + c) / 2) + Vector3.new(0, H / 2 - .1, 0)
					local along = floor.CFrame:VectorToWorldSpace((c - a).Unit)
					local w = A.part(gateModel, "Wall", Vector3.new(1, H, length), CFrame.lookAt(mid, mid + along), barrier.Color, Enum.Material.Glass, true)
					w.Transparency, w.CanQuery, w.CastShadow = .5, false, false
				end
			end
		end
		local panel = mesh:FindFirstChild("Panel", true)
		if panel and panel:IsA("BasePart") then
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Sign"
			gui.Face = face(panel, facing)
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			gui.LightInfluence = 0
			gui.Parent = panel
			local function label(name: string, text: string, top: number, height: number, color: Color3)
				local l = Instance.new("TextLabel")
				l.Name, l.Text = name, text
				l.BackgroundTransparency = 1
				l.Size, l.Position = UDim2.fromScale(.92, height), UDim2.fromScale(.04, top)
				l.Font = Enum.Font.FredokaOne
				l.TextScaled, l.TextColor3 = true, color
				l.TextStrokeTransparency, l.TextStrokeColor3 = 0, T.ink
				l.Parent = gui
			end
			label("Title", field.Name:upper(), .06, .5, Color3.new(1, 1, 1))
			label("Rule", if field.Unlock then (if field.Unlock.Rebirths then "REBIRTH " .. field.Unlock.Rebirths else "LEVEL " .. field.Unlock.Level) else "OPEN", .58, .36, Color3.fromRGB(255, 213, 74))
		end
		task.wait()
	end
	local entrance = A.part(model, "Entrance", Vector3.new(4, 1, 4), CFrame.lookAt(entranceAt + Vector3.new(0, .5, 0), entranceAt + Vector3.new(0, .5, 0) - (firstFacing :: Vector3)), field.Color, nil, false)
	entrance.Transparency, entrance.CanQuery = 1, false

	-- chute
	local row = assert(f.chute, id .. " has no chute")
	local front = Vector3.new(-math.cos(math.rad(row.yaw)), 0, -math.sin(math.rad(row.yaw)))
	local chutePos = Vector3.new(row.x, y, row.z)
	local chuteModel = A.group(chutes, id)
	T.mesh(chuteModel, "OreChute", CFrame.lookAt(chutePos, chutePos + front), 11.6, function() error("ServerStorage.MapArt.OreChute is missing; run Props") end)
	local use = A.part(chuteModel, "UsePoint", Vector3.new(4, 1, 4), CFrame.new(chutePos + front * 9 + Vector3.new(0, 3, 0)), field.Color, nil, false)
	use.Transparency, use.CanQuery = 1, false

	table.insert(summary, ("%s rocks=%d blocks=%d"):format(id, #f.rocks, #f.blocks))
	task.wait()
end

return { stage = "Fields", rocks = #debris:GetChildren(), fields = summary }

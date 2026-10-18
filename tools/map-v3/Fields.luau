-- Map v3 ore fields. Load Common, Brick and Toon first, and pass the plan: L("../map-v3/Fields", L("../map-v3/PlanData")).
-- Owns Map_Redesign.Debris, DebrisFields, Gates and Chutes, all from PlanData rows with a `field`:
--   Debris: one rock per plan rock, cloned from an archived v2 rock (root Part + RockChunk/OreFleck children) of the
--     field's look, turned at random, standing on its tier, attribute Field = <id>.
--   DebrisFields.<Id>: FieldFloor (thin, invisible, non-colliding, the field's PrimaryPart) under all of its rocks plus
--     a margin, in the field's own frame; Entrance (the zone's entrance, facing the crater). The locked-field eject
--     treats the floor box as "inside", so each Entrance is asserted to lie outside it.
--   Gates.<Id>: the FieldGate mesh facing the crater, a Barrier (not on fields without an Unlock) and the Rule label.
--     The Crown fields have no plan gate; theirs stands 4 studs past their entrance, as on the other tiers.
--   Chutes.<Id>: the OreChute mesh facing the crater and its UsePoint 9 studs in front of its pivot.
local A = assert(_G.MapRedesignArt, "Run Common first")
local T = assert(A.toon, "Run Toon first")
local plan = assert(..., "Pass the plan: L(\"../map-v3/PlanData\")")
local G = A.geometry
local Config = A.config -- a fresh copy: a plain require in Edit can return a stale cached module
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

local byField: { [string]: { rocks: { any }, gate: any?, chute: any? } } = {}
for _, row in plan.footprints do
	if row.field then
		local f = byField[row.field] or { rocks = {} }
		byField[row.field] = f
		if row.kind == "rock" then table.insert(f.rocks, row) elseif row.kind == "gate" then f.gate = row elseif row.kind == "chute" then f.chute = row end
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
	local dMin, dMax, uMin, uMax = math.huge, -math.huge, math.huge, -math.huge
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
		local p = Vector3.new(row.x, 0, row.z)
		local d, u = p:Dot(out), p:Dot(across)
		local half = math.max(row.w, row.d) / 2
		dMin, dMax, uMin, uMax = math.min(dMin, d - half), math.max(dMax, d + half), math.min(uMin, u - half), math.max(uMax, u + half)
	end

	-- floor and entrance
	local model = A.group(fieldsGroup, id)
	local dMid, uMid = (dMin + dMax) / 2, (uMin + uMax) / 2
	local centre = out * dMid + across * uMid
	local floorCf = CFrame.lookAt(Vector3.new(centre.X, y + .1, centre.Z), Vector3.new(centre.X, y + .1, centre.Z) + out)
	local floor = A.part(model, "FieldFloor", Vector3.new(uMax - uMin + MARGIN * 2, .2, dMax - dMin + MARGIN * 2), floorCf, field.Color, nil, false)
	floor.Transparency, floor.CanQuery, floor.CastShadow = 1, false, false
	model.PrimaryPart = floor
	local e = zone.entrance
	local entrance = A.part(model, "Entrance", Vector3.new(4, 1, 4), CFrame.lookAt(Vector3.new(e.X, y + .5, e.Z), Vector3.new(e.X, y + .5, e.Z) - out), field.Color, nil, false)
	entrance.Transparency, entrance.CanQuery = 1, false
	local local_ = floor.CFrame:PointToObjectSpace(entrance.Position)
	assert(math.abs(local_.X) > floor.Size.X / 2 + 2 or math.abs(local_.Z) > floor.Size.Z / 2 + 2,
		id .. ": the Entrance is inside the field's eject box; a locked player would be put back forever")

	-- gate: the plan's, or for the Crown fields one in front of the first rocks
	local gatePos = if f.gate then Vector3.new(f.gate.x, y, f.gate.z) else Vector3.new(e.X, y, e.Z) + out * 4
	-- the eject puts a locked player on the Entrance, so it must stand clear of the (solid for them) barrier
	assert(math.abs((Vector3.new(e.X, y, e.Z) - gatePos):Dot(out)) >= 3, id .. ": the Entrance is inside the gate's barrier")
	local gateModel = A.group(gates, id)
	local mesh = T.mesh(gateModel, "FieldGate", CFrame.lookAt(gatePos, gatePos - out), 25.2, function() error("ServerStorage.MapArt.FieldGate is missing; run Props") end)
	if field.Unlock then
		local barrier = A.part(gateModel, "Barrier", Vector3.new(24, 16, 1), CFrame.lookAt(gatePos + Vector3.new(0, 8, 0), gatePos + Vector3.new(0, 8, 0) - out), Color3.fromRGB(111, 240, 224), Enum.Material.ForceField, true)
		barrier.Transparency, barrier.CanQuery = .35, false
	end
	local panel = mesh:FindFirstChild("Panel", true)
	if panel and panel:IsA("BasePart") then
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Sign"
		gui.Face = face(panel, -out)
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

	-- chute
	local row = assert(f.chute, id .. " has no chute")
	local front = Vector3.new(-math.cos(math.rad(row.yaw)), 0, -math.sin(math.rad(row.yaw)))
	local chutePos = Vector3.new(row.x, y, row.z)
	local chuteModel = A.group(chutes, id)
	T.mesh(chuteModel, "OreChute", CFrame.lookAt(chutePos, chutePos + front), 11.6, function() error("ServerStorage.MapArt.OreChute is missing; run Props") end)
	local use = A.part(chuteModel, "UsePoint", Vector3.new(4, 1, 4), CFrame.new(chutePos + front * 9 + Vector3.new(0, 3, 0)), field.Color, nil, false)
	use.Transparency, use.CanQuery = 1, false

	table.insert(summary, ("%s rocks=%d floor=%.0fx%.0f"):format(id, #f.rocks, floor.Size.X, floor.Size.Z))
	task.wait()
end

return { stage = "Fields", rocks = #debris:GetChildren(), fields = summary }

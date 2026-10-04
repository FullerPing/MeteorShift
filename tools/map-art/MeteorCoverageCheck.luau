-- Edit-time geometric QA. Run standalone; never save its temporary clones.
-- Samples the exposed dome, then opens the front by removing 22 crust roots.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
assert(not game:GetService("RunService"):IsRunning(), "Edit mode only")
local assets = game.ServerStorage.Assets
local sourceCore = assets.Meteor.Core
local templates = assets.NodePieces:GetChildren()
table.sort(templates, function(a, b) return a.Name < b.Name end)
assert(#templates == 4, "Expected four node templates")
local slots = {}
for _, p in sourceCore:GetChildren() do
	if p:IsA("Attachment") and p.Name == "NodeSlot" then table.insert(slots, p) end
end
assert(#slots == 36, "Coverage/balance baseline expects 36 slots")
local center = Vector3.new(0, 700, 0)
local temporary = Instance.new("Model")
temporary.Name = "TemporaryMeteorCoverageQA"
temporary.Parent = workspace
local report = {runs = {}, toleranceDegrees = .35, minimumNormalizedY = -.80, queryFidelity = "PreciseConvexDecomposition"}

-- The same offset-preserving operation as MeteorService.place.
local function place(part, cf)
	local offsets = {}
	for _, child in part:GetDescendants() do
		if child:IsA("BasePart") then offsets[child] = part.CFrame:ToObjectSpace(child.CFrame) end
	end
	part.CFrame = cf
	for child, offset in offsets do child.CFrame = cf * offset end
end
local function prepare(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	-- Box fidelity would report the rectangular bounds as a closed crust while
	-- the faceted render geometry still had gaps. Change only these QA clones.
	if part:IsA("UnionOperation") or part:IsA("MeshPart") then
		part.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	end
	for _, child in part:GetDescendants() do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false -- Include filters also include descendants.
		end
	end
end
local function vector(v) return {math.round(v.X * 10000) / 10000, math.round(v.Y * 10000) / 10000, math.round(v.Z * 10000) / 10000} end

local function run(label, seed, homogeneous)
	temporary:ClearAllChildren()
	local rng = Random.new(seed)
	local core = sourceCore:Clone()
	place(core, CFrame.new(center))
	prepare(core)
	core.Parent = temporary
	local roots, originDistance = {}, sourceCore.Size.Magnitude * 2 + 50
	for i, slot in slots do
		local source = homogeneous or templates[rng:NextInteger(1, #templates)]
		local p = source:Clone()
		prepare(p)
		place(p, core.CFrame * slot.CFrame * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		p.Name = "CrustNode" .. i
		p.Parent = temporary
		table.insert(roots, p)
		originDistance = math.max(originDistance, (p.Position-center).Magnitude + p.Size.Magnitude + 50)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = roots
	local function hit(dir)
		-- Stop at the center: the opposite crust must not conceal a near-side gap.
		return workspace:Raycast(center + dir * originDistance, -dir * originDistance, params)
	end
	local row = {name = label, seed = seed, samples = 0, rawGaps = 0, gaps = 0, examples = {}, maxFlatRadius = 0}
	local epsilon = math.tan(math.rad(report.toleranceDegrees))
	for iy = 0, 80 do
		local y = -.80 + 1.80 * iy / 80
		local radial = math.sqrt(math.max(0, 1-y*y))
		for ia = 0, 179 do
			local a = ia * math.pi * 2 / 180
			local dir = Vector3.new(math.cos(a) * radial, y, math.sin(a) * radial)
			row.samples += 1
			local surface = hit(dir)
			if surface then
				local delta = surface.Position-center
				row.maxFlatRadius=math.max(row.maxFlatRadius,Vector2.new(delta.X,delta.Z).Magnitude)
			else
				row.rawGaps += 1
				local tangent = dir:Cross(Vector3.yAxis)
				if tangent.Magnitude < .001 then tangent = Vector3.xAxis else tangent = tangent.Unit end
				local bitangent = dir:Cross(tangent).Unit
				local nearby = hit((dir+tangent*epsilon).Unit) or hit((dir-tangent*epsilon).Unit)
					or hit((dir+bitangent*epsilon).Unit) or hit((dir-bitangent*epsilon).Unit)
				if not nearby then
					row.gaps += 1
					if #row.examples < 5 then table.insert(row.examples, vector(dir)) end
				end
			end
		end
		if iy % 10 == 0 then task.wait() end
	end
	-- A deterministic favorable opening, preserving the actual 60% unlock count.
	table.sort(roots, function(a, b)
		return (a.Position-center).Unit:Dot(Vector3.zAxis) > (b.Position-center).Unit:Dot(Vector3.zAxis)
	end)
	for i = 1, math.ceil(#slots * .6) do
		roots[i].CanQuery = false
		roots[i].Transparency = 1
		for _, p in roots[i]:GetDescendants() do if p:IsA("BasePart") then p.Transparency = 1 end end
	end
	local targets = {core}
	for i = math.ceil(#slots * .6)+1, #roots do table.insert(targets, roots[i]) end
	params.FilterDescendantsInstances = targets
	row.coreAccess = {removed = math.ceil(#slots * .6), frontSamples = 0, frontVisible = 0, largestClearAngleFromFront = 0}
	for iy = 0, 20 do
		local y = -.25 + iy / 20
		local r = math.sqrt(1-y*y)
		for ia = -45, 45, 3 do
			local a = math.rad(ia)
			local dir = Vector3.new(math.sin(a)*r, y, math.cos(a)*r)
			local result = hit(dir)
			row.coreAccess.frontSamples += 1
			if result and result.Instance == core then
				row.coreAccess.frontVisible += 1
				row.coreAccess.largestClearAngleFromFront = math.max(row.coreAccess.largestClearAngleFromFront, math.deg(math.acos(dir.Z)))
			end
		end
	end
	local front = hit(Vector3.zAxis)
	row.coreAccess.directFrontVisible = front ~= nil and front.Instance == core
	row.coreAccess.directFrontBlocker = front and front.Instance.Name or "none"
	row.passed = row.gaps == 0 and row.coreAccess.directFrontVisible and row.coreAccess.frontVisible > 0
	table.insert(report.runs, row)
end

local ok, err = xpcall(function()
	for i, template in templates do run(template.Name, 60200+i, template) end
	for seed = 1, 6 do run("Mixed"..seed, 60300+seed, nil) end
end, debug.traceback)
temporary:Destroy()
report.ok = ok
report.error = not ok and tostring(err) or nil
report.allPassed = ok
for _, row in report.runs do if not row.passed then report.allPassed = false end end
-- Sampled collision/query coverage, not a proof of render-mesh watertightness.
return game:GetService("HttpService"):JSONEncode(report)

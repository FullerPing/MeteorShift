-- Runtime command only: evaluate in the Play datamodel, never save as a Script.
-- Installs _G.MapRedesignWalkingQA. No teleport, progression grant, or speed tuning.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
assert(RunService:IsStudio() and RunService:IsRunning(), "Studio Play required")
assert(workspace:GetAttribute("DevWorldMap") == "Map_Redesign", "Select DevWorldMap=Map_Redesign before Play")
local map = assert(workspace:FindFirstChild("Map_Redesign"), "Selected map missing")
assert(map:GetAttribute("MapRedesignOwned"), "Selected staged map is unowned")

local previous = _G.MapRedesignWalkingQA
if previous and type(previous.cancel) == "function" then
	previous.cancel("tool_reloaded")
end
local geometryModule = game:GetService("ReplicatedStorage").Shared.WorldGeometry:Clone()
local geometryOk, WorldGeometry = pcall(require, geometryModule)
geometryModule:Destroy()
assert(geometryOk, "Cannot load current WorldGeometry: " .. tostring(WorldGeometry))
local geometry = WorldGeometry.Settings

local api = {}
local current = nil
local runId = 0
local function vector(v)
	return { x = v.X, y = v.Y, z = v.Z }
end
local function horizontalDistance(a, b)
	local delta = a - b
	return Vector2.new(delta.X, delta.Z).Magnitude
end
local function active(run)
	return current == run and (run.phase == "computing" or run.phase == "walking")
end
local function targets()
	-- Retains StaticQA's 14 ground destinations. The owner retired five elevated targets.
	-- This tool never runs a spawn/target matrix.
	assert(not map.Crater:FindFirstChild("MiningAccess"), "Ground-only revision requires MiningAccess absent")
	local town = assert(map:FindFirstChild("TownSquare"), "TownSquare missing")
	local result = {
		Refinery = town.Refinery.UsePoint.Position,
		GearCounter = town.PickaxeShop.ShopPoint.Position,
		SellBars = town.TradingPost.SellPoint.Position,
		HatcheryEntrance = WorldGeometry.zone("Hatchery").entrance + geometry.StageOffset + Vector3.new(0, 3, 0),
		RebirthEntrance = town.RebirthMonument.RebirthPoint.Position,
		MuseumEntrance = town.IndexMuseum.IndexPoint.Position,
	}
	for _, field in map.DebrisFields:GetChildren() do
		local entrance = field:GetAttribute("Entrance")
		assert(typeof(entrance) == "Vector3", field.Name .. " Entrance attribute missing")
		result[field.Name .. "Entrance"] = entrance + geometry.StageOffset + Vector3.new(0, 3, 0)
	end
	for _, landing in map.Crater.AccessRamps:GetChildren() do
		if landing:IsA("BasePart") and landing.Name:find("FloorLanding") then
			result[landing.Name] = landing.Position + Vector3.new(0, landing.Size.Y / 2 + 3, 0)
		end
	end
	local count = 0
	for _ in result do count += 1 end
	assert(count == 14, "Fourteen original ground destinations required")
	return result
end
function api.targets()
	local result = {}
	for name, position in targets() do
		table.insert(result, { name = name, position = vector(position) })
	end
	table.sort(result, function(a, b) return a.name < b.name end)
	return result
end

local function observe(run)
	if not run.root.Parent or not run.humanoid.Parent then return end
	local position = run.root.Position
	run.observedDistance += (position - run.lastPosition).Magnitude
	run.lastPosition = position
	run.samples += 1
	run.lastHealth = run.humanoid.Health
	run.minimumHealth = math.min(run.minimumHealth, run.lastHealth)
end
local function finish(run, phase, reason, detail)
	if not active(run) then return end
	observe(run)
	run.phase, run.reason, run.detail = phase, reason, detail
	run.finishedAt = os.clock()
	run.endPosition = run.lastPosition
	if run.waypointStartedAt and run.records[run.waypointIndex] then
		local record = run.records[run.waypointIndex]
		if not record.reached then
			record.seconds = run.finishedAt - run.waypointStartedAt
			record.endPosition = vector(run.lastPosition)
			record.distanceOnStop = (run.lastPosition - run.waypoints[run.waypointIndex].Position).Magnitude
		end
	end
	if run.heartbeat then run.heartbeat:Disconnect() end
	if run.healthChanged then run.healthChanged:Disconnect() end
	if run.stateChanged then run.stateChanged:Disconnect() end
	if run.blocked then run.blocked:Disconnect() end
	-- Stop only the original character. Never move a replacement after respawn.
	if run.player.Character == run.character and run.root.Parent and run.humanoid.Parent then
		pcall(function()
			if run.moveIssued then run.humanoid:MoveTo(run.root.Position) end
			-- Jump is the only property written; the engine normally clears it itself.
			if run.jumpChanged and run.humanoid.Jump then run.humanoid.Jump = false end
		end)
	end
	if run.path then run.path:Destroy(); run.path = nil end
end

local function advance(run)
	if not active(run) then return end
	if workspace:GetAttribute("DevWorldMap") ~= "Map_Redesign" or map.Parent ~= workspace then
		finish(run, "failed", "selected_map_changed")
		return
	end
	if run.player.Parent ~= Players or run.player.Character ~= run.character
		or not run.character.Parent or not run.root.Parent or not run.humanoid.Parent then
		finish(run, "failed", "character_replaced_or_removed")
		return
	end
	observe(run)
	if run.lastHealth <= 0 then finish(run, "failed", "character_died"); return end
	if run.minimumHealth < run.startHealth - 0.01 then finish(run, "failed", "health_lost"); return end
	if run.root.Anchored then finish(run, "failed", "root_anchored"); return end
	local now = os.clock()
	if run.phase == "computing" then
		if now - run.startedAt >= run.options.computeTimeoutSeconds then
			finish(run, "failed", "compute_timeout")
		end
		return
	end
	if now - run.walkingStartedAt >= run.options.walkTimeoutSeconds then
		finish(run, "failed", "walk_timeout")
		return
	end
	local waypoint = run.waypoints[run.waypointIndex]
	if not waypoint then
		local distance = (run.lastPosition - run.targetPosition).Magnitude
		if distance <= run.options.finalTolerance then
			finish(run, "passed", "walked_to_target")
		else
			finish(run, "failed", "final_distance", tostring(distance))
		end
		return
	end
	if not run.waypointStartedAt then
		run.waypointStartedAt = now
		run.lastProgressAt = now
		run.bestDistance = (run.lastPosition - waypoint.Position).Magnitude
		local record = run.records[run.waypointIndex]
		record.startedAtSeconds = now - run.startedAt
		record.startPosition = vector(run.lastPosition)
		record.minimumDistance = run.bestDistance
		run.humanoid:MoveTo(waypoint.Position)
		run.moveIssued = true
		run.moveToCommands += 1
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			if not run.humanoid.Jump then run.jumpChanged = true end
			run.humanoid.Jump = true
			run.jumpActionsIssued += 1
			record.jumpIssued = true
		end
		return
	end
	local distance = (run.lastPosition - waypoint.Position).Magnitude
	local record = run.records[run.waypointIndex]
	record.minimumDistance = math.min(record.minimumDistance, distance)
	if distance <= run.bestDistance - 0.25 then
		run.bestDistance = distance
		run.lastProgressAt = now
	end
	-- Path waypoints are on the surface; HumanoidRootPart is above that surface.
	if horizontalDistance(run.lastPosition, waypoint.Position) <= run.options.waypointTolerance
		and math.abs(run.lastPosition.Y - waypoint.Position.Y) <= run.options.waypointVerticalTolerance then
		record.reached = true
		record.reachedAtSeconds = now - run.startedAt
		record.seconds = now - run.waypointStartedAt
		record.endPosition = vector(run.lastPosition)
		record.distanceOnArrival = distance
		run.waypointsReached += 1
		run.waypointIndex += 1
		run.waypointStartedAt = nil
		return
	end
	if now - run.waypointStartedAt >= run.options.waypointTimeoutSeconds then
		finish(run, "failed", "waypoint_timeout", tostring(run.waypointIndex))
	elseif now - run.lastProgressAt >= run.options.stuckSeconds then
		finish(run, "failed", "stuck", tostring(run.waypointIndex))
	end
end

function api.status(includeWaypoints)
	local run = current
	if not run then return { installed = true, phase = "idle", runtimeWalkingOnly = true } end
	local now = run.finishedAt or os.clock()
	local result = {
		version = 1, runId = run.id, runtimeWalkingOnly = true,
		phase = run.phase, finished = not active(run), reason = run.reason, detail = run.detail,
		playerName = run.player.Name, userId = run.player.UserId, startedUtc = run.startedUtc,
		targetName = run.targetName, startPosition = vector(run.startPosition),
		targetPosition = vector(run.targetPosition), actualPosition = vector(run.lastPosition),
		pathComputed = run.pathComputed, pathStatus = run.pathStatus,
		walkedSuccess = run.phase == "passed", elapsedSeconds = now - run.startedAt,
		computeSeconds = run.computeSeconds or (math.min(now, run.walkingStartedAt or now) - run.startedAt),
		walkingSeconds = if run.walkingStartedAt then now - run.walkingStartedAt else 0,
		waypointIndex = run.waypointIndex, waypointsTotal = #run.waypoints,
		waypointsReached = run.waypointsReached, moveToCommands = run.moveToCommands,
		jumpWaypoints = run.jumpWaypoints, jumpActionsIssued = run.jumpActionsIssued,
		actualJumpsObserved = run.actualJumpsObserved, blockedWaypointIndices = table.clone(run.blockedIndices),
		startHealth = run.startHealth, actualHealth = run.lastHealth, minimumHealth = run.minimumHealth,
		observedTravelStuds = run.observedDistance, positionSamples = run.samples,
		finalDistance = (run.lastPosition - run.targetPosition).Magnitude,
		finalHorizontalDistance = horizontalDistance(run.lastPosition, run.targetPosition),
		finalVerticalDifference = math.abs(run.lastPosition.Y - run.targetPosition.Y),
		limits = table.clone(run.options), humanoidTuningChanged = false,
	}
	if includeWaypoints then
		result.waypoints = {}
		for _, record in run.records do table.insert(result.waypoints, table.clone(record)) end
	end
	return result
end
function api.cancel(reason)
	if current and active(current) then finish(current, "cancelled", reason or "operator_cancelled") end
	return api.status(true)
end
function api.start(playerName, targetName, options)
	assert(not current or not active(current), "A route is active; cancel it before starting another")
	assert(RunService:IsStudio() and RunService:IsRunning(), "Studio Play required")
	assert(workspace:GetAttribute("DevWorldMap") == "Map_Redesign" and map.Parent == workspace, "Selected map changed")
	assert(type(playerName) == "string" and #playerName > 0, "Provide the exact player Name")
	local player = assert(Players:FindFirstChild(playerName), "Named player missing")
	assert(player:IsA("Player"), "Named instance is not a Player")
	assert(not RunService:IsClient() or player == Players.LocalPlayer, "Client must control its local player")
	local character = assert(player.Character, "Named player has no character")
	local humanoid = assert(character:FindFirstChildOfClass("Humanoid"), "Humanoid missing")
	local root = assert(character:FindFirstChild("HumanoidRootPart"), "HumanoidRootPart missing")
	assert(root:IsA("BasePart") and not root.Anchored and humanoid.Health > 0, "Live unanchored character required")
	assert(humanoid.WalkSpeed > 0, "Character cannot walk at its actual WalkSpeed")
	local target = assert(targets()[targetName], "Unknown target; call targets() for names")
	local limits = {
		computeTimeoutSeconds = 20, walkTimeoutSeconds = 180, waypointTimeoutSeconds = 10,
		stuckSeconds = 4, waypointTolerance = 2.5, waypointVerticalTolerance = 6, finalTolerance = 4,
	}
	for key, value in options or {} do
		assert(limits[key] ~= nil, "Unknown option: " .. tostring(key))
		assert(type(value) == "number" and value == value and value > 0 and value < math.huge, "Positive finite option required")
		limits[key] = value
	end
	assert(limits.computeTimeoutSeconds <= 30 and limits.walkTimeoutSeconds <= 300
		and limits.waypointTimeoutSeconds <= 30 and limits.stuckSeconds <= 15, "Timeouts exceed QA bounds")
	assert(limits.waypointTolerance <= 3 and limits.waypointVerticalTolerance <= 7
		and limits.finalTolerance <= 5, "Arrival tolerances exceed QA bounds")
	runId += 1
	local run = {
		id = runId, phase = "computing", player = player, character = character, humanoid = humanoid, root = root,
		targetName = targetName, targetPosition = target, startPosition = root.Position, lastPosition = root.Position,
		startedAt = os.clock(), startedUtc = DateTime.now():ToIsoDate(), options = limits,
		startHealth = humanoid.Health, lastHealth = humanoid.Health, minimumHealth = humanoid.Health,
		observedDistance = 0, samples = 0, pathComputed = false, pathStatus = "pending",
		waypoints = {}, records = {}, waypointIndex = 1, waypointsReached = 0,
		moveToCommands = 0, jumpWaypoints = 0, jumpActionsIssued = 0, actualJumpsObserved = 0, blockedIndices = {},
	}
	current = run
	run.healthChanged = humanoid.HealthChanged:Connect(function(health)
		run.minimumHealth = math.min(run.minimumHealth, health)
	end)
	run.stateChanged = humanoid.StateChanged:Connect(function(_, state)
		if active(run) and state == Enum.HumanoidStateType.Jumping then run.actualJumpsObserved += 1 end
	end)
	run.heartbeat = RunService.Heartbeat:Connect(function()
		local ok, err = pcall(advance, run)
		if not ok then finish(run, "failed", "runtime_error", tostring(err)) end
	end)
	-- ComputeAsync yields, so keep the command bounded while the heartbeat watchdog runs.
	task.spawn(function()
		local ok, err = pcall(function()
			local path = PathfindingService:CreatePath({ AgentRadius = 3, AgentHeight = 6, AgentCanJump = true, WaypointSpacing = 8 })
			run.path = path
			path:ComputeAsync(run.startPosition, run.targetPosition)
			if not active(run) then return end
			run.computeSeconds = os.clock() - run.startedAt
			run.pathStatus = path.Status.Name
			if path.Status ~= Enum.PathStatus.Success then finish(run, "failed", "path_not_computed"); return end
			run.pathComputed = true
			run.waypoints = path:GetWaypoints()
			if #run.waypoints == 0 or #run.waypoints > 512 then finish(run, "failed", "invalid_waypoint_count"); return end
			for index, waypoint in run.waypoints do
				if waypoint.Action == Enum.PathWaypointAction.Jump then run.jumpWaypoints += 1 end
				table.insert(run.records, { index = index, position = vector(waypoint.Position), action = waypoint.Action.Name, reached = false, jumpIssued = false })
			end
			run.blocked = path.Blocked:Connect(function(index)
				if active(run) and index >= run.waypointIndex then table.insert(run.blockedIndices, index) end
			end)
			run.walkingStartedAt = os.clock()
			run.phase = "walking"
		end)
		if not ok then finish(run, "failed", "compute_error", tostring(err)) end
	end)
	return api.status()
end
function api.step(maxSeconds, includeWaypoints)
	local seconds = if maxSeconds == nil then 5 else maxSeconds
	assert(type(seconds) == "number" and seconds == seconds and seconds >= 0 and seconds <= 10, "step seconds must be 0..10")
	local run = current
	local deadline = os.clock() + seconds
	while run and active(run) and os.clock() < deadline do RunService.Heartbeat:Wait() end
	return api.status(includeWaypoints)
end

_G.MapRedesignWalkingQA = api
return { installed = true, version = 1, runtimeWalkingOnly = true, targets = api.targets(), next = "start(exactPlayerName, targetName); step(5); status(true); cancel()" }

--!strict
-- All followers are local anchored clones. The server only replicates loadout and work events.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Visuals = require(ReplicatedStorage.Shared.PetVisuals)
local PetModel = require(script.Parent.Parent.PetModel)

local player = Players.LocalPlayer
local PetVisualController = Knit.CreateController({ Name = "PetVisualController" })

type Follower = {
	visual: PetModel.Visual, entry: Visuals.Entry, owner: Player,
	cframe: CFrame, workingUntil: number, arrivedAt: number, floorY: number, arrivalBurst: boolean,
	workStartedAt: number, target: Vector3?, hopper: Vector3?, lastStepAt: number, sounds: { [string]: Sound }, capacityFraction: number,
}
type Owner = { player: Player, entries: { Visuals.Entry }, connections: { RBXScriptConnection } }
local owners: { [number]: Owner } = {}
local followers: { [string]: Follower } = {}
local folder = Instance.new("Folder")
folder.Name = "LocalPetVisuals"
local reduced = false
local hatchReserved = false
local shopReserved = 0
local ownCapacityFraction = 0
local selectionClock = 0
local OFFSETS = { Vector3.new(-2.5, 0, 3.2), Vector3.new(2.5, 0, 3.2), Vector3.new(-1.7, 1.8, 0.8), Vector3.new(1.7, 1.8, 0.8) }

local function key(userId: number, slot: number): string
	return tostring(userId) .. ":" .. tostring(slot)
end

local function rootOf(owner: Player): BasePart?
	local character = owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then root else nil
end

local function pointOf(item: Instance?): Vector3?
	if not item then return nil end
	if item:IsA("BasePart") then return item.Position end
	if item:IsA("Model") then return item:GetPivot().Position end
	if item:IsA("Attachment") then return item.WorldPosition end
	return nil
end

local function hopperOf(owner: Player): Vector3?
	local map = workspace:FindFirstChild("Map")
	local town = map and map:FindFirstChild("TownSquare")
	local shared = town and town:FindFirstChild("Refinery")
	if shared then return pointOf(shared:FindFirstChild("Intake", true) or shared:FindFirstChild("Hopper", true) or shared:FindFirstChild("UsePoint", true)) end
	local plots = map and map:FindFirstChild("Plots")
	if plots then
		for _, plot in plots:GetChildren() do
			if plot:GetAttribute("OwnerUserId") == owner.UserId then
				local stations = plot:FindFirstChild("Stations")
				local hopper = stations and stations:FindFirstChild("Hopper")
				return pointOf(hopper and hopper:FindFirstChild("Intake", true)) or pointOf(hopper)
			end
		end
	end
	return nil
end

local function petSound(follower: Follower, name: string, id: string, volume: number, pitch: number, looped: boolean?)
	if reduced then return end
	local sound = follower.sounds[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name, sound.SoundId, sound.Volume, sound.PlaybackSpeed = name, id, volume, pitch
		sound.RollOffMinDistance, sound.RollOffMaxDistance = 3, 16
		sound.Looped = looped == true
		sound.Parent = follower.visual.model.PrimaryPart
		follower.sounds[name] = sound
	end
	if not sound.IsPlaying then sound:Play() end
end

local function removeOwner(userId: number)
	local owner = owners[userId]
	if owner then
		for _, connection in owner.connections do connection:Disconnect() end
		owners[userId] = nil
	end
	for id, follower in followers do
		if follower.owner.UserId == userId then follower.visual.model:Destroy() followers[id] = nil end
	end
end

local function read(owner: Owner)
	local ids, levels, slots = owner.player:GetAttribute("Pets"), owner.player:GetAttribute("PetLevels"), owner.player:GetAttribute("PetSlots")
	owner.entries = Visuals.loadout(
		if typeof(ids) == "string" then ids else nil,
		if typeof(levels) == "string" then levels else nil,
		if typeof(slots) == "number" then slots else nil
	)
	selectionClock = 0.2
end

local function watch(ownerPlayer: Player)
	if owners[ownerPlayer.UserId] then return end
	local owner: Owner = { player = ownerPlayer, entries = {}, connections = {} }
	owners[ownerPlayer.UserId] = owner
	for _, attribute in { "Pets", "PetLevels", "PetSlots" } do
		table.insert(owner.connections, ownerPlayer:GetAttributeChangedSignal(attribute):Connect(function() read(owner) end))
	end
	table.insert(owner.connections, ownerPlayer.CharacterRemoving:Connect(function()
		for id, follower in followers do
			if follower.owner == ownerPlayer then follower.visual.model:Destroy() followers[id] = nil end
		end
	end))
	read(owner)
end

local function selectFollowers()
	local camera = workspace.CurrentCamera
	if not camera then
		-- Reservations must still release clones during camera replacement.
		for id, follower in followers do follower.visual.model:Destroy() followers[id] = nil end
		return
	end
	folder.Parent = workspace
	local ownRoot = rootOf(player)
	local center = if ownRoot then ownRoot.Position else camera.CFrame.Position
	local candidates: { Visuals.Candidate } = {}
	local available: { [number]: { Visuals.Entry } } = {}
	for userId, owner in owners do
		local root = rootOf(owner.player)
		if root then
			local entries = {}
			for _, entry in owner.entries do
				if PetModel.source(entry.id) then table.insert(entries, entry) end
			end
			available[userId] = entries
			table.insert(candidates, { userId = userId, distance = (root.Position - center).Magnitude, count = #entries })
		end
	end
	local desired: { [string]: boolean } = {}
	local budget = Visuals.Budget - shopReserved - (if hatchReserved then 1 else 0)
	local picked = Visuals.select(candidates, player.UserId, budget)
	-- Remove before creating, including when an upgraded look replaces the old clone.
	for _, pick in picked do
		local entry = available[pick.userId][pick.slot]
		local id = key(pick.userId, entry.slot)
		desired[id] = true
		local existing = followers[id]
		if existing and (existing.entry.id ~= entry.id or existing.entry.level ~= entry.level) then
			existing.visual.model:Destroy()
			followers[id] = nil
		end
	end
	for id, follower in followers do
		if not desired[id] then follower.visual.model:Destroy() followers[id] = nil end
	end
	for _, pick in picked do
		local owner = owners[pick.userId]
		local entry = available[pick.userId][pick.slot]
		local id = key(pick.userId, entry.slot)
		if not followers[id] then
			local root = rootOf(owner.player)
			local visual = PetModel.clone(entry.id, entry.level)
			if root and visual then
				local cf = root.CFrame * CFrame.new(OFFSETS[entry.slot])
				visual.model:PivotTo(cf)
				PetModel.reduce(visual, reduced)
				visual.model.Name = tostring(pick.userId) .. "_" .. entry.id
				visual.model.Parent = folder
				followers[id] = {
					visual = visual, owner = owner.player, entry = entry, cframe = cf, workingUntil = 0, arrivedAt = os.clock(), floorY = root.Position.Y - 3, arrivalBurst = false,
					workStartedAt = 0, target = nil, hopper = nil, lastStepAt = 0, sounds = {}, capacityFraction = 0,
				}
			end
		end
	end
	for _, follower in followers do
		local root = rootOf(follower.owner)
		local fraction = follower.owner:GetAttribute("PetBackpackFraction")
		follower.capacityFraction = if typeof(fraction) == "number" then fraction elseif follower.owner == player then ownCapacityFraction else 0
		if root and (follower.entry.slot <= 2 or follower.entry.id == "coinMagpie" or follower.visual.style == "dive") then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			local characters: { Instance } = { folder }
			for _, owner in owners do if owner.player.Character then table.insert(characters, owner.player.Character :: Model) end end
			params.FilterDescendantsInstances = characters
			local position = (root.CFrame * CFrame.new(OFFSETS[follower.entry.slot])).Position
			local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
			follower.floorY = if hit then hit.Position.Y else root.Position.Y - 3
		end
	end
end

-- The overlay reserves synchronously before creating its preview, including reduced effects.
function PetVisualController:ReserveHatchPreview(reserved: boolean)
	hatchReserved = reserved
	selectFollowers()
end

-- Reserve before cloning Shop pets; destroy those previews before releasing.
function PetVisualController:ReserveShopPreviews(count: number)
	shopReserved = if count == count then math.clamp(math.floor(count), 0, 14) else 0
	selectFollowers()
end

local function animate(follower: Follower, root: BasePart, dt: number, now: number)
	local visual, slot = follower.visual, follower.entry.slot
	if not follower.arrivalBurst then
		follower.arrivalBurst = true
		local rarity = visual.model:GetAttribute("Rarity")
		if not reduced and (rarity == "legendary" or rarity == "premium") then PetModel.burst(visual) end
	end
	local moving = root.AssemblyLinearVelocity.Magnitude > 1
	local groundMagpie = follower.entry.id == "coinMagpie" and not moving
	local flying = visual.flying and not groundMagpie
	local phase = now * (if visual.flying then 2 else 10) + slot * 1.8
	local work = if not reduced and now < follower.workingUntil then math.sin((follower.workingUntil - now) / 0.7 * math.pi) else 0
	local progress = math.clamp((now - follower.workStartedAt) / 0.7, 0, 1)
	local position = (root.CFrame * CFrame.new(OFFSETS[slot])).Position
	if (not flying and slot <= 2) or groundMagpie then position = Vector3.new(position.X, follower.floorY + visual.groundOffset, position.Z) end
	local bob = if reduced then 0 elseif flying then math.sin(phase) * 0.16 elseif groundMagpie then math.max(0, math.sin(now * 3)) * 0.18 elseif moving then math.abs(math.sin(phase)) * (if follower.entry.id == "sparkHare" then 0.22 else 0.12) else 0
	position += Vector3.new(0, bob, 0)
	if visual.style == "dive" then
		local target = follower.target or (position + root.CFrame.LookVector * 2 - Vector3.new(0, 0.8, 0))
		position = position:Lerp(target, work)
	elseif visual.style == "haul" then
		position -= Vector3.new(0, work * (if follower.entry.id == "lodeWyrm" then visual.height + 0.5 else 0.35), 0)
	end
	if follower.entry.id == "graniteGolem" and moving and not reduced and follower.owner == player and now - follower.lastStepAt >= 0.55 then
		follower.lastStepAt = now
		petSound(follower, "HeavyStep", Config.Sounds.HitA.Id, 0.055, 0.55)
	end
	if visual.style == "drill" and follower.owner == player then
		petSound(follower, "RotorHum", "rbxasset://sounds/Rocket whoosh 01.wav", 0.035, 0.45, true)
		if now - follower.arrivedAt < 0.45 then petSound(follower, "AssemblyClick", Config.Sounds.Click.Id, 0.045, 1.4) end
	end
	local desired = CFrame.lookAt(position, position + root.CFrame.LookVector)
	follower.cframe = if (follower.cframe.Position - position).Magnitude > 25 then desired else follower.cframe:Lerp(desired, 1 - math.exp(-dt * 10))
	local cf = follower.cframe
	visual.model:PivotTo(cf)
	if visual.style == "flash" then
		for _, effect in visual.effects do
			if effect.brightness then effect.instance.Brightness = effect.brightness * (1 + work * 2) end
		end
	end
	for _, piece in visual.pieces do
		local rotation = CFrame.identity
		if not reduced then
			local group = piece.group
			if group == "Drill" then rotation = CFrame.Angles(0, 0, now * (12 + work * 35))
			elseif group == "Halo" then rotation = CFrame.Angles(0, now * 0.6, 0)
			elseif group == "WingsLeft" or group == "WingsRight" then
				rotation = CFrame.Angles(0, 0, (if group == "WingsLeft" then 1 else -1) * (math.sin(phase * 2) * 0.18 + work * 0.35))
			elseif group == "FrontLeg" then rotation = CFrame.Angles((if moving then math.sin(phase) * 0.3 else 0) - work * 0.65, 0, 0)
			elseif group == "BackLeg" then rotation = CFrame.Angles(if moving then -math.sin(phase) * 0.3 else 0, 0, 0)
			elseif group == "Head" then rotation = CFrame.Angles(work * (if visual.style == "chirp" then 0.3 else -0.35), 0, 0)
			elseif group == "Ears" then rotation = CFrame.Angles(0, 0, math.sin(phase * 1.4) * 0.1 + work * 0.4)
			elseif group == "Tail" then rotation = CFrame.Angles(if follower.entry.id == "meteorDrake" then -work * 0.8 else 0, math.sin(phase) * 0.16 + work * 0.45, 0)
			end
		end
		piece.part.CFrame = cf * CFrame.new(piece.pivot) * rotation * CFrame.new(-piece.pivot) * piece.rest
		if piece.group == "OreChunk" then
			local from = (cf * piece.rest).Position
			local to = follower.hopper or from + root.CFrame.LookVector * 3
			if (to - from).Magnitude > 120 then to = from + (to - from).Unit * 120 end
			piece.part.CFrame = CFrame.new(from:Lerp(to, if work > 0 then progress else 0) + Vector3.new(0, work * 2.2, 0))
		elseif piece.group == "WorkingRing" then
			piece.part.Transparency = if work > 0 and not reduced then 1 - work * 0.85 else 1
		elseif piece.group == "GreyChip" or piece.group == "TargetShard" then
			local index = piece.part:GetAttribute("WorkIndex") or 1
			local base = if piece.group == "TargetShard" then follower.target or (cf * CFrame.new(0, 0, -1.5)).Position else (cf * piece.rest).Position
			piece.part.CFrame = CFrame.new(base + Vector3.new(math.cos(index * 1.7) * progress, work * (0.5 + index * 0.12), math.sin(index * 1.7) * progress)) * CFrame.Angles(progress * 2, index, 0)
			piece.part.Transparency = if work > 0 and not reduced then 1 - work else 1
		elseif piece.group == "CoinGlint" then
			piece.part.Transparency = if work > 0 and not reduced then 1 - work else 1
		elseif piece.group == "TunnelLight" or piece.group == "TunnelOre" then
			local from = cf.Position + Vector3.new(0, work * visual.height, 0)
			local to = follower.hopper or from + root.CFrame.LookVector * 3
			local length = (to - from).Magnitude
			if length > 120 then to = from + (to - from).Unit * 120 length = 120 end
			if piece.group == "TunnelLight" and length > 0.05 then
				piece.part.Size = Vector3.new(0.035, 0.035, length)
				piece.part.CFrame = CFrame.lookAt((from + to) / 2, to)
			else
				local index = piece.part:GetAttribute("WorkIndex") or 1
				piece.part.CFrame = CFrame.new(from:Lerp(to, (progress + index * 0.14) % 1))
			end
			piece.part.Transparency = if work > 0 and not reduced then 1 - work * 0.55 else 1
		elseif piece.group == "FlameBreath" then
			local index = piece.part:GetAttribute("WorkIndex") or 1
			local from = (cf * CFrame.new(0, 0.5, -1.65)).Position
			local to = follower.target or from + root.CFrame.LookVector * 2
			local direction = to - from
			if direction.Magnitude > 6 then to = from + direction.Unit * 6 end
			local center = from:Lerp(to, index / 5)
			if (to - from).Magnitude > 0.05 then piece.part.CFrame = CFrame.lookAt(center, to) end
			piece.part.Transparency = if work > 0 and not reduced then 1 - work * 0.7 else 1
		elseif piece.group == "ArrivalStreak" then
			local arrival = math.clamp(1 - (now - follower.arrivedAt) / 0.5, 0, 1)
			piece.part.CFrame = cf * CFrame.new(0, arrival * 2, 0) * piece.rest
			piece.part.Transparency = if not reduced then 1 - arrival else 1
		elseif piece.group == "HeatWave" then
			local index = piece.part:GetAttribute("WorkIndex") or 1
			piece.part.CFrame = cf * CFrame.new(math.sin(now * 12 + index) * 0.06, progress * 0.3, 0) * piece.rest
			piece.part.Transparency = if work > 0 and not reduced then 1 - work * 0.15 else 1
		elseif piece.group == "ScorchGlow" then
			local target = follower.target or cf.Position
			piece.part.CFrame = CFrame.new(target.X, follower.floorY + 0.03, target.Z) * CFrame.Angles(0, 0, math.pi / 2)
			piece.part.Transparency = if work > 0.65 and not reduced then 0.8 else 1
		elseif piece.group == "SparkLink" then
			piece.part.Transparency = 1
			local tool = follower.owner.Character and follower.owner.Character:FindFirstChildOfClass("Tool")
			local handle = tool and tool:FindFirstChild("Handle")
			if work > 0 and not reduced and handle and handle:IsA("BasePart") then
				local from, to = piece.part.Position, handle.Position
				local length = (to - from).Magnitude
				if length > 0.05 and length < 6 then
					piece.part.Size = Vector3.new(0.035, 0.035, length)
					piece.part.CFrame = CFrame.lookAt((from + to) / 2, to)
					piece.part.Transparency = 1 - work * 0.8
				end
			end
		end
		if piece.part:GetAttribute("CapacityGlow") == true then
			piece.part.Transparency = if not reduced and (work > 0 or follower.capacityFraction >= 0.8) then 0 else 0.85
		end
		if piece.part:GetAttribute("Aurora") == true and not reduced then
			piece.part.Color = piece.color:Lerp(Color3.fromRGB(120, 255, 210), math.clamp((math.sin(now * 1.2 + piece.rest.Position.X) + 1) * 0.35 + work * math.sin(piece.rest.Position.X * 5 + progress * 12) * 0.3, 0, 1))
		end
		if visual.style == "drill" and not reduced then
			local assemble = math.clamp(1 - (now - follower.arrivedAt) / 0.45, 0, 1)
			if assemble > 0 then piece.part.CFrame *= CFrame.new(piece.rest.Position * assemble * 0.4) end
		end
	end
end

function PetVisualController:KnitStart()
	local PetService = Knit.GetService("PetService")
	Knit.GetService("PlayerStateService").State:Observe(function(state: any)
		ownCapacityFraction = if state and state.capacity > 0 then state.carried / state.capacity else 0
	end)
	reduced = player:GetAttribute("ReduceEffects") == true
	for _, owner in Players:GetPlayers() do watch(owner) end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(owner) removeOwner(owner.UserId) end)
	player:GetAttributeChangedSignal("ReduceEffects"):Connect(function()
		reduced = player:GetAttribute("ReduceEffects") == true
		for _, follower in followers do
			PetModel.reduce(follower.visual, reduced)
			if reduced then for _, sound in follower.sounds do sound:Stop() end end
		end
	end)
	player:GetAttributeChangedSignal("HatchVisible"):Connect(function() selectionClock = 0.2 end)
	PetService.Working:Connect(function(userId: number, role: string, target: Vector3?)
		for _, follower in followers do
			if follower.owner.UserId == userId then
				local def = Pets.def(follower.entry.id)
				if def then
					for _, perk in def.Perks do
						if perk.Role == role then
							follower.workStartedAt = os.clock()
							follower.workingUntil = follower.workStartedAt + 0.7
							follower.target = if typeof(target) == "Vector3" then target else nil
							follower.hopper = if role == "hauler" then hopperOf(follower.owner) else nil
							if not reduced then PetModel.burst(follower.visual) end
							break
						end
					end
				end
			end
		end
	end)
	-- Sparrow's sell chirp is cosmetic even though its new gameplay perk is Scholar.
	Knit.GetService("EconomyService").Sold:Connect(function()
		for _, follower in followers do
			if follower.owner == player and follower.entry.id == "scrapSparrow" then
				follower.workStartedAt, follower.workingUntil = os.clock(), os.clock() + 0.7
				petSound(follower, "MetalTing", "rbxasset://sounds/electronicpingshort.wav", 0.1, 1.6)
			end
		end
	end)
	RunService.RenderStepped:Connect(function(dt: number)
		selectionClock += dt
		if selectionClock >= 0.2 then selectionClock = 0 selectFollowers() end
		local now = os.clock()
		for id, follower in followers do
			local root = rootOf(follower.owner)
			if root then animate(follower, root, dt, now)
			else follower.visual.model:Destroy() followers[id] = nil end
		end
	end)
end

return PetVisualController

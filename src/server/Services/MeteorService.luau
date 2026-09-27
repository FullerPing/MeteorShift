--!strict
-- Meteor schedule and server-authoritative state machine (spec §5.1 - §5.3).
--
-- Countdown -> Impact -> Active -> CoreCracked | Cooled -> Cleanup -> Countdown ...
--
-- The meteor is assembled at impact from reusable pieces saved in the place:
-- ServerStorage.Assets.Meteor.Core carries NodeSlot attachments, and each slot gets
-- a clone of one of the ServerStorage.Assets.NodePieces rocks, recoloured per type.
-- The map itself (crater, town, debris, plots) is saved in Workspace.Map.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Phase = require(ReplicatedStorage.Shared.Phase)

local MeteorConfig = Config.Meteor

local MeteorService = Knit.CreateService({
	Name = "MeteorService",
	Client = {
		-- { phase, endsAt, type, typeName, eventId, crustTotal, crustBroken, unlocked }
		-- endsAt is in workspace:GetServerTimeNow() time.
		State = Knit.CreateProperty(nil),
		Impact = Knit.CreateSignal(), -- (position: Vector3)
		CoreCracked = Knit.CreateSignal(), -- (position: Vector3)
	},
})

local NodeService
local ContributionService
local RewardService

type Meteor = {
	Model: Model,
	Core: BasePart,
	CoreId: number,
	CrustIds: { number },
	CrustTotal: number,
	CrustBroken: number,
	UnlockAt: number,
	Unlocked: boolean,
	Cracked: boolean,
	Type: Config.MeteorType,
}

local state = {
	phase = Phase.Countdown,
	endsAt = 0,
	type = "Iron",
	typeName = "Iron Meteor",
	eventId = 0,
	crustTotal = 0,
	crustBroken = 0,
	unlocked = false,
}
local current: Meteor? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

function MeteorService:_publish(patch: { [string]: any })
	for key, value in patch do
		(state :: any)[key] = value
	end
	self.Client.State:Set(table.clone(state))
end

function MeteorService:GetPhase(): Phase.Phase
	return state.phase
end

-- Sets the remaining countdown (used by Call a Meteor and private servers later).
function MeteorService:SetCountdownRemaining(seconds: number)
	if state.phase == Phase.Countdown then
		self:_publish({ endsAt = now() + seconds })
	end
end

local function countdownLength(first: boolean): number
	if RunService:IsStudio() and MeteorConfig.StudioCountdown then
		return MeteorConfig.StudioCountdown
	end
	return if first then MeteorConfig.FirstCountdown else MeteorConfig.Countdown
end

local function pickType(): Config.MeteorType
	local total = 0
	for _, meteorType in MeteorConfig.Types do
		total += meteorType.Weight
	end
	local roll = math.random() * total
	for _, meteorType in MeteorConfig.Types do
		roll -= meteorType.Weight
		if roll <= 0 then
			return meteorType
		end
	end
	return MeteorConfig.Types.Iron
end

-- Sum of every online player's pickaxe DPS (spec §5.3)
local function serverDps(): number
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local dps = 0
	for _, player in Players:GetPlayers() do
		local pickaxe = PlayerStateService:GetPickaxe(player)
		dps += pickaxe.Damage / pickaxe.Swing
	end
	return math.max(dps, MeteorConfig.MinServerDps)
end

local function waitUntil(predicate: () -> boolean)
	while not predicate() do
		task.wait(0.1)
	end
end

function MeteorService:_breakPart(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	for _, child in part:GetDescendants() do
		if child:IsA("Light") or child:IsA("ParticleEmitter") then
			child.Enabled = false
		elseif child:IsA("BasePart") then
			child.Transparency = 1
		end
	end
	task.delay(1, function()
		part:Destroy()
	end)
end

function MeteorService:_unlockCore(meteor: Meteor)
	meteor.Unlocked = true
	local core = meteor.Core
	core.Material = Enum.Material.Neon
	core.Color = meteor.Type.CoreColor
	core:SetAttribute("Unlocked", true)
	local light = core:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = true
	end
	self:_publish({ unlocked = true })
	RewardService:Announce("CoreUnlocked", "The core is exposed! Hit it before it cools!")
end

function MeteorService:_spawnMeteor(meteorType: Config.MeteorType): Meteor
	local assets = ServerStorage:WaitForChild("Assets")
	local spawnPoint = workspace:WaitForChild("Map"):WaitForChild("Crater"):WaitForChild("MeteorSpawn") :: BasePart
	local pieces = assets:WaitForChild("NodePieces"):GetChildren()

	local model = Instance.new("Model")
	model.Name = meteorType.Id .. "Meteor"

	local core = (assets:WaitForChild("Meteor"):WaitForChild("Core") :: BasePart):Clone()
	core.CFrame = spawnPoint.CFrame
	core.Anchored = true
	core.Material = Enum.Material.Slate
	core.Color = meteorType.CoreColor:Lerp(Color3.new(0, 0, 0), 0.55)
	core.Parent = model
	model.PrimaryPart = core

	local dps = serverDps()
	local slots = {}
	for _, child in core:GetChildren() do
		if child:IsA("Attachment") and child.Name == "NodeSlot" then
			table.insert(slots, child)
		end
	end

	local meteor: Meteor = {
		Model = model,
		Core = core,
		CoreId = 0,
		CrustIds = {},
		CrustTotal = #slots,
		CrustBroken = 0,
		UnlockAt = math.ceil(#slots * MeteorConfig.CoreUnlockFraction),
		Unlocked = false,
		Cracked = false,
		Type = meteorType,
	}

	local crustHp = math.ceil(dps * MeteorConfig.CrustSeconds / math.max(#slots, 1))
	local coreHp = math.ceil(dps * MeteorConfig.CoreSeconds)

	local function isActive(): boolean
		return state.phase == Phase.Active and current == meteor
	end

	local crustFolder = Instance.new("Folder")
	crustFolder.Name = "Crust"
	crustFolder.Parent = model

	for index, slot in slots do
		local piece = (pieces[math.random(1, #pieces)] :: BasePart):Clone()
		piece.Name = "CrustNode" .. index
		piece.Anchored = true
		-- Decorations (ore glints) are anchored children; carry them along with the piece
		local offsets = {}
		for _, child in piece:GetDescendants() do
			if child:IsA("BasePart") then
				offsets[child] = piece.CFrame:ToObjectSpace(child.CFrame)
			end
		end
		piece.CFrame = slot.WorldCFrame * CFrame.Angles(0, math.random() * math.pi * 2, 0)
		for child, offset in offsets do
			child.CFrame = piece.CFrame * offset
		end
		piece.Color = meteorType.CrustColors[math.random(1, #meteorType.CrustColors)]
		piece.Material = meteorType.CrustMaterial
		piece.Parent = crustFolder

		local id = NodeService:Register(piece, {
			Kind = "Crust",
			MaxHp = crustHp,
			Ore = meteorType.Ore,
			OreMult = meteorType.YieldMult,
			CanHit = function()
				return isActive()
			end,
			OnHit = function(player, damage, ore)
				ContributionService:AddCrust(player, damage, ore)
			end,
			OnBroken = function()
				meteor.CrustBroken += 1
				self:_breakPart(piece)
				self:_publish({ crustBroken = meteor.CrustBroken })
				if not meteor.Unlocked and meteor.CrustBroken >= meteor.UnlockAt then
					self:_unlockCore(meteor)
				end
			end,
		})
		table.insert(meteor.CrustIds, id)
	end

	meteor.CoreId = NodeService:Register(core, {
		Kind = "Core",
		MaxHp = coreHp,
		Ore = nil,
		OreMult = 0,
		CanHit = function()
			return isActive() and meteor.Unlocked
		end,
		OnHit = function(player, damage)
			ContributionService:AddCore(player, damage)
		end,
		OnBroken = function()
			meteor.Cracked = true
		end,
	})

	model.Parent = workspace:WaitForChild("Map"):WaitForChild("Crater"):WaitForChild("ActiveMeteor")
	return meteor
end

-- Push anyone standing where the meteor lands out of the way (clients also get knockback).
function MeteorService:_clearImpactZone(position: Vector3)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local offset = root.Position - position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude < 26 then
				local direction = if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis
				local target = position + direction * 30
				root.CFrame = CFrame.new(target.X, root.Position.Y + 4, target.Z)
			end
		end
	end
end

function MeteorService:_cool(meteor: Meteor)
	for _, part in meteor.Model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Color = MeteorConfig.InertColor
			part.Material = Enum.Material.Slate
		elseif part:IsA("Light") or part:IsA("ParticleEmitter") then
			part.Enabled = false
		end
	end
end

function MeteorService:_cleanup(meteor: Meteor)
	for _, id in meteor.CrustIds do
		NodeService:Unregister(id)
	end
	NodeService:Unregister(meteor.CoreId)
	meteor.Model:Destroy()
end

function MeteorService:_runEvent(meteorType: Config.MeteorType)
	-- Impact
	local meteor = self:_spawnMeteor(meteorType)
	current = meteor
	ContributionService:Reset()
	self:_clearImpactZone(meteor.Core.Position)
	self:_publish({
		phase = Phase.Impact,
		endsAt = now() + MeteorConfig.ImpactDuration,
		eventId = state.eventId + 1,
		crustTotal = meteor.CrustTotal,
		crustBroken = 0,
		unlocked = false,
	})
	self.Client.Impact:FireAll(meteor.Core.Position)
	task.wait(MeteorConfig.ImpactDuration)

	-- Active: mine the crust, crack the core before it cools
	self:_publish({ phase = Phase.Active, endsAt = now() + MeteorConfig.ActiveDuration })
	waitUntil(function()
		return meteor.Cracked or now() >= state.endsAt
	end)
	ContributionService:Stop()

	if meteor.Cracked then
		self:_publish({ phase = Phase.CoreCracked, endsAt = now() + MeteorConfig.CrackedDuration })
		self.Client.CoreCracked:FireAll(meteor.Core.Position)
		self:_breakPart(meteor.Core)
		RewardService:Finish(true)
		task.wait(MeteorConfig.CrackedDuration)
	else
		self:_publish({ phase = Phase.Cooled, endsAt = now() + MeteorConfig.CooledDuration })
		self:_cool(meteor)
		RewardService:Finish(false)
		task.wait(MeteorConfig.CooledDuration)
	end

	-- Cleanup
	self:_publish({ phase = Phase.Cleanup, endsAt = now() + MeteorConfig.CleanupDuration })
	task.wait(MeteorConfig.CleanupDuration)
	self:_cleanup(meteor)
	current = nil
end

function MeteorService:_loop()
	local first = true
	while true do
		local meteorType = pickType()
		self:_publish({
			phase = Phase.Countdown,
			endsAt = now() + countdownLength(first),
			type = meteorType.Id,
			typeName = meteorType.DisplayName,
			crustTotal = 0,
			crustBroken = 0,
			unlocked = false,
		})
		first = false
		-- endsAt can move while we wait (Call a Meteor, private server settings)
		waitUntil(function()
			return now() >= state.endsAt
		end)

		local ok, err = pcall(self._runEvent, self, meteorType)
		if not ok then
			warn("[MeteorService] event failed:", err)
			if current then
				pcall(self._cleanup, self, current)
				current = nil
			end
			ContributionService:Stop()
		end
	end
end

-- Studio-only shortcut for playtesting: jump to the last few seconds of the countdown.
function MeteorService.Client:DevSkipCountdown(_player: Player)
	if RunService:IsStudio() then
		self.Server:SetCountdownRemaining(MeteorConfig.StreakLeadTime)
	end
end

function MeteorService:KnitInit()
	NodeService = Knit.GetService("NodeService")
	ContributionService = Knit.GetService("ContributionService")
	RewardService = Knit.GetService("RewardService")
end

function MeteorService:KnitStart()
	task.spawn(self._loop, self)
end

return MeteorService

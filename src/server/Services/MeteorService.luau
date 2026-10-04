--!strict
-- Meteor schedule and server-authoritative state machine (spec §5.1 - §5.3).
--
-- Countdown -> Impact -> Active -> CoreCracked | Cooled -> Cleanup -> Countdown ...
--
-- The meteor is assembled at impact from reusable pieces saved in the place:
-- ServerStorage.Assets.Meteor.Core carries NodeSlot attachments, and each slot gets
-- a clone of one of the ServerStorage.Assets.NodePieces rocks, recoloured per type.
-- A few of those crust nodes are rich (spec §8.2): they sparkle, and only they can
-- drop the mineral index's rarest minerals (IndexService).
-- The map itself (crater, town, debris, plots) is saved in Workspace.Map.
--
-- Call a Meteor (spec §9.2): CanCallMeteor applies Shared.CallMeteor's rules to the
-- live schedule and CallMeteor(player) jumps the countdown and announces the buyer.
-- MonetizationService calls them from ProcessReceipt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Phase = require(ReplicatedStorage.Shared.Phase)
local MiningPower = require(ReplicatedStorage.Shared.MiningPower)
local MeteorTypes = require(ReplicatedStorage.Shared.MeteorTypes)
local MineralIndex = require(ReplicatedStorage.Shared.MineralIndex)
local CallMeteor = require(ReplicatedStorage.Shared.CallMeteor)
local Signal = require(ReplicatedStorage.Packages.Signal)

local MeteorConfig = Config.Meteor

-- Seconds between meteors. Private servers will be able to change it (spec §5.1,
-- §12.4); a faster schedule pays a smaller shard pool (MeteorTypes.shardPoolMult).
-- The first meteor's shorter countdown and Studio's are not a faster schedule.
local interval = MeteorConfig.Countdown

local MeteorService = Knit.CreateService({
	Name = "MeteorService",
	Client = {
		-- { phase, endsAt, type, typeName, requiredTier, eventId, crustTotal, crustBroken, unlocked }
		-- endsAt is in workspace:GetServerTimeNow() time. type is the Config.Meteor.Types
		-- id, picked at the start of each countdown; requiredTier is its pickaxe tier.
		State = Knit.CreateProperty(nil),
		Impact = Knit.CreateSignal(), -- (position: Vector3)
		CoreCracked = Knit.CreateSignal(), -- (position: Vector3)
	},
})

MeteorService.Landed = Signal.new() -- (position: Vector3) at impact
-- (meteorType: string, cracked: boolean, secondsToCrack: number?) when the Active
-- phase ends; secondsToCrack runs from the start of Active, nil when it cooled
MeteorService.Ended = Signal.new()

local NodeService
local ContributionService
local RewardService
local ActivityService
local PlayerStateService

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
	CrackedAt: number, -- os.clock() when the core broke, 0 until then
	Type: Config.MeteorType,
	SizedPower: number, -- server power the current HP is sized for
	CrustHp: number, -- a crust node's max HP at that power (under-tier mining is paced on it)
	LastRescale: number,
}

local state = {
	phase = Phase.Countdown,
	endsAt = 0,
	type = "Iron",
	typeName = "Iron Meteor",
	requiredTier = 1,
	eventId = 0,
	crustTotal = 0,
	crustBroken = 0,
	unlocked = false,
}
local current: Meteor? = nil
-- Call a Meteor bookkeeping, in os.clock() time: when the last CALLED meteor's Active
-- phase ended (nil until one has; ordinary meteors don't start the cooldown), whether
-- the coming/current event was called, and when each call was made (pruned to the cap window)
local lastCalledEnd: number? = nil
local eventCalled = false
local callTimes: { number } = {}
-- Studio only (DevSpawn): the meteor type asked for from the command bar or chat. It
-- ends a meteor that is still down and comes in StreakLeadTime seconds into its countdown.
local devNext: Config.MeteorType? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

function MeteorService:_publish(patch: { [string]: any })
	-- Use the actual length of each phase, including first and Studio countdowns.
	if patch.phase ~= nil and patch.endsAt ~= nil then
		patch.duration = math.max(0, patch.endsAt - now())
	end
	for key, value in patch do
		(state :: any)[key] = value
	end
	self.Client.State:Set(table.clone(state))
end

function MeteorService:GetPhase(): Phase.Phase
	return state.phase
end

-- The type of the meteor on the ground (impact to cleanup), nil between meteors.
function MeteorService:GetActiveType(): Config.MeteorType?
	return if current then current.Type else nil
end

-- Sets the remaining countdown (used by Call a Meteor and private servers later).
function MeteorService:SetCountdownRemaining(seconds: number)
	if state.phase == Phase.Countdown then
		self:_publish({ endsAt = now() + seconds })
	end
end

-- Whether Call a Meteor can be bought right now, and why not (Shared.CallMeteor).
function MeteorService:CanCallMeteor(): (boolean, string?)
	local clock = os.clock()
	local sinceLastEnd = if lastCalledEnd then clock - lastCalledEnd else nil
	return CallMeteor.available(
		state.phase,
		state.endsAt - now(),
		sinceLastEnd,
		CallMeteor.callsInWindow(callTimes, clock)
	)
end

-- Brings the next meteor in early for the whole server (spec §9.2) if the rules
-- allow it: the countdown jumps to Config.Monetization.CallMeteor.SetCountdownTo and
-- the server hears who called it. The meteor type was already picked; a call can't
-- change it or the loot. Returns whether it went through and, if not, why.
function MeteorService:CallMeteor(player: Player): (boolean, string?)
	local ok, reason = self:CanCallMeteor()
	if not ok then
		return false, reason
	end
	local clock = os.clock()
	local window = Config.Monetization.CallMeteor.CapWindow
	for index = #callTimes, 1, -1 do
		if clock - callTimes[index] >= window then
			table.remove(callTimes, index)
		end
	end
	table.insert(callTimes, clock)
	eventCalled = true
	self:SetCountdownRemaining(Config.Monetization.CallMeteor.SetCountdownTo)
	RewardService:Announce("CallMeteor", player.DisplayName .. " called a meteor!")
	return true, nil
end

local function countdownLength(first: boolean): number
	if RunService:IsStudio() and MeteorConfig.StudioCountdown then
		return MeteorConfig.StudioCountdown
	end
	return if first then MeteorConfig.FirstCountdown else interval
end

-- The next meteor's type (spec §8.1): weighted odds, gated by the active players'
-- pickaxe tiers (MeteorTypes.pick). In Studio, ServerStorage's DevMeteorType
-- attribute ("Ice") forces a type for testing.
local function pickType(): Config.MeteorType
	local forced = ServerStorage:GetAttribute("DevMeteorType")
	if RunService:IsStudio() and typeof(forced) == "string" and MeteorConfig.Types[forced] then
		return MeteorConfig.Types[forced]
	end
	return MeteorTypes.pick(ActivityService:GetActiveTiers(), math.random())
end

-- Mining Power per second of the active players, with the floor (spec §5.3).
local function serverPower(): number
	return MiningPower.serverPower(ActivityService:GetActiveTiers())
end

-- Moves a part and the decorative parts parented under it together.
local function place(part: BasePart, cframe: CFrame)
	local offsets = {}
	for _, child in part:GetDescendants() do
		if child:IsA("BasePart") then
			offsets[child] = part.CFrame:ToObjectSpace(child.CFrame)
		end
	end
	part.CFrame = cframe
	for child, offset in offsets do
		child.CFrame = cframe * offset
	end
end

-- Recolours a cluster: the rock itself, its "Ore" chunks and "Ember" glints.
local function paintCluster(piece: BasePart, meteorType: Config.MeteorType)
	piece.Color = meteorType.CrustColors[math.random(1, #meteorType.CrustColors)]
	piece.Material = meteorType.CrustMaterial
	for _, child in piece:GetDescendants() do
		if child:IsA("BasePart") then
			if child.Name == "Ore" then
				child.Color = meteorType.OreColor
				child.Material = meteorType.OreMaterial
			elseif child.Name == "Ember" then
				child.Color = meteorType.GlowColor
			elseif child.Name == "Rock" then
				child.Color = piece.Color
				child.Material = piece.Material
			end
		end
	end
end

-- Marks a crust node rich (spec §8.2): IndexService reads the Rich attribute on each
-- hit. Its ore chunks take Config.Index.RichColor and it sparkles so players can
-- spot it; breaking or cooling the meteor turns the sparkle off with its other effects.
local function markRich(piece: BasePart)
	piece:SetAttribute("Rich", true)
	for _, child in piece:GetDescendants() do
		if child:IsA("BasePart") and child.Name == "Ore" then
			child.Color = Config.Index.RichColor
			child.Material = Enum.Material.Neon
		end
	end
	local sparkle = Instance.new("ParticleEmitter") -- the default texture is a sparkle
	sparkle.Name = "RichSparkle"
	sparkle.Color = ColorSequence.new(Config.Index.RichColor)
	sparkle.LightEmission = 1
	sparkle.Rate = 8
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(0.5, 1.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkle.Parent = piece
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
	for _, child in core:GetDescendants() do
		if child:IsA("BasePart") and child.Name == "Vein" then
			child.Transparency = 1 -- the whole core glows now
		elseif child:IsA("ParticleEmitter") then
			child.Rate *= 3
		end
	end
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
	place(core, spawnPoint.CFrame * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	core.Anchored = true
	core.Material = Enum.Material.Basalt
	-- the template's lights and embers are Iron orange; other types recolour them
	local recolorLights = meteorType.Id ~= "Iron"
	core.Color = meteorType.CoreColor:Lerp(Color3.new(0, 0, 0), 0.7)
	for _, vein in core:GetDescendants() do
		if vein:IsA("BasePart") and vein.Name == "Vein" then
			vein.Color = meteorType.GlowColor
		elseif recolorLights and (vein:IsA("PointLight") or vein:IsA("SpotLight") or vein:IsA("SurfaceLight")) then
			vein.Color = meteorType.GlowColor -- the template's lights are orange (Iron)
		elseif recolorLights and vein:IsA("ParticleEmitter") then
			vein.Color = ColorSequence.new(meteorType.GlowColor)
		end
	end
	core.Parent = model
	model.PrimaryPart = core

	local power = serverPower()
	local slots = {}
	for _, child in core:GetChildren() do
		if child:IsA("Attachment") and child.Name == "NodeSlot" then
			table.insert(slots, child)
		end
	end
	local crustHp, coreHp = MiningPower.size(power, #slots, meteorType.HpMult)

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
		CrackedAt = 0,
		Type = meteorType,
		SizedPower = power,
		CrustHp = crustHp,
		LastRescale = os.clock(),
	}
	model:SetAttribute("ServerPower", power)

	local function isActive(): boolean
		return state.phase == Phase.Active and current == meteor
	end

	-- Everyone mines the meteor's own ore (spec §8.1). A pickaxe under its tier gets a
	-- fraction of it per crust hit, worth 3x a hit on the pickaxe's own best ore per type
	-- above it (MeteorTypes.underTierYield), up to MeteorTypes.underTierCap over this
	-- meteor; PlayerStateService:AddOre adds the fractions up.
	local underTierOre: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
	local function oreFor(player: Player): (string?, number)
		local pickaxe = PlayerStateService:GetPickaxe(player)
		if not MeteorTypes.underTier(pickaxe.Tier, meteorType) then
			return meteorType.Ore, meteorType.YieldMult
		end
		local cap = MeteorTypes.underTierCap(pickaxe.Tier, PlayerStateService:GetCapacity(player), meteorType)
		local taken = underTierOre[player] or 0
		local quantity = math.min(pickaxe.OrePerHit * MeteorTypes.underTierYield(pickaxe.Tier, meteorType), cap - taken)
		if quantity <= 0 or pickaxe.OrePerHit <= 0 then
			return nil, 0
		end
		underTierOre[player] = taken + quantity
		return meteorType.Ore, meteorType.YieldMult * quantity / pickaxe.OrePerHit
	end

	-- Mining Power per hit: a pickaxe under the meteor's tier mines slower the more tiers
	-- short it is, and the Crystal twist makes every player on the same node or core mine harder
	local function powerMult(player: Player, hitters: number): number
		local mult = if meteorType.Twist == "Resonance" then MeteorTypes.resonanceMult(hitters) else 1
		local pickaxe = PlayerStateService:GetPickaxe(player)
		local short = MeteorTypes.tiersShort(pickaxe.Tier, meteorType)
		if short > 0 then
			mult *= MeteorTypes.underTierPowerMult(MiningPower.power(pickaxe.Tier), pickaxe.Swing, meteor.CrustHp, short)
		end
		return mult
	end

	local crustFolder = Instance.new("Folder")
	crustFolder.Name = "Crust"
	crustFolder.Parent = model

	local richNodes = MineralIndex.pickRichNodes(#slots, math.random)
	for index, slot in slots do
		local piece = (pieces[math.random(1, #pieces)] :: BasePart):Clone()
		piece.Name = "CrustNode" .. index
		piece.Anchored = true
		place(piece, slot.WorldCFrame * CFrame.Angles(0, math.random() * math.pi * 2, 0))
		paintCluster(piece, meteorType)
		if richNodes[index] then
			markRich(piece)
		end
		piece.Parent = crustFolder

		local id = NodeService:Register(piece, {
			Kind = "Crust",
			MaxHp = crustHp,
			Ore = nil,
			OreMult = 0,
			OreFor = oreFor,
			PowerMult = powerMult,
			CanHit = function()
				return isActive()
			end,
			OnHit = function(player, power, ore)
				ContributionService:AddCrust(player, power, ore)
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
		PowerMult = powerMult,
		CanHit = function()
			return isActive() and meteor.Unlocked
		end,
		OnHit = function(player, power)
			ContributionService:AddCore(player, power)
		end,
		OnBroken = function()
			meteor.Cracked = true
			meteor.CrackedAt = os.clock()
		end,
	})

	model.Parent = workspace:WaitForChild("Map"):WaitForChild("Crater"):WaitForChild("ActiveMeteor")
	return meteor
end

-- Mid-event joins and leaves (spec §5.3): when the active server power drifts more
-- than 15% from what the meteor was sized for, rescale the remaining HP of every
-- node and the core to the new power, keeping the same fraction done. At most once
-- every RescaleCooldown seconds.
function MeteorService:_checkRescale(meteor: Meteor)
	if os.clock() - meteor.LastRescale < MeteorConfig.RescaleCooldown then
		return
	end
	local power = serverPower()
	if not MiningPower.shouldRescale(meteor.SizedPower, power) then
		return
	end
	local ratio = power / meteor.SizedPower
	for _, id in meteor.CrustIds do
		NodeService:Rescale(id, ratio)
	end
	NodeService:Rescale(meteor.CoreId, ratio)
	meteor.SizedPower = power
	meteor.CrustHp *= ratio
	meteor.LastRescale = os.clock()
	meteor.Model:SetAttribute("ServerPower", power)
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

-- Ice twist (spec §8.1): every live crust node and the core that nobody has hit for
-- a while regains HP, `dt` seconds' worth (MeteorTypes.refreezeHp).
function MeteorService:_refreeze(meteor: Meteor, dt: number)
	local function refreeze(id: number)
		local hp, maxHp = NodeService:GetHp(id)
		local refrozen = MeteorTypes.refreezeHp(hp, maxHp, NodeService:GetIdleSeconds(id), dt)
		if refrozen > hp then
			NodeService:Heal(id, refrozen - hp)
		end
	end
	for _, id in meteor.CrustIds do
		refreeze(id)
	end
	refreeze(meteor.CoreId)
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
	self.Landed:Fire(meteor.Core.Position)
	task.wait(MeteorConfig.ImpactDuration)

	-- Active: mine the crust, crack the core before it cools
	self:_publish({ phase = Phase.Active, endsAt = now() + meteorType.ActiveDuration })
	local activeStart = os.clock()
	local nextCheck = os.clock() + MeteorConfig.RescaleCheckInterval
	local refreezing = meteorType.Twist == "Refreeze"
	local lastRefreeze = os.clock()
	waitUntil(function()
		local clock = os.clock()
		if clock >= nextCheck then
			nextCheck = clock + MeteorConfig.RescaleCheckInterval
			self:_checkRescale(meteor)
		end
		if refreezing and clock - lastRefreeze >= MeteorConfig.Twists.Refreeze.Tick then
			self:_refreeze(meteor, clock - lastRefreeze)
			lastRefreeze = clock
		end
		return meteor.Cracked or now() >= state.endsAt or devNext ~= nil
	end)
	ContributionService:Stop()
	-- The Call a Meteor cooldown runs from the end of a called meteor's event only
	if eventCalled then
		lastCalledEnd = os.clock()
		eventCalled = false
	end
	self.Ended:Fire(meteorType.Id, meteor.Cracked, if meteor.Cracked then meteor.CrackedAt - activeStart else nil)

	local poolMult = MeteorTypes.shardPoolMult(meteorType, interval, MeteorConfig.Countdown)
	if meteor.Cracked then
		self:_publish({ phase = Phase.CoreCracked, endsAt = now() + MeteorConfig.CrackedDuration })
		self.Client.CoreCracked:FireAll(meteor.Core.Position)
		self:_breakPart(meteor.Core)
		RewardService:Finish(true, meteorType, poolMult)
		task.wait(MeteorConfig.CrackedDuration)
	else
		self:_publish({ phase = Phase.Cooled, endsAt = now() + MeteorConfig.CooledDuration })
		self:_cool(meteor)
		RewardService:Finish(false, meteorType, poolMult)
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
		local queued = devNext
		devNext = nil
		local meteorType = queued or pickType()
		self:_publish({
			phase = Phase.Countdown,
			endsAt = now() + (if queued then MeteorConfig.StreakLeadTime else countdownLength(first)),
			type = meteorType.Id,
			typeName = meteorType.DisplayName,
			requiredTier = meteorType.RequiredTier,
			crustTotal = 0,
			crustBroken = 0,
			unlocked = false,
		})
		first = false
		-- endsAt can move while we wait (Call a Meteor, private server settings)
		waitUntil(function()
			return now() >= state.endsAt
		end)
		-- DevSpawn swapped the type during this countdown
		if devNext then
			meteorType = devNext
			devNext = nil
		end

		local ok, err = pcall(self._runEvent, self, meteorType)
		if not ok then
			warn("[MeteorService] event failed:", err)
			if current then
				pcall(self._cleanup, self, current)
				current = nil
			end
			ContributionService:Stop()
			if eventCalled then -- a failed Call a Meteor event still starts its cooldown
				lastCalledEnd = os.clock()
				eventCalled = false
			end
		end
	end
end

-- Studio only, for testing: brings a meteor of the given type ("Iron", "Ice", "Crystal",
-- any case) down soon. During a countdown it swaps the type and lands in StreakLeadTime
-- seconds; otherwise the meteor that is down ends early (it cools) and the asked-for one
-- comes in StreakLeadTime seconds into the next countdown. Returns what will happen.
function MeteorService:DevSpawn(typeId: string): string
	if not RunService:IsStudio() then
		return "DevSpawn only works in Studio"
	end
	local meteorType: Config.MeteorType? = nil
	for id, candidate in MeteorConfig.Types do
		if string.lower(id) == string.lower(tostring(typeId)) then
			meteorType = candidate
		end
	end
	if not meteorType then
		return string.format("No meteor type %q (try %s)", tostring(typeId), table.concat(MeteorConfig.TypeOrder, ", "))
	end
	devNext = meteorType
	if state.phase == Phase.Countdown then
		self:_publish({
			endsAt = now() + MeteorConfig.StreakLeadTime,
			type = meteorType.Id,
			typeName = meteorType.DisplayName,
			requiredTier = meteorType.RequiredTier,
		})
		return string.format("%s lands in %d s", meteorType.DisplayName, MeteorConfig.StreakLeadTime)
	end
	return string.format("The current meteor ends now; %s is next, %d s into the next countdown", meteorType.DisplayName, MeteorConfig.StreakLeadTime)
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
	ActivityService = Knit.GetService("ActivityService")
	PlayerStateService = Knit.GetService("PlayerStateService")
end

function MeteorService:KnitStart()
	task.spawn(self._loop, self)
end

return MeteorService

--!strict
-- Mineable targets (meteor crust nodes, the core, debris rocks): HP, hit validation,
-- per-player ore drops and batched HP replication (spec §5.4, §12.2).
--
-- HP is measured in Mining Power (spec §5.3): each hit takes MiningPower.power(tier)
-- off the target, while the client still pops the pickaxe's big damage number.
--
-- Other services register a BasePart with a TargetDef. The part gets a TargetId
-- attribute so clients can find it; HP is replicated through the Hp / MaxHp
-- attributes, flushed at ~10 Hz for changed targets only.
--
-- Meteor types (spec §8.1) hook in through the TargetDef: OreFor decides each
-- player's ore per hit (an under-tier pickaxe only gets some), PowerMult scales a
-- hit's Mining Power by the player's pickaxe (under-tier mining is slow) and by how
-- many players are on the target (Crystal resonance), and Heal plus the idle clock
-- let MeteorService refreeze Ice nodes nobody is hitting.
--
-- The 2x Ore pass (spec §9.1) multiplies the ore quantity per hit here and nothing
-- else: mineral drops are rolled by IndexService on the Hit signal, whose odds no
-- purchase can reach (spec §9.4).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local MiningPower = require(ReplicatedStorage.Shared.MiningPower)
local Signal = require(ReplicatedStorage.Packages.Signal)

export type TargetKind = "Crust" | "Core" | "Debris"

export type TargetDef = {
	Kind: TargetKind,
	MaxHp: number,
	Ore: string?, -- ore type dropped per hit, nil for none
	OreMult: number, -- multiplier on the pickaxe's ore per hit
	-- Per-player ore type and multiplier; when set it replaces Ore and OreMult
	OreFor: ((player: Player) -> (string?, number))?,
	-- Multiplier on the hit's Mining Power (HP taken and contribution). `hitters` is
	-- how many players hit this target within the Resonance window, this one included.
	PowerMult: ((player: Player, hitters: number) -> number)?,
	CanHit: ((player: Player) -> boolean)?,
	OnHit: ((player: Player, power: number, ore: number) -> ())?, -- power is the hit's Mining Power
	OnBroken: ((player: Player) -> ())?,
}

type Target = {
	Id: number,
	Part: BasePart,
	Def: TargetDef,
	Hp: number,
	Dirty: boolean,
	LastHit: number, -- os.clock() of the last validated hit, or of registration
	Hitters: { [Player]: number }, -- os.clock() of each player's last hit; kept only for PowerMult targets
}

local NodeService = Knit.CreateService({
	Name = "NodeService",
	Client = {
		-- Fired only to the player who mined, so ore visuals are per-player (spec §5.4)
		OreGained = Knit.CreateSignal(),
	},
})

-- (player, kind: TargetKind, part: BasePart) after every validated hit. The part lets
-- listeners read its attributes, e.g. IndexService checks a crust node's Rich flag.
NodeService.Hit = Signal.new()

local PlayerStateService
local ActivityService
local MonetizationService

local targets: { [number]: Target } = {}
local nextId = 0
local lastSwing: { [Player]: number } = {}

function NodeService:Register(part: BasePart, def: TargetDef): number
	nextId += 1
	local target: Target = {
		Id = nextId,
		Part = part,
		Def = def,
		Hp = def.MaxHp,
		Dirty = false,
		LastHit = os.clock(),
		Hitters = {},
	}
	targets[nextId] = target
	part:SetAttribute("TargetId", nextId)
	part:SetAttribute("TargetKind", def.Kind)
	part:SetAttribute("MaxHp", def.MaxHp)
	part:SetAttribute("Hp", def.MaxHp)
	return nextId
end

function NodeService:Unregister(id: number)
	local target = targets[id]
	if target then
		targets[id] = nil
		if target.Part.Parent then
			target.Part:SetAttribute("TargetId", nil)
		end
	end
end

-- Resets a target to full HP (debris respawn) or to a new max (meteor sizing).
function NodeService:SetMaxHp(id: number, maxHp: number)
	local target = targets[id]
	if not target then
		return
	end
	target.Def.MaxHp = maxHp
	target.Hp = maxHp
	target.Part:SetAttribute("MaxHp", maxHp)
	target.Part:SetAttribute("Hp", maxHp)
	target.Dirty = false
end

-- Rescales a target's remaining and max HP by ratio, keeping the same fraction done
-- (mid-event joins and leaves, spec §5.3). Broken targets stay broken.
function NodeService:Rescale(id: number, ratio: number)
	local target = targets[id]
	if not target or target.Hp <= 0 then
		return
	end
	target.Hp, target.Def.MaxHp = MiningPower.rescale(target.Hp, target.Def.MaxHp, ratio)
	target.Part:SetAttribute("MaxHp", target.Def.MaxHp)
	target.Part:SetAttribute("Hp", target.Hp)
	target.Dirty = false
end

-- Gives a live target up to `hp` HP back, never past its max (Ice refreeze, spec
-- §8.1). Broken targets stay broken. Clients see it with the next HP flush.
function NodeService:Heal(id: number, hp: number)
	local target = targets[id]
	if not target or target.Hp <= 0 or hp <= 0 then
		return
	end
	local healed = math.min(target.Hp + hp, target.Def.MaxHp)
	if healed > target.Hp then
		target.Hp = healed
		target.Dirty = true
	end
end

function NodeService:GetHp(id: number): (number, number)
	local target = targets[id]
	if not target then
		return 0, 0
	end
	return target.Hp, target.Def.MaxHp
end

-- Seconds since anyone last hit the target (or since it was registered).
function NodeService:GetIdleSeconds(id: number): number
	local target = targets[id]
	return if target then os.clock() - target.LastHit else 0
end

-- Distance from a point to the closest point on the part's bounding box.
local function distanceToPart(part: BasePart, point: Vector3): number
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	local clamped = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)
	return (localPoint - clamped).Magnitude
end

-- Records this hit and returns how many players hit the target within the
-- Resonance window (spec §8.1), this one included. Older hitters are forgotten.
local function countHitters(target: Target, player: Player, now: number): number
	local hitters = target.Hitters
	hitters[player] = now
	local window = Config.Meteor.Twists.Resonance.Window
	local count = 0
	for other, at in hitters do
		if now - at <= window then
			count += 1
		else
			hitters[other] = nil
		end
	end
	return count
end

-- Server-side validation of one swing. Invalid swings are rejected silently.
function NodeService:Swing(player: Player, id: number): (boolean, number?)
	if typeof(id) ~= "number" then
		return false
	end
	local target = targets[id]
	if not target or target.Hp <= 0 or not target.Part.Parent then
		return false
	end

	local pickaxe = PlayerStateService:GetPickaxe(player)
	local now = os.clock()
	if now - (lastSwing[player] or 0) < pickaxe.Swing * Config.Meteor.SwingTolerance then
		return false
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	if distanceToPart(target.Part, root.Position) > Config.Meteor.MineRange then
		return false
	end

	local def = target.Def
	if def.CanHit and not def.CanHit(player) then
		return false
	end

	lastSwing[player] = now
	target.LastHit = now
	ActivityService:Touch(player)

	local power = MiningPower.power(pickaxe.Tier)
	if def.PowerMult then
		power *= def.PowerMult(player, countHitters(target, player, now))
	end
	target.Hp -= power
	if target.Hp < 1e-6 then
		target.Hp = 0
	end
	target.Dirty = true

	local oreType, oreMult = def.Ore, def.OreMult
	if def.OreFor then
		oreType, oreMult = def.OreFor(player)
	end
	local ore = 0
	if oreType then
		local quantity = pickaxe.OrePerHit * oreMult * MonetizationService:OreMult(player)
		ore = PlayerStateService:AddOre(player, oreType, quantity)
		if ore > 0 then
			self.Client.OreGained:Fire(player, id, oreType, ore)
		end
	end

	if def.OnHit then
		def.OnHit(player, power, ore)
	end
	self.Hit:Fire(player, def.Kind, target.Part)

	if target.Hp == 0 then
		target.Part:SetAttribute("Hp", 0)
		target.Dirty = false
		if def.OnBroken then
			def.OnBroken(player)
		end
	end

	-- The displayed number is the pickaxe's damage; HP went down by its Mining Power
	return true, pickaxe.Damage
end

function NodeService.Client:Swing(player: Player, id: number): (boolean, number?)
	return self.Server:Swing(player, id)
end

function NodeService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	ActivityService = Knit.GetService("ActivityService")
	MonetizationService = Knit.GetService("MonetizationService")
end

function NodeService:KnitStart()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < Config.Meteor.HpFlushInterval then
			return
		end
		accumulator = 0
		for _, target in targets do
			if target.Dirty then
				target.Dirty = false
				target.Part:SetAttribute("Hp", target.Hp)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
end

return NodeService

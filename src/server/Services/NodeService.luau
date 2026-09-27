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
}

local NodeService = Knit.CreateService({
	Name = "NodeService",
	Client = {
		-- Fired only to the player who mined, so ore visuals are per-player (spec §5.4)
		OreGained = Knit.CreateSignal(),
	},
})

NodeService.Hit = Signal.new() -- (player, kind: TargetKind) after every validated hit

local PlayerStateService
local ActivityService

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

function NodeService:GetHp(id: number): (number, number)
	local target = targets[id]
	if not target then
		return 0, 0
	end
	return target.Hp, target.Def.MaxHp
end

function NodeService:IsAlive(id: number): boolean
	local target = targets[id]
	return target ~= nil and target.Hp > 0
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
	ActivityService:Touch(player)

	local power = MiningPower.power(pickaxe.Tier)
	target.Hp -= power
	if target.Hp < 1e-6 then
		target.Hp = 0
	end
	target.Dirty = true

	local ore = 0
	if def.Ore then
		ore = PlayerStateService:AddOre(player, def.Ore, pickaxe.OrePerHit * def.OreMult)
		if ore > 0 then
			self.Client.OreGained:Fire(player, id, def.Ore, ore)
		end
	end

	if def.OnHit then
		def.OnHit(player, power, ore)
	end
	self.Hit:Fire(player, def.Kind)

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

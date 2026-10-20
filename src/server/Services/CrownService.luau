--!strict
-- The Crown plateau's two ways in and out (map v3, Map.Crown):
--   Sky Lift: a prompt on Crown.Lift.Prompt at the end of the north avenue carries you up to Crown.LiftTop, from
--   Config.Crown.LiftRebirths rebirths on. The server checks the saved rebirths; the prompt is open to everyone.
--   Meteor Dive: touching Crown.DivePad throws you on a ballistic arc (Shared.DiveArc) onto the crater's north rim.
--   The server decides the launch; the client applies it (it owns its character's physics, like the knockback).
-- Below LiftRebirths nobody stays on the Crown however they got up (climbing the north slide, a lucky jump): every
-- half second they are put back at the lift's foot with the same notice.
-- A map without a Crown (the archived v2 map) simply never wires either.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local DiveArc = require(ReplicatedStorage.Shared.DiveArc)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local WorldGeometry = require(ReplicatedStorage.Shared.WorldGeometry)
local SafeLoop = require(script.Parent.Parent.Lib.SafeLoop)

local CrownService = Knit.CreateService({
	Name = "CrownService",
	Client = { Dive = Knit.CreateSignal() }, -- (velocity: Vector3, seconds: number) launch yourself
})

local PlayerStateService
local RewardService
local lastDive: { [Player]: number } = {}

local function liveRoot(player: Player): (Model?, BasePart?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then return character, root end
	return nil, nil
end

function CrownService:RideLift(player: Player, crown: Instance): boolean
	local data = PlayerStateService:Get(player)
	if not data or (data.rebirths or 0) < Config.Crown.LiftRebirths then
		RewardService:Bonus(player, "locked", "The Sky Lift opens at rebirth " .. Config.Crown.LiftRebirths)
		return false
	end
	local top = crown:FindFirstChild("LiftTop")
	local character, root = liveRoot(player)
	if not (character and root and top and top:IsA("BasePart")) then return false end
	character:PivotTo(top.CFrame + Vector3.new(0, 4, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	return true
end

function CrownService:Dive(player: Player, pad: BasePart): boolean
	local now = os.clock()
	if lastDive[player] and now - lastDive[player] < Config.Crown.DiveCooldown then return false end
	local _, root = liveRoot(player)
	-- a touch is reported by the toucher's machine: only launch someone actually standing at the pad
	if not root or (root.Position - pad.Position).Magnitude > pad.Size.Magnitude / 2 + 8 then return false end
	lastDive[player] = now
	local velocity, seconds = DiveArc.velocity(root.Position, Config.Crown.DiveTarget, Config.Crown.DiveApex, workspace.Gravity)
	self.Client.Dive:Fire(player, velocity, seconds)
	return true
end

-- Puts anyone below LiftRebirths who stands on the Crown back in front of the lift
function CrownService:_returnUnready(crown: Instance)
	local lift = crown:FindFirstChild("Lift")
	local promptPart = lift and lift:FindFirstChild("Prompt")
	if not (promptPart and promptPart:IsA("BasePart")) then return end
	for _, player in Players:GetPlayers() do
		local character, root = liveRoot(player)
		local data = PlayerStateService:Get(player)
		if character and root and data and (data.rebirths or 0) < Config.Crown.LiftRebirths and WorldGeometry.onCrown(root.Position) then
			character:PivotTo(CFrame.new(promptPart.Position + Vector3.new(0, 1, -4)))
			root.AssemblyLinearVelocity = Vector3.zero
			RewardService:Bonus(player, "locked", "The Crown opens at rebirth " .. Config.Crown.LiftRebirths)
		end
	end
end

function CrownService:_wire(crown: Instance)
	local lift = crown:WaitForChild("Lift", math.huge)
	local promptPart = lift:WaitForChild("Prompt", math.huge)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RideLift"
	prompt.ActionText = "Ride up"
	prompt.ObjectText = "Sky Lift"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Crown.PromptRange
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
	prompt.Triggered:Connect(function(player) self:RideLift(player, crown) end)

	local pad = crown:WaitForChild("DivePad", math.huge)
	if pad:IsA("BasePart") then
		pad.CanTouch = true
		pad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player then self:Dive(player, pad) end -- any body part; the cooldown keeps it to one launch
		end)
	end
end

function CrownService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	RewardService = Knit.GetService("RewardService")
end

function CrownService:KnitStart()
	Players.PlayerRemoving:Connect(function(player) lastDive[player] = nil end)
	task.spawn(function()
		local crown = WorldMap.wait():WaitForChild("Crown", math.huge)
		task.spawn(function()
			while crown.Parent do
				task.wait(0.5)
				SafeLoop.step("CrownEject", function()
					self:_returnUnready(crown)
				end)
			end
		end)
		self:_wire(crown)
	end)
end

return CrownService

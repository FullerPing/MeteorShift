--!strict
-- Juice for the ore fields (Workspace.Map.Debris): every live rock glows softly and sparkles in its
-- ore colour, breaks in a spray of chips, and flashes when it grows back. All local and cosmetic: the
-- server owns HP and drops (DebrisService); this only reacts to a rock's Transparency, which the
-- server sets to 1 when it breaks and back to 0 when it respawns.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)

local FieldFXController = Knit.CreateController({ Name = "FieldFXController" })

local STONE = Color3.fromRGB(150, 146, 156)

type Juice = { rock: BasePart, light: PointLight, sparkle: ParticleEmitter, chips: ParticleEmitter, phase: number }

-- The ore colour a rock shows right now (the server tints flecks by the tier a rock is sized for)
local function oreColor(rock: BasePart): Color3
	for _, child in rock:GetDescendants() do
		if child:IsA("BasePart") and child.Name == "OreFleck" then return child.Color end
	end
	return rock.Color
end

local function makeJuice(rock: BasePart, index: number): Juice
	local settings = Config.Debris.Rock
	local color = oreColor(rock)
	local light = Instance.new("PointLight")
	light.Name = "FieldGlow"
	light.Color = color
	light.Range = settings.LightRange
	light.Brightness = settings.LightBrightness
	light.Shadows = false
	light.Parent = rock

	local sparkle = Instance.new("ParticleEmitter") -- the default texture is a sparkle
	sparkle.Name = "FieldSparkle"
	sparkle.Color = ColorSequence.new(color)
	sparkle.LightEmission = 1
	sparkle.Rate = settings.SparkleRate
	sparkle.Lifetime = NumberRange.new(1, 1.8)
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(60, 60)
	sparkle.EmissionDirection = Enum.NormalId.Top
	sparkle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.7), NumberSequenceKeypoint.new(1, 0),
	})
	sparkle.Parent = rock

	local chips = Instance.new("ParticleEmitter")
	chips.Name = "FieldChips"
	chips.Enabled = false
	chips.Rate = 0
	chips.Lifetime = NumberRange.new(0.5, 0.9)
	chips.Speed = NumberRange.new(14, 26)
	chips.SpreadAngle = Vector2.new(180, 180)
	chips.Acceleration = Vector3.new(0, -60, 0)
	chips.Drag = 1
	chips.Rotation = NumberRange.new(0, 360)
	chips.RotSpeed = NumberRange.new(-300, 300)
	chips.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0) })
	chips.Transparency = NumberSequence.new(0, 0.1)
	chips.LightEmission = 0.4
	chips.Parent = rock

	return { rock = rock, light = light, sparkle = sparkle, chips = chips, phase = index * 1.7 }
end

local function setLive(juice: Juice, live: boolean)
	juice.light.Enabled = live
	juice.sparkle.Enabled = live
end

-- A rock just broke: chips in its ore and stone colours
local function burst(juice: Juice)
	local color = oreColor(juice.rock)
	juice.chips.Color = ColorSequence.new(color, STONE)
	juice.chips:Emit(Config.Debris.Rock.BurstCount)
end

-- A rock just grew back: a quick glow-flash and a puff of sparkles
local function pop(juice: Juice)
	local color = oreColor(juice.rock)
	juice.light.Color = color
	juice.sparkle.Color = ColorSequence.new(color)
	juice.sparkle:Emit(8)
	local flash = Instance.new("Highlight")
	flash.Name = "FieldPop"
	flash.Adornee = juice.rock
	flash.FillColor = color
	flash.FillTransparency = 0.1
	flash.OutlineTransparency = 1
	flash.DepthMode = Enum.HighlightDepthMode.Occluded
	flash.Parent = juice.rock
	local tween = TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 1 })
	tween.Completed:Once(function() flash:Destroy() end)
	tween:Play()
end

function FieldFXController:KnitStart()
	local debris = WorldMap.wait():WaitForChild("Debris")
	local all: { Juice } = {}
	local function track(rock: Instance)
		if not rock:IsA("BasePart") then return end
		local juice = makeJuice(rock, #all + 1)
		table.insert(all, juice)
		local live = rock.Transparency < 1
		setLive(juice, live)
		rock:GetPropertyChangedSignal("Transparency"):Connect(function()
			local now = rock.Transparency < 1
			if now == live then return end
			live = now
			setLive(juice, now)
			if now then pop(juice) else burst(juice) end
		end)
	end
	for _, rock in debris:GetChildren() do track(rock) end
	debris.ChildAdded:Connect(track)

	-- One shared loop breathes every glow
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, juice in all do
			if juice.light.Enabled then
				juice.light.Brightness = Config.Debris.Rock.LightBrightness * (0.75 + 0.25 * math.sin(t * 2.2 + juice.phase))
			end
		end
	end)
end

return FieldFXController

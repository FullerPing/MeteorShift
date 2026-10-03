--!strict
-- Fog and light moods during meteor events (spec §5.8), client-side. The calm look
-- is authored in the place; this reads it once and blends Config.Atmosphere's
-- moods on top (Shared.AtmosphereMood): the sky dims and takes the meteor's glow
-- as it approaches, impact dust thickens the fog and settles, and the glow fades
-- once the meteor cracks or cools. Lighting is only written while the look is
-- changing, never while it rests.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local AtmosphereMood = require(ReplicatedStorage.Shared.AtmosphereMood)

type Look = AtmosphereMood.Look

local AtmosphereController = Knit.CreateController({
	Name = "AtmosphereController",
})

local SETTLED = 1e-3

local atmosphere: Atmosphere? = nil
local bloom: BloomEffect? = nil
local grade: ColorCorrectionEffect? = nil
local clouds: Clouds? = nil

-- Missing pieces read as neutral values and are never written
local function readLook(): Look
	return {
		Brightness = Lighting.Brightness,
		Exposure = Lighting.ExposureCompensation,
		Density = if atmosphere then atmosphere.Density else 0,
		Haze = if atmosphere then atmosphere.Haze else 0,
		Glare = if atmosphere then atmosphere.Glare else 0,
		AtmosphereColor = if atmosphere then atmosphere.Color else Color3.new(1, 1, 1),
		AtmosphereDecay = if atmosphere then atmosphere.Decay else Color3.new(1, 1, 1),
		GradeTint = if grade then grade.TintColor else Color3.new(1, 1, 1),
		Saturation = if grade then grade.Saturation else 0,
		Contrast = if grade then grade.Contrast else 0,
		Bloom = if bloom then bloom.Intensity else 0,
		CloudCover = if clouds then clouds.Cover else 0,
		CloudColor = if clouds then clouds.Color else Color3.new(1, 1, 1),
	}
end

local function writeLook(look: Look)
	Lighting.Brightness = look.Brightness
	Lighting.ExposureCompensation = look.Exposure
	if atmosphere then
		atmosphere.Density = look.Density
		atmosphere.Haze = look.Haze
		atmosphere.Glare = look.Glare
		atmosphere.Color = look.AtmosphereColor
		atmosphere.Decay = look.AtmosphereDecay
	end
	if grade then
		grade.TintColor = look.GradeTint
		grade.Saturation = look.Saturation
		grade.Contrast = look.Contrast
	end
	if bloom then
		bloom.Intensity = look.Bloom
	end
	if clouds then
		clouds.Cover = look.CloudCover
		clouds.Color = look.CloudColor
	end
end

function AtmosphereController:KnitStart()
	-- The authored Lighting children must have replicated before the calm look is read
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local bloomEffect = Lighting:FindFirstChild("Bloom")
	bloom = if bloomEffect and bloomEffect:IsA("BloomEffect") then bloomEffect else nil
	local gradeEffect = Lighting:FindFirstChild("Grade")
	grade = if gradeEffect and gradeEffect:IsA("ColorCorrectionEffect") then gradeEffect else nil
	clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")

	local MeteorService = Knit.GetService("MeteorService")
	local calm = readLook()
	local current = calm
	local settled = true
	local impactAt: number? = nil

	MeteorService.Impact:Connect(function()
		impactAt = workspace:GetServerTimeNow()
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		local target = calm
		local state = MeteorService.State:Get()
		if state then
			local now = workspace:GetServerTimeNow()
			local left = math.max(0, state.endsAt - now)
			local sinceImpact = if impactAt then now - impactAt else nil
			local weights = AtmosphereMood.weights(state.phase, left, state.duration or left, sinceImpact)
			-- Studio isolation control (see MeteorFXController): no approach mood either
			if RunService:IsStudio() and ReplicatedStorage:GetAttribute("DevMeteorApproachFX") == false then
				weights.approach = 0
			end
			if weights.approach > 0 or weights.event > 0 or weights.dust > 0 then
				local meteorType = Config.Meteor.Types[state.type] or Config.Meteor.Types.Iron
				target = AtmosphereMood.blend(calm, weights, meteorType.GlowColor)
			end
		end

		if AtmosphereMood.near(current, target, SETTLED) then
			-- Land exactly on the target once, then stay quiet while it holds
			if not settled then
				settled = true
				current = target
				writeLook(current)
			end
			return
		end
		settled = false
		current = AtmosphereMood.lerp(current, target, 1 - math.exp(-Config.Atmosphere.Response * dt))
		writeLook(current)
	end)
end

return AtmosphereController

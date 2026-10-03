--!strict
-- Sky mood rules for meteor events (spec §5.8), tuned in Config.Atmosphere:
--
--   weights   how strongly each layer applies right now, 0..1:
--             approach  rises over the last ApproachLead seconds of the countdown,
--                       then lifts over ApproachClear seconds after impact
--             event     1 while the meteor is down (Impact, Active), fading out
--                       over CoreCracked and Cooled
--             dust      1 at impact, settling over DustSeconds
--   blend     the calm look with the weighted layers added on top, clamped to
--             what Lighting accepts
--   lerp      a step between two looks, for smoothing on the client
--
-- Pure functions, covered by tests/AtmosphereMood.spec; AtmosphereController
-- reads and writes the real Lighting.

local AtmosphereConfig = require(script.Parent.Config.Atmosphere)

export type Look = {
	Brightness: number,
	Exposure: number,
	Density: number,
	Haze: number,
	Glare: number,
	AtmosphereColor: Color3,
	AtmosphereDecay: Color3,
	GradeTint: Color3,
	Saturation: number,
	Contrast: number,
	Bloom: number,
	CloudCover: number,
	CloudColor: Color3,
}

export type Weights = {
	approach: number,
	event: number,
	dust: number,
}

local AtmosphereMood = {}

local NUMBERS = { "Brightness", "Exposure", "Density", "Haze", "Glare", "Saturation", "Contrast", "Bloom", "CloudCover" }
local COLORS = { "AtmosphereColor", "AtmosphereDecay", "GradeTint", "CloudColor" }

local LIMITS: { [string]: { number } } = {
	Brightness = { 0, 10 },
	Exposure = { -3, 3 },
	Density = { 0, 1 },
	Haze = { 0, 10 },
	Glare = { 0, 10 },
	Saturation = { -1, 1 },
	Contrast = { -1, 1 },
	Bloom = { 0, 10 },
	CloudCover = { 0, 1 },
}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function darker(color: Color3, amount: number): Color3
	return Color3.new(color.R * amount, color.G * amount, color.B * amount)
end

-- phase: the meteor phase; secondsLeft / phaseLength: time left in it and its full
-- length; sinceImpact: seconds since this client saw the impact (nil if it didn't)
function AtmosphereMood.weights(phase: string, secondsLeft: number, phaseLength: number, sinceImpact: number?, tuning: any?): Weights
	local config = tuning or AtmosphereConfig
	local weights = { approach = 0, event = 0, dust = 0 }

	if phase == "Countdown" then
		if secondsLeft <= config.ApproachLead then
			weights.approach = smooth(1 - secondsLeft / config.ApproachLead)
		end
		return weights
	end

	if sinceImpact and sinceImpact >= 0 then
		weights.approach = 1 - smooth(sinceImpact / config.ApproachClear)
		local settle = math.clamp(1 - sinceImpact / config.DustSeconds, 0, 1)
		weights.dust = settle * settle
	end

	if phase == "Impact" or phase == "Active" then
		weights.event = 1
	elseif (phase == "CoreCracked" or phase == "Cooled") and phaseLength > 0 then
		weights.event = smooth(secondsLeft / phaseLength)
	end
	return weights
end

-- The calm look with each layer added at its weight. Approach and Event tint toward
-- the meteor's glow colour, Dust toward Config.Atmosphere.DustColor.
function AtmosphereMood.blend(base: Look, weights: Weights, glow: Color3, tuning: any?): Look
	local config = tuning or AtmosphereConfig
	local look = table.clone(base)
	local layers = {
		{ config.Approach, weights.approach, glow },
		{ config.Event, weights.event, glow },
		{ config.Dust, weights.dust, config.DustColor },
	}
	for _, entry in layers do
		local layer, weight, color = entry[1], entry[2] :: number, entry[3] :: Color3
		if weight <= 0 then
			continue
		end
		for _, key in NUMBERS do
			local offset = layer[key]
			if offset then
				(look :: any)[key] += offset * weight
			end
		end
		local tint = (layer.AtmosphereTint or 0) * weight
		look.AtmosphereColor = look.AtmosphereColor:Lerp(color, tint)
		-- Decay colours the whole sky away from the sun, so it takes half the tint
		look.AtmosphereDecay = look.AtmosphereDecay:Lerp(darker(color, 0.55), tint * 0.5)
		look.GradeTint = look.GradeTint:Lerp(color, (layer.GradeTint or 0) * weight)
		look.CloudColor = look.CloudColor:Lerp(config.CloudShadeColor, (layer.CloudShade or 0) * weight)
	end
	for key, range in LIMITS do
		(look :: any)[key] = math.clamp((look :: any)[key], range[1], range[2])
	end
	return look
end

function AtmosphereMood.lerp(a: Look, b: Look, alpha: number): Look
	local look = table.clone(a)
	for _, key in NUMBERS do
		(look :: any)[key] = (a :: any)[key] + ((b :: any)[key] - (a :: any)[key]) * alpha
	end
	for _, key in COLORS do
		(look :: any)[key] = ((a :: any)[key] :: Color3):Lerp((b :: any)[key], alpha)
	end
	return look
end

-- Whether two looks differ by less than epsilon in every value (colour channels 0..1)
function AtmosphereMood.near(a: Look, b: Look, epsilon: number): boolean
	for _, key in NUMBERS do
		if math.abs((a :: any)[key] - (b :: any)[key]) > epsilon then
			return false
		end
	end
	for _, key in COLORS do
		local x: Color3, y: Color3 = (a :: any)[key], (b :: any)[key]
		if math.abs(x.R - y.R) > epsilon or math.abs(x.G - y.G) > epsilon or math.abs(x.B - y.B) > epsilon then
			return false
		end
	end
	return true
end

return AtmosphereMood

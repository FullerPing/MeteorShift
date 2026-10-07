--!strict
-- Sky moods during a meteor event (spec §5.8). The calm look is authored in the
-- place: Lighting, its Atmosphere, Bloom and Grade, and Terrain.Clouds (see
-- tools/atmosphere/author-lighting.luau). AtmosphereController reads those values
-- when you join and blends the layers below on top of them; Shared.AtmosphereMood
-- holds the rules. Each layer's numbers are what it adds at full strength.

export type Layer = {
	Brightness: number?, -- added to Lighting.Brightness
	Exposure: number?, -- added to Lighting.ExposureCompensation
	Density: number?, -- added to the Atmosphere's Density (fog thickness)
	Haze: number?, -- added to the Atmosphere's Haze
	Glare: number?, -- added to the Atmosphere's Glare
	AtmosphereTint: number?, -- 0..1: how far the fog's Color and Decay move toward the layer's colour
	GradeTint: number?, -- 0..1: how far the Grade's TintColor moves toward the layer's colour
	Saturation: number?, -- added to the Grade's Saturation
	Contrast: number?, -- added to the Grade's Contrast
	Bloom: number?, -- added to the Bloom's Intensity
	CloudCover: number?, -- added to Terrain.Clouds.Cover
	CloudShade: number?, -- 0..1: how far the clouds darken toward CloudShadeColor
}

local Atmosphere = {}

Atmosphere.ApproachLead = 25 -- the sky starts to turn this many seconds before impact
Atmosphere.ApproachClear = 8 -- after impact, the approach gloom lifts over this many seconds
Atmosphere.DustSeconds = 12 -- the impact dust settles over this many seconds
Atmosphere.Response = 2.5 -- how quickly the lighting chases its target, per second (higher is snappier)

Atmosphere.DustColor = Color3.fromRGB(196, 168, 136) -- sandy, to read against the bright daylight sky
Atmosphere.CloudShadeColor = Color3.fromRGB(112, 108, 132)

-- The meteor coming in: the light dims, clouds gather and the haze takes on the
-- meteor type's glow colour (Iron orange, Ice cyan, Crystal magenta)
Atmosphere.Approach = {
	Brightness = -0.8,
	Exposure = -0.35,
	Density = 0.05,
	Haze = 0.5,
	Glare = 0.3,
	AtmosphereTint = 0.35,
	GradeTint = 0.1,
	Saturation = 0.1,
	Contrast = 0.08,
	CloudCover = 0.3,
	CloudShade = 0.6,
} :: Layer

-- The meteor on the ground: a glow in the haze until it cracks or cools
Atmosphere.Event = {
	Density = 0.02,
	Haze = 0.2,
	AtmosphereTint = 0.3,
	GradeTint = 0.05,
	Bloom = 0.2,
} :: Layer

-- Impact dust: thick brown fog that settles over DustSeconds
Atmosphere.Dust = {
	Density = 0.1,
	Haze = 1.2,
	AtmosphereTint = 0.45,
	GradeTint = 0.06,
	Saturation = -0.08,
} :: Layer

return Atmosphere

--!strict
-- Extra spectacle on top of every meteor landing (ImpactFXController): a light pillar, rolling
-- shock rings, a rim of dust puffs, a spray of chips and embers, a glowing pool that cools, a bloom
-- pulse and a small FOV punch, plus a burst and a falling "rain" in each meteor type's own style.
-- Colours of the type come from Config.Meteor.Types; this holds sizes, counts and timings.
-- Counts are multiplied by Mobile.Scale on touch-only devices, and everything is skipped when the
-- ReduceEffects setting is on. Seconds are measured from impact.

export type Burst = {
	Count: number,
	Speed: { number },
	Size: { number },
	Lifetime: { number },
	Accel: Vector3,
	Colors: { Color3 },
	LightEmission: number,
	Spread: number?,
	Drag: number?,
}
export type Rain = {
	Rate: number,
	Seconds: number,
	Height: number,
	Area: number,
	Size: { number },
	Lifetime: { number },
	Accel: Vector3,
	Colors: { Color3 },
	LightEmission: number,
}
export type Flavor = { Burst: Burst?, Rain: Rain? }

local ImpactFX = {}

ImpactFX.Mobile = { Scale = 0.5 }

ImpactFX.Pillar = { Height = 280, Radius = 7, Seconds = 1.5, Transparency = 0.25 }
ImpactFX.Light = { Range = 130, Brightness = 9, Seconds = 1.4, Lift = 12 }
-- Three thin neon rings rolling out across the crater floor
ImpactFX.Rings = {
	{ Delay = 0, Seconds = 1.0, ToDiameter = 112, Thickness = 0.5, Transparency = 0.1 },
	{ Delay = 0.16, Seconds = 1.2, ToDiameter = 108, Thickness = 0.4, Transparency = 0.25 },
	{ Delay = 0.34, Seconds = 1.4, ToDiameter = 104, Thickness = 0.3, Transparency = 0.4 },
}
-- Dust thrown up around the bowl as the shock reaches it
ImpactFX.Rim = { Count = 10, Radius = 70, Delay = 0.28, Puffs = 7, Height = 12 }
ImpactFX.Chips = { Count = 40, Speed = { 55, 115 }, Size = { 2.4, 0 }, Lifetime = { 1.6, 2.6 }, Gravity = -115 }
ImpactFX.Embers = { Count = 55, Speed = { 22, 75 }, Size = { 1.3, 0 }, Lifetime = { 2, 3.6 }, Gravity = -26 }
-- A glowing pool left on the floor that cools off as the meteor does
ImpactFX.Pool = { Diameter = 84, Thickness = 0.3, Transparency = 0.45, Seconds = 45 }
ImpactFX.Bloom = { Intensity = 1.3, Size = 42, Threshold = 0.85, Seconds = 1.7 }
-- Degrees the camera widens by at the crater, easing back (skipped with Reduce Camera Shake)
ImpactFX.Fov = { Punch = 9, In = 0.07, Out = 0.9 }
-- Extra confetti when the meteor is golden
ImpactFX.Golden = {
	Burst = { Count = 70, Speed = { 30, 95 }, Size = { 1.6, 0 }, Lifetime = { 1.8, 3 }, Accel = Vector3.new(0, -48, 0),
		Colors = { Color3.fromRGB(255, 236, 140), Color3.fromRGB(255, 190, 40) }, LightEmission = 0.9 } :: Burst,
	Scale = 1.3, -- every count above is multiplied for a golden meteor
}

ImpactFX.Types = {
	-- Molten sparks and a fall of embers
	Iron = {
		Burst = { Count = 46, Speed = { 40, 120 }, Size = { 0.9, 0 }, Lifetime = { 1.2, 2.2 }, Accel = Vector3.new(0, -70, 0),
			Colors = { Color3.fromRGB(255, 210, 110), Color3.fromRGB(255, 96, 28) }, LightEmission = 1, Drag = 0.3 },
		Rain = { Rate = 22, Seconds = 6, Height = 70, Area = 120, Size = { 0.9, 0 }, Lifetime = { 2.2, 3.4 },
			Accel = Vector3.new(0, -18, 0), Colors = { Color3.fromRGB(255, 170, 70), Color3.fromRGB(150, 40, 10) }, LightEmission = 1 },
	} :: Flavor,
	-- A burst of snow and glittering ice
	Ice = {
		Burst = { Count = 70, Speed = { 25, 85 }, Size = { 1.5, 0 }, Lifetime = { 1.6, 2.8 }, Accel = Vector3.new(0, -34, 0),
			Colors = { Color3.fromRGB(240, 252, 255), Color3.fromRGB(110, 210, 255) }, LightEmission = 0.5, Drag = 1 },
		Rain = { Rate = 28, Seconds = 8, Height = 60, Area = 130, Size = { 1.1, 0.4 }, Lifetime = { 3, 4.6 },
			Accel = Vector3.new(0, -9, 0), Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 226, 255) }, LightEmission = 0.4 },
	} :: Flavor,
	-- Prismatic sparkles that hang in the air
	Crystal = {
		Burst = { Count = 64, Speed = { 25, 90 }, Size = { 1.7, 0 }, Lifetime = { 1.8, 3 }, Accel = Vector3.new(0, -20, 0),
			Colors = { Color3.fromRGB(255, 120, 230), Color3.fromRGB(150, 130, 255), Color3.fromRGB(110, 230, 255) }, LightEmission = 1, Drag = 0.8 },
		Rain = { Rate = 16, Seconds = 8, Height = 45, Area = 110, Size = { 1.2, 0 }, Lifetime = { 2.4, 3.6 },
			Accel = Vector3.new(0, -4, 0), Colors = { Color3.fromRGB(255, 150, 240), Color3.fromRGB(120, 235, 255) }, LightEmission = 1 },
	} :: Flavor,
	-- Spores that rise instead of fall
	Alien = {
		Burst = { Count = 60, Speed = { 18, 70 }, Size = { 2, 0.4 }, Lifetime = { 2.2, 3.8 }, Accel = Vector3.new(0, 14, 0),
			Colors = { Color3.fromRGB(190, 255, 170), Color3.fromRGB(60, 230, 130) }, LightEmission = 0.9, Drag = 1.2 },
		Rain = { Rate = 18, Seconds = 9, Height = 2, Area = 100, Size = { 1.3, 0 }, Lifetime = { 3, 5 },
			Accel = Vector3.new(0, 10, 0), Colors = { Color3.fromRGB(120, 255, 170), Color3.fromRGB(40, 190, 110) }, LightEmission = 1 },
	} :: Flavor,
}

return ImpactFX

--!strict
-- Crater-floor scenes that live as long as a meteor is down (SurfaceFXController; layout rules in
-- Shared.SurfaceLayout). Alien gets the showpiece, Iron a molten scene, Ice and Crystal a lighter
-- extra on top of LandingFXController's ground art. Radii are studs from the meteor's centre: the
-- meteor itself fills about the first 38, the flat floor ends at 55 and the bowl climbs to 83.
-- Colours of each type's glow come from Config.Meteor.Types. Everything is looks only, built under the
-- camera, and skipped by the Reduce Effects setting; touch-only devices get Mobile.Scale of the counts.

local SurfaceFX = {}

SurfaceFX.Mobile = { Scale = 0.5 }
SurfaceFX.FadeIn = 1.4 -- seconds a scene takes to appear
SurfaceFX.FadeOut = 2.2 -- and to fade when the meteor cools
SurfaceFX.Lift = 0.5 -- how far above the ground flat parts float

SurfaceFX.Alien = {
	Spore = Color3.fromRGB(190, 255, 170),
	Deep = Color3.fromRGB(20, 120, 80),
	-- A pale green column from the meteor's core to the sky, with a wider halo
	Pillar = { Height = 230, Radius = 3.2, Halo = 9, Transparency = { 0.4, 0.78 }, Period = 2.4 },
	Light = { Range = 80, Brightness = { 1.5, 4.2 }, Period = 1.6, Lift = 30 },
	-- Rings that swell out of the meteor and fade, again and again
	Pulses = { Count = 3, Gap = 1.1, Seconds = 3.4, From = 76, To = 156, Thickness = 0.3 },
	-- Tendrils crawling in from the rim to the meteor, throbbing with a travelling pulse
	Tendrils = { Count = 9, From = 80, To = 40, Steps = 6, Width = { 0.45, 1.5 }, Period = 1.5, Bend = 9, Lift = 0.8 },
	-- Rocks that have lost their weight
	Rocks = { Count = 9, Radius = { 42, 64 }, Height = { 12, 38 }, Size = { 3, 7 }, Bob = 3, Period = { 3, 5 } },
	Updraft = { Rate = 30, Area = 96, Lifetime = { 4, 6 }, Speed = { 3, 7 } },
	-- Arms of spores spiralling up round the meteor
	Vortex = { Arms = 3, Radius = 50, Height = { 6, 20 }, Seconds = 9, Rate = 34, Rise = 9 },
	-- When the core cracks: a dome, quick rings and the rocks drop
	Finale = { Dome = { From = 40, To = 200, Seconds = 1.3 }, Rings = 4, RingGap = 0.12, Fall = 1.2 },
}

SurfaceFX.Iron = {
	Lava = Color3.fromRGB(255, 120, 30),
	Hot = Color3.fromRGB(255, 214, 110),
	Dark = Color3.fromRGB(86, 52, 40),
	-- Glowing cracks running out across the floor, each flickering by itself
	Cracks = { Count = 11, From = 40, To = 76, Steps = 6, Width = 0.8, Bend = 7, Flicker = { 0.15, 0.6 }, Period = { 0.6, 1.5 } },
	-- Vents on the floor breathing smoke and sparks
	Vents = { Count = 4, Radius = 56, Smoke = 6, Sparks = 5 },
	Updraft = { Rate = 16, Area = 90, Lifetime = { 3, 5 }, Speed = { 4, 9 } },
	Light = { Range = 80, Brightness = { 1.4, 3.2 }, Period = 0.9, Lift = 24 },
	Finale = { Geyser = 90, Ring = { From = 40, To = 170, Seconds = 1 } },
}

SurfaceFX.Ice = {
	Halo = { Count = 2, Gap = 2.2, Seconds = 4.5, From = 80, To = 150, Thickness = 0.25 },
	Glints = { Rate = 16, Area = 100, Lifetime = { 2.5, 4 }, Speed = { 1, 3 } },
}

SurfaceFX.Crystal = {
	-- Slow light shafts round the crater in prism colours
	Shafts = { Count = 6, Radius = 62, Height = 95, Width = 1.6, Transparency = { 0.68, 0.9 }, Period = { 2.4, 4 },
		Colors = { Color3.fromRGB(255, 120, 230), Color3.fromRGB(150, 130, 255), Color3.fromRGB(110, 230, 255) } },
}

return SurfaceFX

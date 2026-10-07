--!strict
-- Ice and Crystal landing effects (LandingFXController, Shared.LandingFX). Colours come
-- from Config.Meteor.Types; this holds sizes, counts and timings. Times are seconds since
-- impact unless noted; angles are degrees, bearing = atan2(z, x) from the crater centre.
local LandingFX = {}
LandingFX.MaxParts = 160 -- per event; the spec checks budget() against it
LandingFX.BuildPerFrame = 40 -- instances created per frame while building
LandingFX.Crater = {
	Center = Vector3.new(0, -1.25, 0), -- original landing height; doubled shell is partially buried
	FloorY = -14.755, FloorRadius = 55.25, OpeningRadius = 83.2, RimY = 0,
	FloorProbeRadius = 42, FloorProbes = 8, FloorProbesNeeded = 3,
	ProbeHeight = 100, ProbeDepth = 160, ProbeTolerance = 12,
	LineStartRadius = 52, -- doubled crust envelope
	VerticalClearRadius = 85.2, -- upright props remain outside mining access
}
-- Cardinal crater approaches stay clear of upright pieces; world props are avoided too.
LandingFX.Corridors = {
	{ Angle = 0, Half = 12 }, { Angle = 90, Half = 12 }, { Angle = 180, Half = 12 }, { Angle = 270, Half = 12 },
}
LandingFX.Obstacles = { Padding = 4, RetryDegrees = { 0, 4, -4, 8, -8, 12, -12, 16, -16 } }
LandingFX.Strip = { Thickness = 0.2, Lift = 0.1, StartLength = 0.05 }
LandingFX.FlatLift = 0.02
LandingFX.Sink = 1
LandingFX.FlowBeams = { Enabled = true, Height = 0.35, Width = 1, TextureLength = 4, Transparency = 0.35 }
LandingFX.Burst = { Eruption = 14, Shatter = 24, LateGrace = 0.25 }
LandingFX.Exit = {
	ShatterSeconds = 0.35, ShatterRipple = 0.03, SproutRipple = 0.02, ShatterScale = 0.3,
	LineFlash = 0.15, LineFade = 1.5, BeamCut = 0.25, LightsOut = 0.4, GemFlash = 0.5,
	WitherRecolor = 1.5, InertBlend = 0.6, ArcStep = 0.1, ArcOut = 0.3,
	SinkDelay = 1, SinkSeconds = 3, FadeDelay = 1.5, FadeSeconds = 2.5,
}
LandingFX.Mobile = { Satellites = 1, FlowBeams = false, ParticleScale = 0.5, Mist = false, Lights = 0 }
LandingFX.SoundRanks = { 1, 4, 7 }
LandingFX.Types = {
	Ice = {
		Sound = "FrostCrackle",
		Sheet = { Enabled = true, Diameter = 108, StartDiameter = 52, Thickness = 0.15, Lift = 0.09, Transparency = 0.35, Start = 0.1, Seconds = 0.9 },
		Shimmer = { Enabled = false },
		Clusters = { Count = 8, Radii = { 90, 92, 94 }, Footprint = 6, MinSpacing = 22,
			Height = { 20, 28 }, Width = { 4.5, 6.5 }, Thickness = { 1.2, 1.6 }, Lean = { 6, 14 }, Yaw = { 0, 90 },
			Transparency = 0.25, Core = { Width = 0.5, Length = 0.7 },
			Satellites = 2, SatelliteHeight = { 0.35, 0.55 }, SatelliteWidth = 0.55, SatelliteThickness = { 0.8, 1.1 },
			SatelliteLean = { 8, 16 }, SatelliteYaw = { 25, 55 }, Out = { 1.5, 3 }, Side = { 2.5, 4 },
			After = 0.05, Rise = 0.45, SatelliteDelay = 0.1, SatelliteRise = 0.4, WhiteBlend = 0.35 },
		Cracks = { Radii = { 52, 62, 70, 78 }, Beyond = { 14, 28 }, Kink = { 2, 5 }, Width = { 1.1, 0.5 },
			Transparency = 0.1, Delay = 0.15, Seconds = 1.6, FlowSegments = { 1, 5, 6 }, FlowSpeed = 1, UnlockWhiten = 0.35, UnlockSeconds = 0.5 },
		Fingers = { Count = 12, Inner = 85, Length = { 24, 38 }, Width = { 7, 11 }, Thickness = 0.1, Jitter = 8,
			Color = Color3.fromRGB(226, 240, 250), Start = 0.5, Stagger = 0.03, Burst = 0.4, BurstSeconds = 0.6 },
		Snow = { Rate = 16, Area = 130, Height = 36, Start = 1 },
		Mist = { Rate = 3, Area = 84, Lift = 1.2, Start = 1.5 },
		Rime = { Enabled = true, Max = 6, Hold = 1.2, Tick = 0.2, Rate = 14, Scale = 1.1 },
	},
	Crystal = {
		Sound = "CrystalChime",
		Shimmer = { Enabled = true, Diameter = 106, StartDiameter = 52, Thickness = 0.1, Lift = 0.12,
			Transparency = { 0.55, 0.7 }, Start = 0.3, Seconds = 2.5, Breath = 2 },
		Clusters = { Count = 8, Radii = { 90, 92, 94 }, Footprint = 6, MinSpacing = 24,
			Height = { 16, 24 }, Width = { 4, 5.5 }, Lean = { 6, 14 }, Yaw = { 0, 90 }, Transparency = 0.25,
			TipScale = 0.9, Spine = { Width = 0.35, Length = 0.85 },
			Satellites = 2, SatelliteHeight = { 6, 11 }, SatelliteWidth = { 1.6, 2.4 }, SatelliteLean = { 20, 35 },
			Out = { 1.5, 3 }, Side = { 2.5, 4 }, Stagger = 0.04, Rise = 0.5, EmergeTo = 0.65, GrowSeconds = 120,
			SatelliteDelay = 0.12, SatelliteRise = 0.4 },
		Spokes = { Radii = { 52, 62, 70, 78 }, Width = 0.9, Delay = 0.1, Seconds = 0.8, FlowSpeed = 1.5 },
		Circle = { Radius = 85, Sides = 16, Width = 0.7, Start = 1, Step = 0.06, Grow = 0.1, From = 90 },
		Rays = { Gap = 8, To = 124, Width = 0.5, Start = 1.3, Stagger = 0.03, Seconds = 0.5 },
		Sprouts = { Count = 12, Radii = { { 90, 86, 94 }, { 100, 96, 104 } }, Footprint = 2, MinSpacing = 10,
			Height = { 3, 6 }, Width = { 1, 1.6 }, Lean = { 8, 20 }, Rise = 0.5, Burst = 6 },
		Arcs = { MaxGap = 80, RingWidth = 0.8, RingCurve = 6, RingStart = 1.9, RingStep = 0.06, RingIgnite = 0.35,
			CrownWidth = { 1.2, 0.5 }, CrownCurve = { 8, 6 }, CrownStart = 2.45, CrownStep = 0.03, CrownIgnite = 0.3,
			Brightness = { 1.5, 3 }, TextureSpeed = 2.5, TextureLength = 3, Segments = 12, Transparency = 0.15 },
		Gem = { Height = 62, Size = 3, Pulse = { 3, 3.6 }, UnlockedPulse = { 4, 4.8 }, PulseSeconds = 1.2, Start = 2.3, Pop = 0.35, Sparkles = 6 },
		Motes = { Rate = 10, Area = 90, Lift = 1, Start = 1 },
		Lights = { Ranks = { 1, 3, 5, 7 }, Range = 18, Brightness = { 0.6, 1.2 }, Start = 1.2, FadeIn = 0.8, Breath = 2.4 },
	},
}
return LandingFX

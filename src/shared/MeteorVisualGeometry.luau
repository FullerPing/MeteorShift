--!strict
-- Linear spectacle dimensions. Counts, lifetimes, camera angles and gameplay
-- impulses stay in the controller; the configured knockback radius is already scaled.
local MeteorVisualGeometry = {}

function MeteorVisualGeometry.build(scale: number, knockbackRadius: number)
	return {
		Streak = {
			Offset = Vector3.new(-420, 520, 260) * scale,
			StartSize = Vector3.one * (16 * scale),
			EndSize = Vector3.one * (22 * scale),
			TrailTop = Vector3.new(0, 6, 0) * scale,
			TrailBottom = Vector3.new(0, -6, 0) * scale,
			LightRange = 60 * scale,
			FlameSize = NumberSequence.new(30 * scale, 6 * scale),
			FlameSpeed = NumberRange.new(12 * scale, 25 * scale),
			SmokeSize = NumberSequence.new(8 * scale, 20 * scale),
			SmokeSpeed = NumberRange.new(2 * scale, 5 * scale),
		},
		Impact = {
			RingOffset = Vector3.new(0, -4, 0) * scale,
			RingStartSize = Vector3.new(1, 8, 8) * scale,
			RingEndSize = Vector3.new(scale, knockbackRadius * 2, knockbackRadius * 2),
			FlashStartSize = Vector3.one * (10 * scale),
			FlashEndSize = Vector3.one * (70 * scale),
			DustAnchorSize = Vector3.new(40, 1, 40) * scale,
			DustSize = NumberSequence.new(8 * scale, 26 * scale),
			DustSpeed = NumberRange.new(20 * scale, 45 * scale),
		},
		Core = {
			StartSize = Vector3.one * (14 * scale),
			EndSize = Vector3.one * (60 * scale),
			ShardsSize = NumberSequence.new(1.2 * scale, 0),
			ShardsSpeed = NumberRange.new(40 * scale, 80 * scale),
			ShardsAcceleration = Vector3.new(0, -50, 0) * scale,
		},
		Shake = {
			ImpactRadius = 250 * scale,
			CoreRadius = 200 * scale,
		},
		Sound = {
			minDistance = 10 * scale,
			maxDistance = 1000 * scale,
		},
	}
end

function MeteorVisualGeometry.falloff(distance: number, radius: number): number
	return math.clamp(1 - distance / radius, 0, 1)
end

return MeteorVisualGeometry

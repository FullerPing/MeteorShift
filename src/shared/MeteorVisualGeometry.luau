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

-- Height of the visible outer shockfront. The meteor's centre may be elevated;
-- its Y is deliberately excluded from the crater's ground profile.
function MeteorVisualGeometry.groundHeight(radius: number, crater: any): number
	local slope = math.clamp((radius-crater.FloorRadius)/(crater.OpeningRadius-crater.FloorRadius), 0, 1)
	return crater.FloorY + (crater.RimY-crater.FloorY)*slope
end

function MeteorVisualGeometry.groundRingPosition(impact: Vector3, radius: number, thickness: number, crater: any, samples: any?): Vector3
	local y = MeteorVisualGeometry.groundHeight(radius,crater)
	if samples and #samples > 0 and radius >= samples[1].radius and radius <= samples[#samples].radius then
		y = samples[#samples].y
		for i, sample in samples do
			if radius <= sample.radius then
				local previous = samples[math.max(1,i-1)]
				local span = sample.radius-previous.radius
				local alpha = if span > 0 then math.clamp((radius-previous.radius)/span,0,1) else 0
				y = previous.y+(sample.y-previous.y)*alpha
				break
			end
		end
	end
	return Vector3.new(impact.X,y+thickness/2+.04,impact.Z)
end

return MeteorVisualGeometry

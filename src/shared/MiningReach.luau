--!strict
-- How far a swing reaches (spec §12.2). The distance is from the character's root to the nearest point of the
-- target's box. Meteor targets also count the swing from the root raised by up to `lift` studs
-- (Config.Meteor.UpwardReach): the 2x meteor's crown sits well above head height over the crater floor, and
-- without this its top crust nodes can't be hit from anywhere a player can stand. NodeService checks every swing
-- with it and MiningController aims with it, so the two always agree.

local MiningReach = {}

-- Studs from `point` to the nearest point of a box at `cframe` with `size` (0 inside it).
local function boxDistance(cframe: CFrame, size: Vector3, point: Vector3): number
	local l = cframe:PointToObjectSpace(point)
	local h = size / 2
	local clamped = Vector3.new(math.clamp(l.X, -h.X, h.X), math.clamp(l.Y, -h.Y, h.Y), math.clamp(l.Z, -h.Z, h.Z))
	return (l - clamped).Magnitude
end

-- The swing distance: the box distance from `point`, or from anywhere up to `lift` studs above it if that is
-- nearer. The distance along that vertical segment is convex, so a golden-section search finds its minimum.
function MiningReach.distance(cframe: CFrame, size: Vector3, point: Vector3, lift: number): number
	local best = boxDistance(cframe, size, point)
	if lift <= 0 or best == 0 then
		return best
	end
	local function at(k: number): number
		return boxDistance(cframe, size, point + Vector3.new(0, k, 0))
	end
	local lo, hi = 0, lift
	local ratio = (math.sqrt(5) - 1) / 2
	local a, b = hi - ratio * (hi - lo), lo + ratio * (hi - lo)
	local fa, fb = at(a), at(b)
	for _ = 1, 30 do
		if fa < fb then
			hi, b, fb = b, a, fa
			a = hi - ratio * (hi - lo)
			fa = at(a)
		else
			lo, a, fa = a, b, fb
			b = lo + ratio * (hi - lo)
			fb = at(b)
		end
	end
	return math.min(best, fa, fb, at(lift))
end

-- The upward reach a target of `kind` (its TargetKind) gets: meteor crust and core only.
function MiningReach.lift(kind: string?, upward: number): number
	return if kind == "Crust" or kind == "Core" then upward else 0
end

return MiningReach

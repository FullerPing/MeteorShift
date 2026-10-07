--!strict
-- The compact world's 125-stud contract applies to persistent landing geometry,
-- not airborne particles. Exercise the real layout and shape helpers; transform
-- every box corner rather than checking only the configured anchor radii.
-- Ground uses the controller's fallback profile in a local crater frame. Live
-- terrain hits and rime hosts assigned to actual meteor nodes need runtime QA.

return function(t: any)
	local LandingFX = require(t.shared.LandingFX)
	local Tuning = require(t.shared.Config.LandingFX)
	local LIMIT, EPSILON, SEEDS = 125, 1e-3, 40
	local crater = Tuning.Crater
	local center = crater.Center

	local function radius(point: Vector3): number
		return Vector2.new(point.X - center.X, point.Z - center.Z).Magnitude
	end

	local function checkPoint(point: Vector3, halfWidth: number, label: string)
		local reach = radius(point) + halfWidth
		t.ok(reach <= LIMIT + EPSILON, string.format("%s reaches %.5f; compact limit is %d", label, reach, LIMIT))
	end

	local function ground(x: number, z: number, lift: number?): Vector3
		local r = Vector2.new(x, z).Magnitude
		local y = LandingFX.groundY(r, crater.FloorY, crater.RimY, crater.FloorRadius, crater.OpeningRadius)
		return Vector3.new(center.X + x, y + (lift or 0), center.Z + z)
	end

	local function outward(x: number, z: number): Vector3
		local flat = Vector3.new(x, 0, z)
		return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
	end

	local function checkCorners(cf: CFrame, size: Vector3, label: string)
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					checkPoint(cf * Vector3.new(x * size.X / 2, y * size.Y / 2, z * size.Z / 2), 0, label)
				end
			end
		end
	end

	local function checkPiece(piece: any, label: string, axis: Vector3?, depth: number?)
		checkCorners(piece.cf, piece.size, label .. " final")
		if axis and depth then
			checkCorners(LandingFX.buried(piece.cf, axis, depth), piece.size, label .. " buried")
		end
		-- Rise, growth and wither translate along one axis. Each corner's XZ
		-- path is a line segment, so its maximum radius is at one endpoint.
	end

	local function checkBeam(a: Vector3, b: Vector3, width: number, curve0: number, curve1: number, label: string)
		-- Upright arc attachments point their X axes along world Y. Their
		-- Bezier controls therefore have the endpoints' XZ coordinates.
		-- The control hull plus half-width bounds every FaceCamera orientation.
		for _, point in { a, a + Vector3.yAxis * curve0, b - Vector3.yAxis * curve1, b } do
			checkPoint(point, width / 2, label)
		end
	end

	local function checkLine(line: any, label: string)
		for k = 1, #line.points - 1 do
			local a, b = line.points[k], line.points[k + 1]
			local from, to = ground(a.X, a.Y), ground(b.X, b.Y)
			for _, alpha in { 0, 1 } do
				local cf, size = LandingFX.stripAt(from, to, alpha, line.widths[k], Tuning.Strip.Thickness, Tuning.Strip.Lift)
				checkCorners(cf, size, label .. " strip " .. k)
			end
			if line.flow[k] == true or table.find(line.flow, k) then
				local att0 = ground(a.X, a.Y, Tuning.FlowBeams.Height)
				local att1 = ground(b.X, b.Y, Tuning.FlowBeams.Height)
				checkPoint(att0, 0, label .. " flow anchor")
				checkPoint(att1, 0, label .. " flow anchor")
				checkBeam(att0, att1, Tuning.FlowBeams.Width, 0, 0, label .. " flow width")
			end
		end
	end

	local function checkPrism(frame: CFrame, item: any, spec: any, withSpine: boolean, label: string): Vector3
		local shape = LandingFX.prism(frame, item.height, item.width, spec.TipScale, spec.Spine, Tuning.Sink)
		checkPiece(shape.body, label .. " body", frame.UpVector, item.depth)
		checkPiece(shape.tip, label .. " tip", frame.UpVector, item.depth)
		if withSpine then
			checkPiece(shape.spine, label .. " spine", frame.UpVector, item.depth)
		end
		checkPoint(shape.top, 0, label .. " top attachment")
		checkPoint(shape.top - frame.UpVector * item.depth, 0, label .. " buried top attachment")
		return shape.top
	end

	local function checkFlat(spec: any, label: string)
		if not spec.Enabled then return end
		local cf = CFrame.new(center.X, crater.FloorY + spec.Lift, center.Z) * CFrame.Angles(0, 0, math.pi / 2)
		for _, diameter in { spec.StartDiameter, spec.Diameter } do
			checkCorners(cf, Vector3.new(spec.Thickness, diameter, diameter), label)
		end
	end

	local function checkHost(area: number, position: Vector3, label: string)
		checkCorners(CFrame.new(position), Vector3.new(area, 1, area), label)
	end

	local function checkLayout(typeId: string, seed: number, mobile: boolean)
		local layout = LandingFX.layout(typeId, LandingFX.seed(seed, typeId), {}, mobile) :: any
		local fx = (Tuning.Types :: any)[typeId]
		local spec = fx.Clusters
		local label = typeId .. (if mobile then " mobile" else " desktop") .. " seed " .. seed
		t.ok(layout, label .. " layout missing")
		t.eq(#layout.clusters, 8, label .. " all heroes must be checked")
		local satellites = if mobile then 1 else 2
		local tips: { Vector3 } = {}

		-- The controller's invisible root anchor is at world origin; this
		-- fixture keeps the approved crater XZ origin and checks its corners.
		checkCorners(CFrame.identity, Vector3.one, label .. " root anchor")
		for rank, cluster in layout.clusters do
			local base = ground(cluster.x, cluster.z)
			local direction = outward(cluster.x, cluster.z)
			local frame = LandingFX.pieceFrame(base, direction, cluster.lean, cluster.yaw)
			local heroLabel = label .. " hero " .. rank
			t.eq(#cluster.satellites, satellites, heroLabel .. " satellite coverage")
			if typeId == "Ice" then
				for _, piece in LandingFX.star(frame, cluster.height, cluster.width, cluster.thickness, Tuning.Sink) do
					checkPiece(piece, heroLabel .. " star", frame.UpVector, cluster.depth)
				end
				local length = spec.Core.Length * cluster.height
				checkPiece({ cf = frame * CFrame.new(0, length / 2 - Tuning.Sink, 0), size = Vector3.new(spec.Core.Width, length, spec.Core.Width) }, heroLabel .. " core", frame.UpVector, cluster.depth)
			else
				tips[rank] = checkPrism(frame, cluster, spec, true, heroLabel)
			end
			checkPoint(base + Vector3.new(0, 1.5, 0), 0, heroLabel .. " eruption anchor")
			checkPoint((frame * CFrame.new(0, cluster.height / 2 - Tuning.Sink, 0)).Position, 0, heroLabel .. " shatter anchor")
			for index, satellite in cluster.satellites do
				local satFrame = LandingFX.pieceFrame(ground(satellite.x, satellite.z), direction, satellite.lean, satellite.yaw)
				local satLabel = heroLabel .. " satellite " .. index
				if typeId == "Ice" then
					for _, piece in LandingFX.blade(satFrame, satellite.height, satellite.width, satellite.thickness, Tuning.Sink) do
						checkPiece(piece, satLabel, satFrame.UpVector, satellite.depth)
					end
				else
					checkPrism(satFrame, satellite, spec, false, satLabel)
				end
			end
		end

		for _, list in { layout.cracks, layout.spokes, layout.circle, layout.rays } do
			for index, line in list do checkLine(line, label .. " line " .. index) end
		end
		if typeId == "Ice" then
			t.eq(#layout.cracks, 8, label .. " crack coverage")
			t.eq(#layout.fingers, 12, label .. " finger coverage")
			checkFlat(fx.Sheet, label .. " glaze")
			for index, finger in layout.fingers do
				local angle = math.rad(finger.angle)
				local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
				local inner = ground(direction.X * fx.Fingers.Inner, direction.Z * fx.Fingers.Inner, Tuning.FlatLift)
				for _, length in { Tuning.Strip.StartLength, finger.length * fx.Fingers.Burst, finger.length } do
					for _, piece in LandingFX.flatSpike(inner, direction, length, finger.width, fx.Fingers.Thickness) do
						checkPiece(piece, label .. " finger " .. index)
					end
				end
			end
			checkHost(fx.Snow.Area, center + Vector3.new(0, fx.Snow.Height, 0), label .. " snow host")
			if not mobile or Tuning.Mobile.Mist then
				checkHost(fx.Mist.Area, Vector3.new(center.X, crater.FloorY + fx.Mist.Lift, center.Z), label .. " mist host")
			end
			if fx.Rime.Enabled then
				for _ = 1, fx.Rime.Max do checkCorners(CFrame.new(center), Vector3.one, label .. " pooled rime host") end
			end
		else
			t.eq(#layout.spokes, 8, label .. " spoke coverage")
			t.eq(#layout.rays, 8, label .. " ray coverage")
			t.eq(#layout.circle, 16, label .. " circle coverage")
			t.eq(#layout.sprouts, 12, label .. " sprout coverage")
			checkFlat(fx.Shimmer, label .. " shimmer")
			for index, sprout in layout.sprouts do
				local frame = LandingFX.pieceFrame(ground(sprout.x, sprout.z), outward(sprout.x, sprout.z), sprout.lean, sprout.yaw)
				checkPrism(frame, sprout, spec, false, label .. " sprout " .. index)
			end
			local gem = center + Vector3.new(0, fx.Gem.Height, 0)
			-- 10 is the controller's fixed shatter flash size; include it as well
			-- as the configured resting and maximum locked/unlocked pulses.
			local gemSize = math.max(10, fx.Gem.Size, fx.Gem.Pulse[2], fx.Gem.UnlockedPulse[2])
			checkCorners(CFrame.new(gem) * LandingFX.TIP_ROTATION, Vector3.one * gemSize, label .. " crown gem")
			checkPoint(gem, 0, label .. " gem anchor")
			checkPoint(center, 0, label .. " sprout burst anchor")
			for _, arc in layout.arcs do
				checkBeam(tips[arc.i], tips[arc.j], fx.Arcs.RingWidth, fx.Arcs.RingCurve, -fx.Arcs.RingCurve, label .. " ring arc")
			end
			for _, crown in layout.crowns do
				checkBeam(tips[crown.i], gem, math.max(fx.Arcs.CrownWidth[1], fx.Arcs.CrownWidth[2]), fx.Arcs.CrownCurve[1], fx.Arcs.CrownCurve[2], label .. " crown arc")
			end
			checkHost(fx.Motes.Area, Vector3.new(center.X, crater.FloorY + fx.Motes.Lift, center.Z), label .. " motes host")
		end
	end

	t.test("Iron has no persistent landing layout across compact event seeds", function()
		for seed = 1, SEEDS do
			for _, mobile in { false, true } do
				t.eq(LandingFX.layout("Iron", LandingFX.seed(seed, "Iron"), {}, mobile), nil, "Iron seed " .. seed)
			end
		end
	end)
	for _, typeId in { "Ice", "Crystal" } do
		for _, mobile in { false, true } do
			local caseType, caseMobile = typeId, mobile
			t.test(caseType .. (if caseMobile then " mobile" else " desktop") .. " seeded persistent geometry stays inside radius 125", function()
				for seed = 1, SEEDS do checkLayout(caseType, seed, caseMobile) end
			end)
		end
	end
end

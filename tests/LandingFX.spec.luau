--!strict
-- Spec for Shared.LandingFX: the Ice and Crystal landing effects' clock, layout and
-- rules. Sizes, counts and timings are read from Config.LandingFX and Config.Meteor, so a
-- retune doesn't break these cases.

return function(t: any)
	local LandingFX = require(t.shared.LandingFX)
	local Tuning = require(t.shared.Config.LandingFX)
	local Meteor = require(t.shared.Config.Meteor)

	local crater = Tuning.Crater
	local function radiusOf(x: number, z: number): number
		return math.sqrt(x * x + z * z)
	end
	local function bearingOf(x: number, z: number): number
		return math.deg(math.atan2(z, x)) % 360
	end
	local function gap(a: number, b: number): number
		return math.abs((a - b + 180) % 360 - 180)
	end

	t.test("style: Iron and unknown types build nothing", function()
		t.eq(LandingFX.style("Iron"), nil, "Iron")
		t.eq(LandingFX.style("Nope"), nil, "unknown")
		t.eq(LandingFX.style(nil), nil, "nil")
		t.eq(LandingFX.style("Ice"), "Ice")
		t.eq(LandingFX.style("Crystal"), "Crystal")
	end)

	t.test("clock follows the phases from the State alone", function()
		local active = Meteor.Types.Ice.ActiveDuration
		t.eq(LandingFX.clock("Countdown", 10, 25, "Ice").stage, "None", "countdown")
		local impact = LandingFX.clock("Impact", Meteor.ImpactDuration, Meteor.ImpactDuration, "Ice")
		t.eq(impact.stage, "Grow")
		t.near(impact.t, 0, 1e-9, "impact start")
		t.near(LandingFX.clock("Active", active, active, "Ice").t, Meteor.ImpactDuration, 1e-9, "active start")
		t.near(LandingFX.clock("Active", 100, 150, "Ice").t, Meteor.ImpactDuration + 50, 1e-9, "100 s left of 150")
		local cracked = LandingFX.clock("CoreCracked", 0, 5, "Ice")
		t.eq(cracked.stage, "Shatter")
		t.near(cracked.t, 5, 1e-9, "cracked end")
		t.eq(LandingFX.clock("Cooled", 5, 5, "Ice").stage, "Wither")
		t.eq(LandingFX.clock("Cleanup", 3, 5, "Ice").stage, "Gone")
		t.near(LandingFX.clock("Active", 100, nil, "Crystal").t, Meteor.ImpactDuration + active - 100, 1e-9, "no length")
		t.near(LandingFX.clock("Cooled", 1, nil, "Ice").t, Meteor.CooledDuration - 1, 1e-9, "cooled without a length")
		t.near(LandingFX.clock("Impact", 99, 3, "Ice").t, 0, 1e-9, "more time left than the phase clamps to 0")
	end)

	t.test("schedule waits, plays and snaps; linearAlpha is clamped", function()
		local snap, wait = LandingFX.schedule(2, 1, 0.5)
		t.eq(snap, false)
		t.near(wait, 1.5, 1e-9, "before start")
		snap, wait = LandingFX.schedule(2, 1, 2.5)
		t.eq(snap, false)
		t.eq(wait, 0, "running")
		snap = LandingFX.schedule(2, 1, 3)
		t.eq(snap, true, "done")
		t.eq(LandingFX.linearAlpha(2, 4, 0), 0)
		t.near(LandingFX.linearAlpha(2, 4, 3), 0.25, 1e-9)
		t.eq(LandingFX.linearAlpha(2, 4, 99), 1)
		t.eq(LandingFX.linearAlpha(2, 0, 1), 0, "zero length before")
		t.eq(LandingFX.linearAlpha(2, 0, 2), 1, "zero length after")
	end)

	t.test("front eases out and reach is its inverse", function()
		local delay, seconds, r0, r1 = 0.15, 1.6, 26, 120
		t.eq(LandingFX.front(0, delay, seconds, r0, r1), r0, "before the delay")
		local previous = r0
		for step = 0, 40 do
			local time = delay + seconds * step / 40
			local r = LandingFX.front(time, delay, seconds, r0, r1)
			t.ok(r >= previous - 1e-9, "never decreases")
			previous = r
			if step > 0 and step < 40 then
				t.near(LandingFX.reach(r, delay, seconds, r0, r1), time, 1e-6, "reach(front(t)) at step " .. step)
			end
		end
		t.eq(LandingFX.front(delay + seconds, delay, seconds, r0, r1), r1, "end")
		t.eq(LandingFX.reach(r1 + 1, delay, seconds, r0, r1), math.huge, "past the end")
	end)

	t.test("spread keeps bearings out of the corridors and is deterministic", function()
		for _, bearing in LandingFX.spread(8, Tuning.Corridors, 0.3) do
			t.ok(not LandingFX.inCorridor(bearing, Tuning.Corridors), "bearing " .. bearing .. " in a corridor")
		end
		local even = LandingFX.spread(8, {}, 0)
		for k = 2, #even do
			t.near(even[k] - even[k - 1], 45, 1e-9, "even spacing")
		end
		local a, b = LandingFX.spread(8, Tuning.Corridors, 0.42), LandingFX.spread(8, Tuning.Corridors, 0.42)
		for k = 1, #a do
			t.eq(a[k], b[k], "same input, same bearings")
		end
	end)

	local function same(a: any, b: any): boolean
		if #a.clusters ~= #b.clusters then
			return false
		end
		for k, cluster in a.clusters do
			local other = b.clusters[k]
			if cluster.x ~= other.x or cluster.z ~= other.z or cluster.height ~= other.height then
				return false
			end
		end
		return true
	end

	t.test("layout is seeded by the event", function()
		local ice = LandingFX.layout("Ice", LandingFX.seed(5, "Ice"), {}, false) :: any
		t.ok(same(ice, LandingFX.layout("Ice", LandingFX.seed(5, "Ice"), {}, false)), "same seed")
		t.ok(not same(ice, LandingFX.layout("Ice", LandingFX.seed(6, "Ice"), {}, false)), "next event differs")
		t.ok(LandingFX.seed(5, "Ice") ~= LandingFX.seed(5, "Crystal"), "types seed differently")
		t.eq(LandingFX.layout("Iron", 1, {}, false), nil, "Iron has no layout")
	end)

	local plaza = { kind = "box", cx = 0, cz = -95, hx = 34, hz = 29.5, ux = 1, uz = 0 }
	local rock = { kind = "circle", cx = 74, cz = 0, r = 3 }

	t.test("upright pieces stay out of the mining area, the corridors and the obstacles", function()
		local padding = Tuning.Obstacles.Padding
		for _, typeId in { "Ice", "Crystal" } do
			local fx = Tuning.Types[typeId]
			for seed = 1, 40 do
				local layout = LandingFX.layout(typeId, seed, { plaza, rock }, false) :: any
				local label = typeId .. " seed " .. seed
				local anchors = {}
				for _, cluster in layout.clusters do
					local r = radiusOf(cluster.x, cluster.z)
					t.ok(r - fx.Clusters.Footprint >= crater.OpeningRadius, label .. ": hero inside the opening")
					t.ok(not LandingFX.inCorridor(bearingOf(cluster.x, cluster.z), Tuning.Corridors), label .. ": hero in a corridor")
					t.ok(not LandingFX.blocked(cluster.x, cluster.z, { plaza, rock }, fx.Clusters.Footprint + padding), label .. ": hero on an obstacle")
					table.insert(anchors, { x = cluster.x, z = cluster.z, spacing = fx.Clusters.MinSpacing })
					for _, satellite in cluster.satellites do
						t.ok(radiusOf(satellite.x, satellite.z) >= crater.VerticalClearRadius, label .. ": satellite inside the clear radius")
					end
				end
				for _, sprout in layout.sprouts do
					t.ok(radiusOf(sprout.x, sprout.z) >= crater.VerticalClearRadius, label .. ": sprout inside the clear radius")
					t.ok(not LandingFX.inCorridor(bearingOf(sprout.x, sprout.z), Tuning.Corridors), label .. ": sprout in a corridor")
					t.ok(not LandingFX.blocked(sprout.x, sprout.z, { plaza, rock }, fx.Sprouts.Footprint + padding), label .. ": sprout on an obstacle")
					table.insert(anchors, { x = sprout.x, z = sprout.z, spacing = fx.Sprouts.MinSpacing })
				end
				for i = 1, #anchors do
					for j = i + 1, #anchors do
						local a, b = anchors[i], anchors[j]
						local spacing = math.min(a.spacing, b.spacing)
						t.ok(radiusOf(a.x - b.x, a.z - b.z) >= spacing - 1e-6, label .. ": pieces too close")
					end
				end
			end
		end
	end)

	t.test("an obstacle over the whole band leaves no clusters and no lines", function()
		local everything = { { kind = "circle", cx = 0, cz = 0, r = 500 } }
		for _, typeId in { "Ice", "Crystal" } do
			local layout = LandingFX.layout(typeId, 3, everything, false) :: any
			t.eq(#layout.clusters, 0, typeId .. " clusters")
			t.eq(#layout.cracks + #layout.spokes + #layout.rays, 0, typeId .. " lines")
		end
	end)

	-- A line from the crust out along its cluster's bearing, its segments starting when
	-- an easing-out front reaches each vertex. Vector2 is single precision, hence 1e-3.
	local function checkLine(line: any, cluster: any, maxKink: number, delay: number, seconds: number, label: string)
		local points = line.points
		local first, last = points[1].Magnitude, points[#points].Magnitude
		t.near(first, crater.LineStartRadius, 1e-3, label .. " starts at the crust")
		t.ok(gap(bearingOf(points[1].X, points[1].Y), cluster.angle) < 1e-3, label .. " starts on its cluster's bearing")
		for v = 2, #points do
			t.ok(points[v].Magnitude > points[v - 1].Magnitude, label .. " radii rise")
			t.ok(gap(bearingOf(points[v].X, points[v].Y), cluster.angle) <= maxKink + 1e-3, label .. " kink within range")
		end
		for s = 1, #line.starts do
			if s > 1 then
				t.ok(line.starts[s] >= line.starts[s - 1], label .. " segments start in order")
			end
			t.near(line.starts[s], LandingFX.reach(points[s].Magnitude, delay, seconds, first, last), 1e-4, label .. " segment start")
		end
	end

	t.test("lines run outward from the crust to their cluster", function()
		for seed = 1, 10 do
			local ice = LandingFX.layout("Ice", seed, {}, false) :: any
			local cracks = Tuning.Types.Ice.Cracks
			t.eq(#ice.cracks, #ice.clusters, "a crack per cluster")
			for k, crack in ice.cracks do
				local cluster = ice.clusters[k]
				checkLine(crack, cluster, cracks.Kink[2], cracks.Delay, cracks.Seconds, "crack")
				local base = crack.points[#cracks.Radii + 1]
				t.near(base.X, cluster.x, 1e-3, "crack passes through its cluster x")
				t.near(base.Y, cluster.z, 1e-3, "crack passes through its cluster z")
				t.ok(cluster.start >= crack.starts[#cracks.Radii + 1], "the spike erupts once its crack arrives")
			end

			local crystal = LandingFX.layout("Crystal", seed, {}, false) :: any
			local spokes = Tuning.Types.Crystal.Spokes
			t.eq(#crystal.spokes, #crystal.clusters, "a spoke per cluster")
			for k, spoke in crystal.spokes do
				local cluster = crystal.clusters[k]
				checkLine(spoke, cluster, 0, spokes.Delay, spokes.Seconds, "spoke")
				local n = #spoke.starts
				t.ok(cluster.start >= spoke.starts[n] + spoke.seconds[n] - 1e-6, "the crystal erupts once its spoke arrives")
			end
		end
	end)

	t.test("everything erupts in order and finishes during the Impact phase", function()
		for _, typeId in { "Ice", "Crystal" } do
			for seed = 1, 10 do
				local layout = LandingFX.layout(typeId, seed, {}, false) :: any
				for _, cluster in layout.clusters do
					t.ok(cluster.start + cluster.rise <= Meteor.ImpactDuration, typeId .. ": hero eruption ends by impact's end")
					for _, satellite in cluster.satellites do
						t.ok(satellite.start > cluster.start, typeId .. ": satellite after its hero")
						t.ok(satellite.start + satellite.rise <= Meteor.ImpactDuration, typeId .. ": satellite ends by impact's end")
					end
				end
				for _, arc in layout.arcs do
					local a, b = layout.clusters[arc.i], layout.clusters[arc.j]
					t.ok((b.angle - a.angle) % 360 <= Tuning.Types.Crystal.Arcs.MaxGap, "arcs only join near neighbours")
					t.ok(arc.start + arc.seconds <= Meteor.ImpactDuration, "ring arcs ignite during impact")
				end
				for _, crown in layout.crowns do
					t.ok(crown.start + crown.seconds <= Meteor.ImpactDuration, "crown arcs ignite during impact")
				end
				for _, list in { layout.cracks, layout.spokes, layout.circle, layout.rays } do
					for _, line in list do
						local n = #line.starts
						t.ok(line.starts[n] + line.seconds[n] <= Meteor.ImpactDuration, typeId .. ": lines finish during impact")
					end
				end
				for _, finger in layout.fingers do
					t.ok(finger.start + Tuning.Types.Ice.Fingers.BurstSeconds <= Meteor.ImpactDuration, "frost bursts during impact")
				end
			end
		end
	end)

	t.test("creep runs from the burst to the end of the event", function()
		t.near(LandingFX.creep(5, 5, 0.4, 153), 0.4, 1e-9, "at the burst's end")
		t.near(LandingFX.creep(153, 5, 0.4, 153), 1, 1e-9, "at the end")
		local previous = 0
		for time = 0, 160, 4 do
			local value = LandingFX.creep(time, 5, 0.4, 153)
			t.ok(value >= previous and value >= 0.4 and value <= 1, "within range and rising")
			previous = value
		end
	end)

	t.test("sprouts follow the crust until the core unlocks; charge is clamped", function()
		local count = Tuning.Types.Crystal.Sprouts.Count
		local need = math.ceil(36 * Meteor.CoreUnlockFraction)
		t.eq(LandingFX.sproutsShown(0, 36, count, Meteor.CoreUnlockFraction), 0, "none broken")
		t.eq(LandingFX.sproutsShown(need, 36, count, Meteor.CoreUnlockFraction), count, "all up at unlock")
		t.eq(LandingFX.sproutsShown(36, 36, count, Meteor.CoreUnlockFraction), count, "stays full")
		t.eq(LandingFX.sproutsShown(5, 0, count, Meteor.CoreUnlockFraction), 0, "no crust")
		local previous = 0
		for broken = 0, 36 do
			local shown = LandingFX.sproutsShown(broken, 36, count, Meteor.CoreUnlockFraction)
			t.ok(shown >= previous, "never drops")
			previous = shown
		end
		t.eq(LandingFX.charge(0, 0), 0)
		t.eq(LandingFX.charge(50, 36), 1)
		t.near(LandingFX.charge(9, 36), 0.25, 1e-9)
	end)

	t.test("rime shows on nodes that are refreezing right now", function()
		t.eq(LandingFX.hpChange(0.5, 0.6), "rise")
		t.eq(LandingFX.hpChange(0.5, 0.4), "drop")
		t.eq(LandingFX.hpChange(0.5, 0.5), "same", "a rescale keeps the fraction")
		t.eq(LandingFX.hpChange(nil, 0.5), "same")
		local candidates = {
			{ id = 1, fraction = 0.9, lastRiseAt = 10 },
			{ id = 2, fraction = 0.2, lastRiseAt = 10 },
			{ id = 3, fraction = 0.5, lastRiseAt = 5 }, -- rose too long ago
			{ id = 4, fraction = 1, lastRiseAt = 10 }, -- full again
			{ id = 5, fraction = 0, lastRiseAt = 10 }, -- broken
			{ id = 6, fraction = 0.4, lastRiseAt = nil },
			{ id = 7, fraction = 0.6, lastRiseAt = 10.5 },
		}
		local picked = LandingFX.pickRime(candidates, 11, 1.2, 2)
		t.eq(#picked, 2, "capped")
		t.eq(picked[1], 2, "most damaged first")
		t.eq(picked[2], 7)
	end)

	t.test("geometry helpers", function()
		local a, b = Vector3.new(0, 0, 0), Vector3.new(10, 0, 0)
		local cf, size = LandingFX.stripAt(a, b, 1, 1, 0.2, 0.1)
		t.near(size.Z, 10, 1e-6, "full length")
		t.near(cf.Position.X, 5, 1e-6, "midpoint")
		t.near(cf.Position.Y, 0.2, 1e-6, "lifted by half its thickness plus the lift")
		t.near(cf.LookVector:Dot(Vector3.xAxis), 1, 1e-6, "points along the strip")

		local outward = Vector3.xAxis
		for _, half in LandingFX.flatSpike(Vector3.zero, outward, 20, 8, 0.1) do
			t.near(half.cf.LookVector:Dot(outward), 1, 1e-6, "finger halves point outward")
			-- Each half's straight edge (its -Y face) lies on the centreline
			local edge = half.cf * Vector3.new(0, -half.size.Y / 2, 0)
			t.near(edge.Z, 0, 1e-6, "straight edges meet on the centreline")
		end

		local base = Vector3.new(70, 0, 0)
		local frame = LandingFX.pieceFrame(base, outward, 10, 30)
		local top = frame * Vector3.new(0, 20, 0)
		t.ok(top.X > base.X, "a lean tilts the top away from the crater")

		local moved = LandingFX.buried(CFrame.new(1, 2, 3), Vector3.yAxis, 4)
		t.near(moved.Position.Y, -2, 1e-9, "buried moves down the axis")

		local up = LandingFX.TIP_ROTATION:VectorToWorldSpace(Vector3.one.Unit)
		t.near(up:Dot(Vector3.yAxis), 1, 1e-6, "the tip cube stands on its corner")
	end)

	t.test("the part budget fits, and phones get no more than desktops", function()
		for _, typeId in { "Ice", "Crystal" } do
			local desktop, phone = LandingFX.budget(typeId, false), LandingFX.budget(typeId, true)
			t.ok(desktop <= Tuning.MaxParts, typeId .. " desktop over budget: " .. desktop)
			t.ok(phone <= desktop, typeId .. " phone above desktop")
		end
		t.eq(LandingFX.budget("Iron", false), 0)
	end)

	t.test("effect parts never block anything", function()
		local flags = LandingFX.PART_FLAGS
		t.eq(flags.Anchored, true)
		t.eq(flags.CanCollide, false)
		t.eq(flags.CanQuery, false)
		t.eq(flags.CanTouch, false)
		t.eq(flags.CastShadow, false)
	end)

	t.test("the colours and sounds the effects use exist", function()
		local Sounds = require(t.shared.Config.Sounds)
		for _, typeId in { "Ice", "Crystal" } do
			local meteorType = Meteor.Types[typeId]
			t.ok(meteorType.GlowColor and meteorType.OreColor and meteorType.CoreColor, typeId .. " colours")
			t.ok(#meteorType.CrustColors >= 3, typeId .. " crust colours")
			t.ok((Sounds :: any)[Tuning.Types[typeId].Sound], typeId .. " sound")
		end
		t.ok(Meteor.InertColor, "inert colour")
	end)
end

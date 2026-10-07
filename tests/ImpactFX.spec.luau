--!strict
return function(t)
	local Config = require(t.shared.Config)
	local FX = Config.ImpactFX

	t.test("every meteor type, the boss included, has its own landing flavour", function()
		for id in Config.Meteor.Types do
			t.ok(FX.Types[id], id .. " has an ImpactFX entry")
			t.ok(FX.Types[id].Burst and FX.Types[id].Rain, id .. " has a burst and a rain")
		end
	end)

	t.test("bursts and rains have sane counts, ranges and colours", function()
		local function burst(spec: any, label: string)
			t.ok(spec.Count > 0 and spec.Count <= 120, label .. " count")
			t.ok(spec.Speed[1] > 0 and spec.Speed[2] >= spec.Speed[1], label .. " speed")
			t.ok(spec.Lifetime[1] > 0 and spec.Lifetime[2] >= spec.Lifetime[1], label .. " lifetime")
			t.ok(#spec.Colors >= 2, label .. " colours")
		end
		for id, flavor in FX.Types do
			burst(flavor.Burst, id .. " burst")
			t.ok(flavor.Rain.Rate > 0 and flavor.Rain.Seconds > 0 and flavor.Rain.Seconds <= 12, id .. " rain")
			t.ok(flavor.Rain.Rate * flavor.Rain.Lifetime[2] < 400, id .. " rain keeps live particles bounded")
		end
		burst(FX.Golden.Burst, "golden")
		burst({ Count = FX.Chips.Count, Speed = FX.Chips.Speed, Lifetime = FX.Chips.Lifetime, Colors = { 1, 2 } }, "chips")
		burst({ Count = FX.Embers.Count, Speed = FX.Embers.Speed, Lifetime = FX.Embers.Lifetime, Colors = { 1, 2 } }, "embers")
	end)

	t.test("the rings roll out in order and never outlast the pool", function()
		local last = -1
		for _, ring in FX.Rings do
			t.ok(ring.Delay > last, "ring delays increase")
			last = ring.Delay
			t.ok(ring.Delay + ring.Seconds < FX.Pool.Seconds)
			t.ok(ring.ToDiameter / 2 <= Config.LandingFX.Crater.OpeningRadius + 1, "rings stay inside the crater opening")
		end
	end)

	t.test("the effects stay light: one pillar, at most three rings, a bounded rim", function()
		t.ok(#FX.Rings <= 3)
		t.ok(FX.Rim.Count <= 12)
		t.ok(FX.Mobile.Scale > 0 and FX.Mobile.Scale < 1)
		t.ok(FX.Fov.Punch <= 12, "the camera never lurches")
	end)
end

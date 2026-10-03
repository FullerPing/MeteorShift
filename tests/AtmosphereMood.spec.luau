--!strict
-- Spec for Shared.AtmosphereMood (spec §5.8): how strongly the approach, event and
-- dust moods apply in each meteor phase, and how they blend onto the calm look.
-- Timings and offsets are read from Config.Atmosphere so a retune doesn't break
-- these cases.

return function(t: any)
	local AtmosphereMood = require(t.shared.AtmosphereMood)
	local Tuning = require(t.shared.Config.Atmosphere)

	local base = {
		Brightness = 2.2,
		Exposure = 0,
		Density = 0.38,
		Haze = 2,
		Glare = 0.8,
		AtmosphereColor = Color3.fromRGB(206, 170, 140),
		AtmosphereDecay = Color3.fromRGB(146, 98, 84),
		GradeTint = Color3.fromRGB(255, 238, 222),
		Saturation = 0.05,
		Contrast = 0.1,
		Bloom = 0.7,
		CloudCover = 0.5,
		CloudColor = Color3.fromRGB(255, 236, 222),
	}
	local glow = Color3.fromRGB(120, 236, 255)
	local function distance(a: Color3, b: Color3): number
		return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B)
	end
	local function none(w: any): boolean
		return w.approach == 0 and w.event == 0 and w.dust == 0
	end

	t.test("calm during the countdown until the approach lead", function()
		t.ok(none(AtmosphereMood.weights("Countdown", 240, 240, nil)), "long before impact")
		t.ok(none(AtmosphereMood.weights("Countdown", Tuning.ApproachLead + 0.1, 240, nil)), "just before the lead")
		t.ok(none(AtmosphereMood.weights("Countdown", 100, 240, 300)), "an old impact doesn't leave dust")
	end)

	t.test("the approach rises to full at impact", function()
		local previous = -1
		for left = Tuning.ApproachLead, 0, -1 do
			local w = AtmosphereMood.weights("Countdown", left, 240, nil)
			t.ok(w.approach >= previous, "rises at " .. left)
			t.eq(w.event, 0)
			t.eq(w.dust, 0)
			previous = w.approach
		end
		t.near(AtmosphereMood.weights("Countdown", Tuning.ApproachLead, 240, nil).approach, 0, 1e-9)
		t.near(AtmosphereMood.weights("Countdown", Tuning.ApproachLead / 2, 240, nil).approach, 0.5, 1e-9)
		t.near(AtmosphereMood.weights("Countdown", 0, 240, nil).approach, 1, 1e-9)
	end)

	t.test("impact: full approach and dust, which then settle", function()
		local w = AtmosphereMood.weights("Impact", 3, 3, 0)
		t.near(w.approach, 1, 1e-9)
		t.near(w.dust, 1, 1e-9)
		t.eq(w.event, 1)
		local later = AtmosphereMood.weights("Active", 140, 150, Tuning.DustSeconds / 2)
		t.ok(later.dust > 0 and later.dust < 1, "dust settling")
		t.eq(AtmosphereMood.weights("Active", 140, 150, Tuning.ApproachClear).approach, 0)
		t.eq(AtmosphereMood.weights("Active", 100, 150, Tuning.DustSeconds).dust, 0)
	end)

	t.test("joining mid-event gets the event mood without approach or dust", function()
		local w = AtmosphereMood.weights("Active", 80, 150, nil)
		t.eq(w.event, 1)
		t.eq(w.approach, 0)
		t.eq(w.dust, 0)
	end)

	t.test("the event mood fades over CoreCracked and Cooled, and is gone in Cleanup", function()
		for _, phase in { "CoreCracked", "Cooled" } do
			t.near(AtmosphereMood.weights(phase, 5, 5, 200).event, 1, 1e-9)
			local mid = AtmosphereMood.weights(phase, 2.5, 5, 200).event
			t.ok(mid > 0 and mid < 1, phase .. " fading")
			t.near(AtmosphereMood.weights(phase, 0, 5, 200).event, 0, 1e-9)
			t.eq(AtmosphereMood.weights(phase, 0, 0, 200).event, 0, phase .. " with no length")
		end
		t.ok(none(AtmosphereMood.weights("Cleanup", 3, 5, 200)), "cleanup is calm")
	end)

	t.test("without a phase length the fades use Config.Meteor's durations", function()
		local Meteor = require(t.shared.Config.Meteor)
		for phase, length in { CoreCracked = Meteor.CrackedDuration, Cooled = Meteor.CooledDuration } do
			t.near(AtmosphereMood.weights(phase, length, nil, 200).event, 1, 1e-9, phase .. " start")
			t.near(AtmosphereMood.weights(phase, length / 2, nil, 200).event, 0.5, 1e-9, phase .. " halfway")
			t.near(AtmosphereMood.weights(phase, 0, nil, 200).event, 0, 1e-9, phase .. " end")
		end
	end)

	t.test("no weights leave the calm look as it is", function()
		local look = AtmosphereMood.blend(base, { approach = 0, event = 0, dust = 0 }, glow)
		t.ok(AtmosphereMood.near(look, base, 1e-9), "unchanged")
	end)

	t.test("the approach dims the light and tints the fog toward the glow", function()
		local look = AtmosphereMood.blend(base, { approach = 1, event = 0, dust = 0 }, glow)
		t.ok(look.Brightness < base.Brightness, "dimmer")
		t.ok(look.CloudCover > base.CloudCover, "more cloud")
		t.ok(distance(look.AtmosphereColor, glow) < distance(base.AtmosphereColor, glow), "fog toward glow")
		t.ok(distance(look.GradeTint, glow) < distance(base.GradeTint, glow), "grade toward glow")
	end)

	t.test("impact dust thickens the fog toward the dust colour", function()
		local look = AtmosphereMood.blend(base, { approach = 0, event = 0, dust = 1 }, glow)
		t.ok(look.Density > base.Density, "denser")
		t.ok(distance(look.AtmosphereColor, Tuning.DustColor) < distance(base.AtmosphereColor, Tuning.DustColor), "toward dust")
	end)

	t.test("blends stay inside what Lighting accepts", function()
		local extreme = table.clone(base)
		extreme.Density = 0.99
		extreme.Brightness = 0.1
		extreme.CloudCover = 0.95
		local look = AtmosphereMood.blend(extreme, { approach = 1, event = 1, dust = 1 }, glow)
		t.ok(look.Density <= 1, "density")
		t.ok(look.Brightness >= 0, "brightness")
		t.ok(look.CloudCover <= 1, "cloud cover")
	end)

	t.test("lerp runs from one look to the other", function()
		local target = AtmosphereMood.blend(base, { approach = 1, event = 1, dust = 1 }, glow)
		t.ok(AtmosphereMood.near(AtmosphereMood.lerp(base, target, 0), base, 1e-9), "alpha 0")
		t.ok(AtmosphereMood.near(AtmosphereMood.lerp(base, target, 1), target, 1e-6), "alpha 1")
		local half = AtmosphereMood.lerp(base, target, 0.5)
		t.near(half.Density, (base.Density + target.Density) / 2, 1e-9)
		t.ok(not AtmosphereMood.near(half, target, 1e-3), "half is not there yet")
	end)
end

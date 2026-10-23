--!strict
-- Spec for the first-join intro: its words and timing, and who gets to see it.

return function(t: any)
	local Config = require(t.shared.Config)
	local Intro = require(t.shared.Intro)

	t.test("the intro cinematic is short and its words fit on one screen", function()
		local settings = Config.Intro
		t.ok(#settings.Title > 0 and #settings.Title <= 30, "title")
		t.ok(#settings.Tagline > 0 and #settings.Tagline <= 60, "tagline")
		t.ok(settings.Fall > 0 and settings.Hold > 0 and settings.Glide > 0)
		t.ok(settings.Fall + settings.Hold + settings.Glide <= 8, "over in under 8 seconds")
		t.ok(settings.Push > 0 and settings.Push <= 1, "pushes in, never past the crater")
	end)

	t.test("a brand-new profile sees the intro", function()
		t.eq(Intro.shouldShow({ tutorialDone = false }, 1), true)
		t.eq(Intro.shouldShow({}, 1), true)
	end)

	t.test("once seen it never shows again", function()
		t.eq(Intro.shouldShow({ introSeen = true }, 1), false)
	end)

	t.test("existing players are treated as having seen it", function()
		t.eq(Intro.shouldShow({ tutorialDone = true }, 1), false, "finished or skipped the tutorial")
		t.eq(Intro.shouldShow({ tutorialDone = false }, 3), false, "partway through the tutorial")
	end)
end

--!strict
-- Spec for the first-join intro: its pages and who gets to see it.

return function(t: any)
	local Config = require(t.shared.Config)
	local Intro = require(t.shared.Intro)

	t.test("the intro has five pages, each with an icon, a headline and a short text", function()
		local pages = Config.Intro.Pages
		t.eq(#pages, 5)
		for index, page in pages do
			t.ok(page.Icon ~= "", "icon " .. index)
			t.ok(#page.Title > 0 and #page.Title <= 20, "headline " .. index)
			t.ok(#page.Body > 0 and #page.Body <= 110, "text " .. index)
		end
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

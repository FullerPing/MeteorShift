--!strict
-- The Rebirth menu stays narrow and readable; only its body scrolls, so the rebirth button, the note under it
-- and the premium keep-everything button are always reachable.
return function(t: any)
	local RebirthLayout = require(t.shared.RebirthLayout)
	local viewports = {
		Vector2.new(320, 568), Vector2.new(390, 667), Vector2.new(430, 932),
		Vector2.new(667, 375), Vector2.new(844, 390),
		Vector2.new(1375, 659), Vector2.new(1920, 1080),
	}
	local function layout(viewport: Vector2, inset: number): any
		t.ok(type(RebirthLayout.compute) == "function", "rebirth geometry compute is available")
		return RebirthLayout.compute(viewport, inset)
	end

	t.test("rebirth panel clears the inset and every viewport edge", function()
		for _, viewport in viewports do
			for _, inset in { 36, 58 } do
				local p = layout(viewport, inset).panel
				local context = tostring(viewport) .. " inset=" .. inset
				t.ok(p.x >= 12 and p.y >= inset + 12, context .. " clears left and top")
				t.ok(p.x + p.w <= viewport.X - 12, context .. " clears right")
				t.ok(p.y + p.h <= viewport.Y - 12, context .. " clears bottom")
				t.ok(p.w > 0 and p.w <= 440 and p.h > 0 and p.h <= 640, context .. " panel bounds")
			end
		end
	end)

	t.test("desktop panel is centered below the top inset", function()
		local p = layout(Vector2.new(1920, 1080), 58).panel
		t.eq(p.w, 440)
		t.eq(p.h, 640)
		t.near(p.x + p.w / 2, 960, 0.01, "horizontal center")
		t.near(p.y + p.h / 2, 569, 0.01, "center of unobstructed height")
	end)

	t.test("header has a 44 px close budget above the body", function()
		for _, viewport in viewports do
			local l = layout(viewport, 58)
			t.ok(l.contentY >= 8 + 44 + 12, "body clears the close target by twelve pixels")
			t.ok(l.panel.w - l.padding * 2 >= 44, "body remains usable between its edges")
		end
	end)

	t.test("the pinned controls stack below the body without overlapping", function()
		for _, viewport in viewports do
			for _, inset in { 36, 58 } do
				local l = layout(viewport, inset)
				t.ok(l.contentH > 0 or l.panel.h < 300, "body has a visible window")
				t.ok(l.contentY + l.contentH + 10 <= l.confirmY, "body clears the rebirth button")
				t.ok(l.confirmY + l.confirmH + 4 <= l.footerY, "the note sits under the rebirth button")
				t.ok(l.footerY + l.footerH + 4 <= l.dividerY, "the premium divider sits under the note")
				t.ok(l.dividerY + l.dividerH + 8 <= l.keepY, "the keep-everything button sits under the divider")
				t.ok(l.keepY + l.keepH <= l.panel.h - l.padding, "the keep-everything button clears the bottom edge")
			end
		end
	end)

	t.test("the premium button carries less weight than the rebirth button", function()
		local l = layout(Vector2.new(1920, 1080), 58)
		t.ok(l.keepH < l.confirmH, "keep-everything is shorter than the main action")
		t.ok(l.confirmH >= 48 and l.keepH >= 40, "both stay comfortable touch targets")
	end)

	t.test("a tall screen shows the whole body, a short one scrolls it", function()
		local desktop = layout(Vector2.new(1920, 1080), 58)
		local short = layout(Vector2.new(844, 390), 58)
		t.ok(desktop.contentH >= 340, "desktop body is tall enough for the reward, lists and progress")
		t.ok(short.contentH < desktop.contentH, "a short screen shrinks only the body window")
		t.ok(short.contentH >= 100, "a phone in landscape keeps a usable window")
		t.ok(short.confirmH >= 40 and short.keepH >= 36, "the pinned buttons stay tappable")
	end)
end

--!strict
-- Rebirth stays compact and readable; short screens scroll only its body.
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
				t.ok(p.w > 0 and p.w <= 400 and p.h > 0 and p.h <= 400, context .. " compact panel bounds")
			end
		end
	end)

	t.test("desktop panel is compact and centered below the top inset", function()
		local p = layout(Vector2.new(1920, 1080), 58).panel
		t.eq(p.w, 400)
		t.eq(p.h, 400)
		t.near(p.x + p.w / 2, 960, 0.01, "horizontal center")
		t.near(p.y + p.h / 2, 569, 0.01, "center of unobstructed height")
	end)

	t.test("header has a 44 px close budget above the body", function()
		for _, viewport in viewports do
			local l = layout(viewport, 58)
			t.ok(l.contentY >= 8 + 44 + 12, "body clears the close target by twelve pixels")
			t.ok(l.panel.w >= 20 + 28 + 12 + 44 + 12, "title and close have separate horizontal room")
			t.ok(l.panel.w - 32 >= 44, "body remains usable between sixteen pixel edges")
		end
	end)

	t.test("confirmation and notice remain reachable outside the scrolling body", function()
		for _, viewport in viewports do
			for _, inset in { 36, 58 } do
				local l = layout(viewport, inset)
				t.ok(l.contentH > 0, "body has a visible window")
				t.ok(l.contentY + l.contentH + 12 <= l.confirmY, "body clears confirmation")
				t.ok(l.confirmY >= 0 and l.confirmY + 48 + 6 <= l.footerY, "48 px confirmation clears notice")
				t.ok(l.footerY + 26 <= l.panel.h - 12, "notice clears the bottom edge")
			end
		end
	end)

	t.test("compact phone portraits show the entire body without vertical scrolling", function()
		for _, viewport in { Vector2.new(320, 568), Vector2.new(390, 667), Vector2.new(430, 932) } do
			for _, inset in { 36, 58 } do
				local l = layout(viewport, inset)
				t.ok(l.contentH >= l.canvasH, "portrait shows paragraph, multiplier and progress together")
				t.ok(l.contentH <= 240, "portrait body remains compact")
				t.ok(l.panel.w <= viewport.X - 24, "portrait width fits")
			end
		end
	end)

	t.test("short landscapes scroll the full body without shrinking the confirmation", function()
		for _, viewport in { Vector2.new(667, 375), Vector2.new(844, 390) } do
			for _, inset in { 36, 58 } do
				local l = layout(viewport, inset)
				t.ok(l.canvasH > l.contentH, "short landscape retains scrollable content")
				t.ok(l.canvasH >= 202 + 20 + 4, "cash progress remains reachable at the canvas end")
				t.eq(l.panel.h - l.confirmY, 92, "confirmation keeps its position above the footer")
			end
		end
		local measured = layout(Vector2.new(844, 390), 58)
		t.eq(measured.panel.h, 308)
		t.eq(measured.contentH, 140)
	end)

	t.test("body canvas preserves the same readable content after a viewport resize", function()
		local desktop = layout(Vector2.new(1920, 1080), 58)
		local phone = layout(Vector2.new(320, 568), 58)
		local short = layout(Vector2.new(844, 390), 58)
		t.eq(desktop.canvasH, 226, "paragraph, multiplier and progress budget")
		t.eq(phone.canvasH, desktop.canvasH, "portrait preserves the content")
		t.eq(short.canvasH, desktop.canvasH, "short screen scrolls the content")
		t.ok(desktop.contentH >= desktop.canvasH, "desktop needs no body scrolling")
	end)
end

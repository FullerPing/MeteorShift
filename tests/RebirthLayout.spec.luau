--!strict
-- The Rebirth menu: the Gear Shop's wide frame on a roomy window, one column on a small screen. Only its body scrolls,
-- so REBIRTH, the note, PERKS and the premium keep-everything button are always reachable, and nothing leaves the panel.
return function(t: any)
	local RebirthLayout = require(t.shared.RebirthLayout)
	local ShopLayout = require(t.shared.EquipmentShopLayout)
	local MenuFit = require(t.shared.MenuFit)
	local viewports = {
		Vector2.new(320, 568), Vector2.new(390, 667), Vector2.new(430, 932),
		Vector2.new(667, 375), Vector2.new(844, 390),
		Vector2.new(1024, 600), Vector2.new(1375, 659), Vector2.new(1920, 1080), Vector2.new(2560, 1440),
	}
	-- the layout the controller would use on this screen, in virtual pixels
	local function layout(viewport: Vector2, inset: number): (any, any)
		local view = ShopLayout.view(viewport, inset)
		return RebirthLayout.compute(view.viewport, view.inset, view.wide), view
	end
	local function inside(r: any, p: any, context: string)
		t.ok(r.x >= 0 and r.y >= 0, context .. " starts inside the panel")
		t.ok(r.x + r.w <= p.w + 0.01 and r.y + r.h <= p.h - RebirthLayout.LIP + 0.01, context .. " ends inside the panel body")
	end
	local function apart(a: any, b: any, context: string)
		local clear = a.x + a.w <= b.x or b.x + b.w <= a.x or a.y + a.h <= b.y or b.y + b.h <= a.y
		t.ok(clear, context)
	end

	t.test("the panel and its ribbon stay on the screen, under the top bar", function()
		for _, viewport in viewports do
			for _, inset in { 36, 58 } do
				local l, view = layout(viewport, inset)
				local p = l.panel
				local context = tostring(viewport) .. " inset=" .. inset
				local ribbonTop = if l.wide then p.y - RebirthLayout.RIBBON else p.y - 24
				t.ok(p.x >= 0 and p.x + p.w <= view.viewport.X + 0.01, context .. " fits the width")
				t.ok(ribbonTop >= view.inset - 0.01, context .. " ribbon clears the top bar")
				t.ok(p.y + p.h + RebirthLayout.LIP <= view.viewport.Y + 0.01, context .. " fits the height")
			end
		end
	end)

	t.test("a roomy window gets the Gear Shop's frame", function()
		local l = layout(Vector2.new(1920, 1080), 58)
		t.ok(l.wide, "1080p is wide")
		t.eq(l.panel.w, 760)
		t.eq(l.panel.h + RebirthLayout.RIBBON, 501)
		local phone = layout(Vector2.new(844, 390), 58)
		t.ok(not phone.wide, "a phone in landscape uses the column")
	end)

	t.test("every control sits inside the panel and none overlap", function()
		for _, viewport in viewports do
			local l = layout(viewport, 58)
			local p = l.panel
			local context = tostring(viewport)
			for _, name in { "content", "requirement", "confirm", "footer", "keep", "perks" } do
				inside(l[name], p, context .. " " .. name)
			end
			apart(l.content, l.requirement, context .. " body clears the requirement")
			apart(l.content, l.confirm, context .. " body clears REBIRTH")
			apart(l.confirm, l.footer, context .. " REBIRTH clears the note")
			apart(l.confirm, l.keep, context .. " REBIRTH clears keep-everything")
			apart(l.confirm, l.perks, context .. " REBIRTH clears PERKS")
			apart(l.keep, l.perks, context .. " keep-everything clears PERKS")
			t.ok(l.content.y >= 50, context .. " the body clears the title ribbon")
		end
	end)

	t.test("the actions stay comfortable to press and the body keeps a window", function()
		for _, viewport in viewports do
			local l = layout(viewport, 58)
			local context = tostring(viewport)
			t.ok(l.confirm.h >= 48 and l.keep.h >= 40 and l.perks.h >= 40, context .. " touch targets")
			t.ok(l.keep.h < l.confirm.h, context .. " keep-everything is lighter than REBIRTH")
			t.ok(l.content.h >= 100, context .. " the body has a usable window")
		end
		local wide = layout(Vector2.new(1920, 1080), 58)
		t.ok(wide.content.h >= 340, "the wide body shows the reward and both lists without scrolling")
	end)

	t.test("small screens are drawn no smaller than MenuFit allows", function()
		local _, view = layout(Vector2.new(844, 390), 58)
		t.ok(view.scale >= MenuFit.MinScale - 0.001, "text stays readable")
	end)
end

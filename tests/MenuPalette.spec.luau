--!strict
-- Spec for Shared.MenuPalette: every text colour of the light menus reads on what it is drawn over.
return function(t: any)
	local MenuPalette = require(t.shared.MenuPalette)

	t.test("contrast follows the WCAG definition", function()
		t.near(MenuPalette.contrast(Color3.new(0, 0, 0), Color3.new(1, 1, 1)), 21, 0.01, "black on white")
		t.near(MenuPalette.contrast(Color3.new(1, 1, 1), Color3.new(1, 1, 1)), 1, 0.001, "a colour on itself")
		t.near(MenuPalette.contrast(Color3.new(0, 0, 0), Color3.new(1, 1, 1)), MenuPalette.contrast(Color3.new(1, 1, 1), Color3.new(0, 0, 0)), 1e-9, "order does not matter")
	end)

	t.test("every text colour reads on its background", function()
		t.ok(#MenuPalette.Pairs > 0, "there are pairs to check")
		for _, pair in MenuPalette.Pairs do
			local ratio = MenuPalette.contrast(pair.text, pair.background)
			t.ok(ratio >= pair.min, string.format("%s: %.2f:1 (needs %.1f)", pair.name, ratio, pair.min))
		end
	end)

	t.test("states the player must tell apart do not look alike", function()
		-- these differ by hue more than by brightness (lime on a pale strip is close in luminance), so compare the colours
		local function distance(a: Color3, b: Color3): number
			return math.sqrt((a.R - b.R) ^ 2 + (a.G - b.G) ^ 2 + (a.B - b.B) ^ 2) * 255
		end
		t.ok(distance(MenuPalette.TAB_ON, MenuPalette.TAB_OFF) >= 60, "selected and unselected tabs")
		t.ok(distance(MenuPalette.LIME, MenuPalette.STRIP) >= 60, "selected and unselected quantity")
		t.ok(distance(MenuPalette.LIME, MenuPalette.FACE) >= 60, "a ready button and one that cannot be pressed")
	end)

	t.test("the body is opaque, as in the owner's mockup", function()
		t.eq(MenuPalette.BODY_ALPHA, 1, "fully opaque")
	end)
end

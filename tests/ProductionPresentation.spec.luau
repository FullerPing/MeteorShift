--!strict
-- Workshop stock and upgrade presentation never change gameplay quantities.

return function(t: any)
	local module = t.shared:FindFirstChild("ProductionPresentation")
	t.test("workshop presentation can render actual station stock", function()
		t.ok(module, "plot presentation module missing")
	end)
	if not module then return end
	local Presentation = require(module)

	t.test("empty and invalid stock hides all decorative contents", function()
		for _, amount in { 0, -1, -math.huge, math.huge, 0 / 0, false, true, "12", {} } do
			t.eq(Presentation.fillCount(amount), 0)
		end
		t.eq(Presentation.fillCount(nil), 0)
	end)

	t.test("any positive finite stock is visible and huge stores stay bounded", function()
		for _, amount in { 1e-200, 0.125, 0.99, 1 } do t.eq(Presentation.fillCount(amount), 1) end
		t.eq(Presentation.fillCount(1e300), 8)
	end)

	t.test("stock grows logarithmically through the eight decorative slots", function()
		for _, fixture in {
			{ 1, 1 }, { 1.9, 1 }, { 2, 2 }, { 3, 2 }, { 4, 3 }, { 8, 4 },
			{ 16, 5 }, { 32, 6 }, { 64, 7 }, { 127, 7 }, { 128, 8 }, { 2000, 8 },
		} do t.eq(Presentation.fillCount(fixture[1]), fixture[2]) end
	end)

	t.test("increasing stock cannot reduce visible contents or exceed slot capacity", function()
		local previous = 0
		for _, amount in { 0, 0.01, 0.25, 1, 2, 7, 18, 34, 99, 128, 1e6, 1e100 } do
			local count = Presentation.fillCount(amount)
			t.ok(count >= previous)
			t.ok(count >= 0 and count <= 8)
			t.eq(count % 1, 0, "decorative slots need integer counts")
			previous = count
		end
	end)

	t.test("upgrade pieces appear at their required station level", function()
		t.eq(Presentation.levelVisible(1, 1), true)
		t.eq(Presentation.levelVisible(1, 2), false)
		t.eq(Presentation.levelVisible(2, 2), true)
		t.eq(Presentation.levelVisible(7, 3), true)
		t.eq(Presentation.levelVisible(2.9, 3), false)
	end)

	t.test("invalid station levels safely show base parts and hide upgrades", function()
		for _, level in { false, "7", -1, 0, math.huge, -math.huge, 0 / 0, {} } do
			t.eq(Presentation.levelVisible(level, 1), true)
			t.eq(Presentation.levelVisible(level, 2), false)
		end
		t.eq(Presentation.levelVisible(nil, 2), false)
		for _, threshold in { false, "3", -1, 0, math.huge, 0 / 0 } do
			t.eq(Presentation.levelVisible(1, threshold), true)
		end
		t.eq(Presentation.levelVisible(1, nil), true)
	end)

	local function brightness(color: Color3): number
		return color.R + color.G + color.B
	end
	t.test("ore colours retain iron frost and crystal visual identities", function()
		local iron = Presentation.color("iron", "ore")
		local frost = Presentation.color("frost", "ore")
		local crystal = Presentation.color("crystal", "ore")
		t.ok(iron.R > iron.G and iron.G > iron.B, "iron is warm stone")
		t.ok(frost.B > frost.G and frost.G > frost.R, "frost is cyan")
		t.ok(crystal.R > crystal.G and crystal.B > crystal.G, "crystal is magenta")
		t.ok(iron ~= frost and frost ~= crystal and crystal ~= iron, "stock types remain distinct")
	end)

	t.test("refined bars use a distinct brighter finish without losing their type colour", function()
		for _, id in { "iron", "frost", "crystal" } do
			local ore, bar = Presentation.color(id, "ore"), Presentation.color(id, "bar")
			t.ok(brightness(bar) > brightness(ore), "bars have a brighter finish")
			for _, color in { ore, bar } do
				for _, channel in { color.R, color.G, color.B } do t.ok(channel == channel and channel >= 0 and channel <= 1) end
			end
		end
		local iron, frost, crystal = Presentation.color("iron", "bar"), Presentation.color("frost", "bar"), Presentation.color("crystal", "bar")
		t.ok(iron.R > iron.G and iron.G > iron.B)
		t.ok(frost.B > frost.G and frost.G > frost.R)
		t.ok(crystal.R > crystal.G and crystal.B > crystal.G)
		t.ok(iron ~= frost and frost ~= crystal and crystal ~= iron)
	end)

	t.test("unknown stock uses safe neutral colours for ore and bars", function()
		for _, payload in { "ore", "bar" } do
			local color = Presentation.color("future-ore", payload)
			t.eq(typeof(color), "Color3")
			t.near(color.R, color.G, 1e-6)
			t.near(color.G, color.B, 1e-6)
			t.ok(color.R > 0 and color.R < 1)
			t.eq(Presentation.color("", payload), color)
		end
		t.ok(brightness(Presentation.color("future-ore", "bar")) > brightness(Presentation.color("future-ore", "ore")))
	end)
end

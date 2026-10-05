--!strict
return function(t: any)
	local Layout = require(t.shared.RefineryLayout)
	t.test("phone refinery retains an inventory row above its footer", function()
		for _, viewport in { Vector2.new(844, 390), Vector2.new(780, 360), Vector2.new(685, 338), Vector2.new(320, 568), Vector2.new(390, 844) } do
			for _, inset in { 36, 58, 60 } do
				local height = math.min(570, viewport.Y - inset - 24)
				local g = Layout.compute(height)
				t.ok(g.inventoryHeight >= 44, tostring(viewport) .. " usable inventory row")
				t.ok(g.list + g.inventoryHeight <= height - 56, "inventory clears footer")
				t.ok(g.actions + g.actionH <= g.list, "actions clear inventory")
				t.ok(g.actionH >= 44, "transaction targets remain touch sized")
			end
		end
	end)
	t.test("short refinery defers extra headings to keep the empty state clear", function()
		local g = Layout.compute(307)
		t.eq(g.hideStatus, true)
		t.eq(g.minimal, false)
		t.ok(g.list + 44 < 307 - 54, "empty-state copy clears feedback")
		t.eq(Layout.compute(570).hideStatus, false)
	end)
end

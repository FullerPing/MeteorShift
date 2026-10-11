--!strict
-- The gear screen's geometry: every control sits inside the scrollable area and nothing overlaps.
return function(t: any)
	local EquipmentShopLayout = require(t.shared.EquipmentShopLayout)
	local sizes = { { 536, 374, false }, { 536, 250, false }, { 296, 380, true }, { 366, 440, true } }

	local function inside(r: any, w: number, canvasH: number): boolean
		return r.x >= 0 and r.y >= 0 and r.x + r.w <= w + 1e-6 and r.y + r.h <= canvasH + 1e-6
	end

	t.test("every control sits inside the screen's canvas", function()
		for _, s in sizes do
			for _, stack in { true, false } do
				for _, rows in { 2, 4 } do
					local l = EquipmentShopLayout.screen(s[1], s[2], s[3], stack, rows)
					local context = s[1] .. "x" .. s[2] .. (if stack then " stacked" else "") .. " rows=" .. rows
					t.ok(l.canvasH >= s[2] or s[3], context .. " the canvas covers the screen")
					for _, key in { "name", "tier", "well", "info", "levelLabel", "levelValue", "upgrade" } do
						t.ok(inside((l :: any)[key], s[1], l.canvasH), context .. " " .. key .. " inside")
					end
					t.ok(#l.stats == rows, context .. " one rect per stat row")
					for index, r in l.stats do t.ok(inside(r, s[1], l.canvasH), context .. " stat " .. index .. " inside") end
					for index, r in l.amounts do t.ok(inside(r, s[1], l.canvasH), context .. " amount " .. index .. " inside") end
					if stack then t.ok(inside(l.evolve, s[1], l.canvasH), context .. " the evolution card inside") end
				end
			end
		end
	end)

	t.test("wide screens keep the quantity row between the info card and Upgrade", function()
		for _, s in sizes do
			if not s[3] then
				local l = EquipmentShopLayout.screen(s[1], s[2], false, false, 4)
				t.ok(l.info.y + l.info.h <= l.amounts[1].y, "the info card clears the quantity row")
				t.ok(l.amounts[1].y + l.amounts[1].h <= l.upgrade.y, "the quantity row clears Upgrade")
				t.ok(l.well.x + l.well.w <= l.info.x, "the preview sits left of the info card")
				t.ok(l.tier.y + l.tier.h <= l.well.y, "the name and tier sit above the preview")
				local last = l.stats[#l.stats]
				t.ok(last.y + last.h <= l.info.y + l.info.h, "the stat rows fit in the info card")
			end
		end
	end)

	t.test("narrow screens stack the controls top to bottom", function()
		local l = EquipmentShopLayout.screen(296, 380, true, true, 4)
		t.ok(l.info.y >= l.well.y + l.well.h, "the info card sits under the preview")
		local last = l.stats[#l.stats]
		t.ok(last.y + last.h <= l.info.y + l.info.h, "the stat rows fit in the info card")
		t.ok(l.amounts[1].y >= l.info.y + l.info.h, "the quantity sits under the info card")
		t.ok(l.upgrade.y >= l.amounts[1].y + l.amounts[1].h, "Upgrade sits under the quantity")
		t.ok(l.evolve.y >= l.upgrade.y + l.upgrade.h, "the evolution card sits last")
	end)

	t.test("the evolution body fits its width in both forms", function()
		for _, stacked in { true, false } do
			for _, alt in { true, false } do
				local width = if stacked then 296 else 268
				local l = EquipmentShopLayout.evolve(width, stacked, alt)
				local parts: { any } = { l.well, l.name, l.tier, l.evolve, table.unpack(l.rows) }
				for _, r in parts do
					t.ok(r.x >= 0 and r.x + r.w <= width + 1e-6 and r.y + r.h <= l.height + 1e-6, "a part sits inside the body")
				end
				t.ok(l.rows[1].y >= l.tier.y + l.tier.h, "the requirements sit under the name")
				t.ok(l.evolve.y >= l.rows[3].y + l.rows[3].h, "the buttons sit under the requirements")
				if alt then t.ok(l.alt.y >= l.evolve.y and l.alt.x + l.alt.w <= width + 1e-6, "the paid button is inside") end
			end
		end
	end)
end

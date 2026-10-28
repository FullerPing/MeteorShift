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
					for _, key in { "card", "name", "tier", "well", "info", "levelLabel", "levelValue", "strip", "upgrade" } do
						t.ok(inside((l :: any)[key], s[1], l.canvasH), context .. " " .. key .. " inside")
					end
					for _, key in { "name", "tier", "well", "info" } do
						local r = (l :: any)[key]
						t.ok(r.x >= l.card.x and r.y >= l.card.y and r.x + r.w <= l.card.x + l.card.w + 1e-6 and r.y + r.h <= l.card.y + l.card.h + 1e-6,
							context .. " " .. key .. " sits on the blue card")
					end
					t.ok(#l.stats == rows, context .. " one rect per stat row")
					for index, r in l.stats do t.ok(inside(r, s[1], l.canvasH), context .. " stat " .. index .. " inside") end
					for index, r in l.amounts do
						t.ok(inside(r, s[1], l.canvasH), context .. " amount " .. index .. " inside")
						t.ok(r.x >= l.strip.x and r.x + r.w <= l.strip.x + l.strip.w + 1e-6 and r.y >= l.strip.y and r.y + r.h <= l.strip.y + l.strip.h + 1e-6,
							context .. " amount " .. index .. " sits in the quantity strip")
					end
					if stack then t.ok(inside(l.evolve, s[1], l.canvasH), context .. " the evolution card inside") end
				end
			end
		end
	end)

	t.test("wide screens keep the quantity row between the info card and Upgrade", function()
		for _, s in sizes do
			if not s[3] and s[2] >= 360 then
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

	t.test("short wide screens fit without scrolling, with the quantity and Upgrade beside the info card", function()
		for _, h in { 220, 250, 300 } do
			for _, rows in { 2, 4 } do
				local l = EquipmentShopLayout.screen(536, h, false, false, rows)
				local context = "536x" .. h .. " rows=" .. rows
				t.ok(l.canvasH <= h + 1e-6, context .. " no scrolling (" .. l.canvasH .. ")")
				t.ok(l.well.x + l.well.w <= l.info.x, context .. " the preview sits left of the info card")
				for _, r in { l.upgrade, table.unpack(l.amounts) } do
					t.ok(r.x >= l.info.x + l.info.w, context .. " the controls sit right of the info card")
				end
				t.ok(l.amounts[1].y + l.amounts[1].h <= l.upgrade.y, context .. " the quantity sits above Upgrade")
				t.ok(l.upgrade.h >= 44, context .. " Upgrade stays a full touch target")
				local last = l.stats[#l.stats]
				t.ok(last.y + last.h <= l.info.y + l.info.h, context .. " the stat rows fit in the info card")
				t.ok(l.tier.y + l.tier.h <= l.info.y, context .. " the name and tier sit above the body")
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
				local parts: { any } = { l.banner, l.heading, l.well, l.name, l.tier, l.bar, l.bar2, l.evolve, table.unpack(l.rows) }
				for _, r in parts do
					t.ok(r.x >= 0 and r.x + r.w <= width + 1e-6 and r.y >= 0 and r.y + r.h <= l.height + 1e-6, "a part sits inside the body")
				end
				-- stacked, the banner carries the heading, name and tier; the column puts the name and tier under it on the card
				for _, r in (if stacked then { l.heading, l.name, l.tier } else { l.heading }) :: { any } do
					t.ok(r.y >= l.banner.y and r.y + r.h <= l.banner.y + l.banner.h, "the heading sits in the banner")
				end
				for _, r in { l.well, l.rows[1], l.rows[2], l.bar } do
					t.ok(r.y >= l.card.y and r.y + r.h <= l.card.y + l.card.h + 1e-6, "the preview and requirements sit on the card")
				end
				t.ok(#l.rows == 2, "two requirements: the gear level and the player level")
				t.ok(l.rows[1].y >= l.tier.y + l.tier.h and l.rows[1].y >= l.well.y + (if stacked then 0 else l.well.h), "the requirements sit under the name")
				t.ok(l.bar.y >= l.rows[1].y + l.rows[1].h and l.rows[2].y >= l.bar.y + l.bar.h, "the gear level's bar sits between the two rows")
				t.ok(l.bar2.y >= l.rows[2].y + l.rows[2].h and l.evolve.y >= l.bar2.y + l.bar2.h, "the player level's bar sits between its row and the buttons")
				t.ok(l.evolve.y >= l.rows[2].y + l.rows[2].h, "the buttons sit under the requirements")
				-- the wide column is the owner's frame (a desktop mouse); the stacked card is for touch screens
				if stacked then t.ok(l.evolve.h >= 44, "the evolve button is a touch target") end
				if alt then t.ok(l.alt.y >= l.evolve.y and l.alt.x + l.alt.w <= width + 1e-6, "the paid button is inside") end
			end
		end
	end)
end

--!strict
-- Spec for Shared.MeteorIcon: resolve maps a meteor typeId to its HUD icon.
-- Expectations compare against Config.HudIcons values (never hard-coded asset
-- ids); the fallback for unknown/missing ids is the generic meteor icon.

return function(t: any)
	local MeteorIcon = require(t.shared.MeteorIcon)
	local HudIcons = require(t.shared.Config.HudIcons)

	t.test("the known types each resolve to their own icon", function()
		t.eq(MeteorIcon.resolve("Crystal"), HudIcons.meteorCrystal)
		t.eq(MeteorIcon.resolve("Ice"), HudIcons.meteorIce)
		t.eq(MeteorIcon.resolve("Alien"), HudIcons.meteorAlien)
	end)

	t.test("Frost is an alias of Ice", function()
		t.eq(MeteorIcon.resolve("Frost"), HudIcons.meteorIce, "same asset id as Ice")
		t.eq(MeteorIcon.resolve("Frost"), MeteorIcon.resolve("Ice"), "both draw the same picture")
	end)

	t.test("unknown, empty, nil and wrong case fall back to the generic meteor", function()
		t.eq(MeteorIcon.resolve(nil), HudIcons.meteor)
		t.eq(MeteorIcon.resolve(""), HudIcons.meteor)
		t.eq(MeteorIcon.resolve("Lava"), HudIcons.meteor)
		t.eq(MeteorIcon.resolve("crystal"), HudIcons.meteor, "type ids match exactly, case included")
	end)

	t.test("resolve never hands back an empty or foreign image", function()
		local present = {}
		for _, id in HudIcons do
			present[id] = true
		end
		for _, typeId in { "Crystal", "Ice", "Frost", "Alien", "Lava", "", "crystal", "meteor" } do
			local image = MeteorIcon.resolve(typeId)
			t.eq(type(image), "string", tostring(typeId) .. " -> string")
			t.ok(image ~= "", "never empty")
			t.ok(present[image] == true, "always a real HudIcons value")
		end
		t.ok(present[MeteorIcon.resolve(nil)] == true, "nil too")
	end)

	t.test("the module is frozen", function()
		local ok = pcall(function()
			MeteorIcon.resolve = function(_: string?): string return "" end
		end)
		t.eq(ok, false, "swapping resolve out errors")
	end)
end

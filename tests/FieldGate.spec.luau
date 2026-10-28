--!strict
-- The gate ladder: which ore fields a player may mine, from their level and rebirths (Config.Debris.Fields[].Unlock)
return function(t)
	local Gate = require(t.shared.FieldGate)
	local find = require(t.shared.FieldTravel).find
	local Config = require(t.shared.Config)

	local function field(id: string): any
		local f = find(id)
		assert(f, "no field " .. id)
		return f
	end

	t.test("rust works is open to a brand new player", function()
		t.eq(Gate.isOpen(field("RustWorks"), 1, 0), true)
	end)

	t.test("level gates open at their level and not before", function()
		t.eq(Gate.isOpen(field("FrostYard"), 4, 0), false)
		t.eq(Gate.isOpen(field("FrostYard"), 5, 0), true)
		t.eq(Gate.isOpen(field("VioletQuarry"), 11, 0), false)
		t.eq(Gate.isOpen(field("VioletQuarry"), 12, 0), true)
		t.eq(Gate.isOpen(field("SulfurRidge"), 20, 0), true)
		t.eq(Gate.isOpen(field("SulfurRidge"), 19, 5), false, "rebirths don't stand in for level")
	end)

	t.test("rebirth gates ignore level", function()
		t.eq(Gate.isOpen(field("EmberShelf"), 50, 2), false)
		t.eq(Gate.isOpen(field("EmberShelf"), 1, 3), true)
		t.eq(Gate.isOpen(field("GlassScar"), 1, 5), true)
		t.eq(Gate.isOpen(field("Starfall"), 50, 7), false)
		t.eq(Gate.isOpen(field("Starfall"), 1, 8), true)
		t.eq(Gate.isOpen(field("HaloLedge"), 50, 9), false)
		t.eq(Gate.isOpen(field("HaloLedge"), 1, 10), true)
	end)

	t.test("labels name the rule", function()
		t.eq(Gate.label(field("RustWorks")), "Open")
		t.eq(Gate.label(field("FrostYard")), "Level 5")
		t.eq(Gate.label(field("HaloLedge")), "Rebirth 10")
	end)

	t.test("the ladder runs in the design's order and only climbs", function()
		local ids = {}
		for _, f in require(t.shared.FieldTravel).inWorld(1) do table.insert(ids, f.Id) end
		t.eq(table.concat(ids, ","), "RustWorks,FrostYard,XpMine,VioletQuarry,SulfurRidge,EmberShelf,GlassScar,Starfall,HaloLedge")
		local rift = {}
		for _, f in require(t.shared.FieldTravel).inWorld(2) do table.insert(rift, f.Id) end
		t.eq(table.concat(rift, ","), "CometDrift,StarlightShelf,EventHorizon", "Nebula Rift's three")
		local lastLevel = 0
		for _, f in Config.Debris.Fields do
			local unlock = f.Unlock
			if unlock and unlock.Level then
				t.ok(unlock.Level > lastLevel, f.Id .. " level gate does not climb")
				lastLevel = unlock.Level
			end
		end
	end)
end

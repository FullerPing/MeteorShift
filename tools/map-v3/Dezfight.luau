-- Map v3 finishing pass. Load Common first; run after every other building stage (re-run after rebuilding any of them):
--   L("../map-v3/Dezfight", L("../map-v3/Overlap"))
-- Finds every visible pair of flush, same-way faces (Coplanar) and moves the part with the smaller face NUDGE studs out
-- along that face's normal, so trims, strips, bands and landings sit just on top of what they were flush with instead of
-- flickering into it. A part is moved once per pass; up to five passes catch the pairs a move creates.
local A = assert(_G.MapRedesignArt, "Run Common first")
local O = assert(..., "Pass the overlap helpers")
local H = game:GetService("HttpService")
local NUDGE = 0.12
local source = H:GetAsync("http://127.0.0.1:8123/map-v3/Coplanar.luau", true)
local moved, passes, everMoved = 0, {}, {}
for pass = 1, 5 do
	local found = assert(loadstring(source, "Coplanar"))(O)
	table.insert(passes, #found.list)
	if #found.list == 0 then break end
	local done = {}
	for _, pair in found.list do
		-- the smaller part, unless an earlier pass already moved it (two equal parts would otherwise swap forever)
		local p = if everMoved[pair.p] and not everMoved[pair.q] then pair.q else pair.p
		if not done[pair.p] and not done[pair.q] then
			done[p] = true
			everMoved[p] = true
			p.CFrame += pair.normal * NUDGE
			moved += 1
		end
	end
	task.wait()
end
return { stage = "Dezfight", moved = moved, pairsPerPass = passes }

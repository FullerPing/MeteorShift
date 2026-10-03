--!strict
-- Edit-time authoring for the rounded mountains outside the playable area.
-- Run once in Studio's command bar (or execute_luau in Edit mode) with Play stopped,
-- check the skyline, then save the place. Nothing in the game runs this: the
-- terrain is saved in the place like the rest of the map.
--
-- Three rings, all past the boundary ridge (radius ~300) on the flat sand:
--   Near     rounded peaks at radius 430-520 that rise over the ridge from inside the
--            playable area
--   Middle   massifs filling the gaps in the existing mountain ring (radius 600-900)
--   Far      tall peaks at radius 1000-1200 that the haze turns into a soft skyline
-- Every peak has a rounded summit and flanks that ease into the sand (no sharp
-- tips). Same materials as the existing mountains: Rock flanks, Basalt bands, Slate tops.
--
-- Only adds terrain (occupancy never goes down) and is deterministic, so running it
-- again lands on the same shapes. One undo waypoint covers the whole pass.

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local terrain = workspace.Terrain
local GROUND = 2 -- the sand's surface height out here
local CELL = 4

type Peak = { x: number, z: number, h: number, r: number, p: number, seed: number }

local peaks: { Peak } = {}
local rng = Random.new(20261003)

local function addPeak(x: number, z: number, height: number, base: number, sharpness: number)
	table.insert(peaks, { x = x, z = z, h = height, r = base, p = sharpness, seed = #peaks * 7.31 + 3.7 })
end

-- A main peak with one or two lower shoulders, so it reads as a mountain, not a dome
local function massif(angleDeg: number, radius: number, height: number, base: number, sharpness: number, shoulders: number)
	local a = math.rad(angleDeg)
	local x, z = math.cos(a) * radius, math.sin(a) * radius
	addPeak(x, z, height, base, sharpness)
	for _ = 1, shoulders do
		local dir = rng:NextNumber(0, math.pi * 2)
		local offset = base * rng:NextNumber(0.35, 0.6)
		addPeak(
			x + math.cos(dir) * offset,
			z + math.sin(dir) * offset,
			height * rng:NextNumber(0.5, 0.75),
			base * rng:NextNumber(0.55, 0.75),
			sharpness * rng:NextNumber(0.9, 1.1)
		)
	end
end

-- Near: sixteen peaks, each with a smaller one beside it
for i = 0, 15 do
	massif(
		i * 22.5 + rng:NextNumber(-6, 6),
		rng:NextNumber(440, 520),
		rng:NextNumber(55, 90),
		rng:NextNumber(45, 60),
		rng:NextNumber(1.6, 2),
		1
	)
end

-- Middle: the gaps between the existing massifs (angles measured from +X toward +Z)
local gaps = { 0, 45, 70, 120, 145, 170, 200, 237, 287, 322, 342 }
for index, angle in gaps do
	massif(
		angle + rng:NextNumber(-3, 3),
		({ 640, 760, 700 })[(index - 1) % 3 + 1] + rng:NextNumber(-30, 30),
		rng:NextNumber(100, 150),
		rng:NextNumber(75, 95),
		rng:NextNumber(1.6, 2),
		rng:NextInteger(1, 2)
	)
end

-- Far: a skyline of eighteen tall peaks
for i = 0, 17 do
	massif(
		i * 20 + rng:NextNumber(-7, 7),
		rng:NextNumber(1000, 1200),
		rng:NextNumber(170, 250),
		rng:NextNumber(130, 170),
		rng:NextNumber(1.6, 2),
		2
	)
end

-- The profile (1 - t^2)^p is flat at the summit and at the foot, so tops are rounded
-- and flanks ease into the sand. The footprint radius wobbles with the angle around
-- the peak (up to ~1.34x), so buttresses and gullies run down the flanks; a little
-- noise roughens the surface.
local REACH = 1.4

local function peakHeight(peak: Peak, x: number, z: number): number
	local dx, dz = x - peak.x, z - peak.z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance >= peak.r * REACH then
		return 0
	end
	local angle = math.atan2(dz, dx)
	local wobble = 1
		+ 0.22 * math.noise(math.cos(angle) * 1.7 + peak.seed, math.sin(angle) * 1.7, peak.seed)
		+ 0.12 * math.sin(angle * 5 + peak.seed)
	local t = distance / (peak.r * wobble)
	if t >= 1 then
		return 0
	end
	local rough = 1 + 0.07 * math.noise(x / 11, z / 11, peak.seed)
	return peak.h * (1 - t * t) ^ peak.p * rough
end

-- Height above the sand at a column, and the peak that gives it
local function column(x: number, z: number, nearby: { Peak }): (number, Peak?)
	local best, owner = 0, nil
	for _, peak in nearby do
		local h = peakHeight(peak, x, z)
		if h > best then
			best, owner = h, peak
		end
	end
	return best, owner
end

local function material(x: number, y: number, z: number, owner: Peak): Enum.Material
	if y >= GROUND + owner.h * 0.58 then
		return Enum.Material.Slate
	end
	if math.noise(x / 26, y / 15, z / 26) > 0.28 then
		return Enum.Material.Basalt
	end
	return Enum.Material.Rock
end

local function overlaps(a: Peak, minX: number, maxX: number, minZ: number, maxZ: number): boolean
	local reach = a.r * REACH
	return a.x + reach > minX and a.x - reach < maxX and a.z + reach > minZ and a.z - reach < maxZ
end

local recording = ChangeHistoryService:TryBeginRecording("Author rounded mountains")
local written = 0

for _, peak in peaks do
	local reach = peak.r * REACH
	local minX, maxX = peak.x - reach, peak.x + reach
	local minZ, maxZ = peak.z - reach, peak.z + reach
	local nearby = {}
	for _, other in peaks do
		if overlaps(other, minX, maxX, minZ, maxZ) then
			table.insert(nearby, other)
		end
	end
	local top = GROUND
	for _, other in nearby do
		top = math.max(top, GROUND + other.h * 1.1)
	end

	-- Slabs 64 studs wide keep each read/write region small
	local x0 = math.floor(minX / CELL) * CELL
	while x0 < maxX do
		local region = Region3.new(
			Vector3.new(x0, -CELL, math.floor(minZ / CELL) * CELL),
			Vector3.new(x0 + 64, top + CELL * 2, math.ceil(maxZ / CELL) * CELL)
		):ExpandToGrid(CELL)
		local origin = region.CFrame.Position - region.Size / 2
		local materials, occupancy = terrain:ReadVoxels(region, CELL)
		local size = materials.Size
		for ix = 1, size.X do
			local x = origin.X + (ix - 0.5) * CELL
			for iz = 1, size.Z do
				local z = origin.Z + (iz - 0.5) * CELL
				local height, owner = column(x, z, nearby)
				if owner and height >= 1 then
					local surface = GROUND + height
					for iy = 1, size.Y do
						local bottom = origin.Y + (iy - 1) * CELL
						-- Occupancy's boundary sits at the voxel centre, hence the half cell
						local fill = math.clamp((surface - CELL / 2 - bottom) / CELL, 0, 1)
						if fill > occupancy[ix][iy][iz] then
							occupancy[ix][iy][iz] = fill
							materials[ix][iy][iz] = material(x, bottom + CELL / 2, z, owner)
						end
					end
				end
			end
		end
		terrain:WriteVoxels(region, CELL, materials, occupancy)
		written += 1
		x0 += 64
		task.wait()
	end
end

workspace.Map:SetAttribute("MountainsPass", #peaks)
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

return { peaks = #peaks, regions = written }

-- Standalone Edit-time resize of existing staged boundary art only.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before authoring")
local map = assert(workspace:FindFirstChild("Map_Redesign"))
assert(map:GetAttribute("MapRedesignOwned"), "Unowned staged map")
local boundary = assert(map:FindFirstChild("Boundary"))
assert(boundary:GetAttribute("MapRedesignOwned"), "Unowned boundary")
local offset = assert(map:GetAttribute("StageOffset"))
assert(typeof(offset) == "Vector3", "Missing staging offset")
local half, height, thickness, bottom = 270, 28, 16, -4
local top, cliffWidth = bottom+height, 32
local edits, untouched = {}, {}
local function edit(name, size, frame)
	local part = assert(boundary:FindFirstChild(name), "Missing " .. name)
	assert(part:IsA("BasePart") and part.Anchored and part.CanCollide
		and part:GetAttribute("MapRedesignOwned"), "Invalid boundary part")
	assert(not edits[part], "Duplicate boundary target")
	edits[part] = {size, frame}
end
for _,sign in {-1,1} do
	edit("EastWestWall"..sign, Vector3.new(thickness,height,half*2+thickness*2),
		CFrame.new(offset+Vector3.new(sign*(half+thickness/2),bottom+height/2,0)))
	edit("NorthSouthWall"..sign, Vector3.new(half*2+thickness*2,height,thickness),
		CFrame.new(offset+Vector3.new(0,bottom+height/2,sign*(half+thickness/2))))
end
for side=0,3 do
	for index=0,15 do
		local part = assert(boundary:FindFirstChild("Cliff"..side.."_"..index))
		local cliffHeight = 14+(index%3)*4
		local position = part.Position
		local frame = CFrame.new(position.X,offset.Y+top+cliffHeight/2,position.Z)*part.CFrame.Rotation
		for _,sx in {-1,1} do for _,sz in {-1,1} do
			local corner = frame*Vector3.new(sx*cliffWidth/2,0,sz*cliffWidth/2)-offset
			assert((if side<2 then math.abs(corner.X) else math.abs(corner.Z))>=half,
				"Cliff intrudes into playable area")
		end end
		edit(part.Name, Vector3.new(cliffWidth,cliffHeight,cliffWidth), frame)
	end
end
local editCount = 0
for _ in edits do editCount += 1 end
assert(editCount == 68, "Expected four walls and 64 cliffs")
local function snapshot(root)
	for _,part in root:GetDescendants() do
		if part:IsA("BasePart") then
			untouched[part] = {part.CFrame,part.Size,part.Anchored,part.CanCollide,
				part.CanTouch,part.CanQuery}
		end
	end
end
snapshot(map)
snapshot(assert(workspace:FindFirstChild("Map")))
local changed = 0
for part, desired in edits do
	if part.Size ~= desired[1] or part.CFrame ~= desired[2] then changed += 1 end
	part.Size, part.CFrame = desired[1], desired[2]
end
for part, before in untouched do
	if not edits[part] then
		assert(part.CFrame==before[1] and part.Size==before[2], "Unrelated geometry changed")
	end
	assert(part.Anchored==before[3] and part.CanCollide==before[4]
		and part.CanTouch==before[5] and part.CanQuery==before[6], "Collision changed")
end
map:SetAttribute("SmallBoundaryVersion", 1)
boundary:SetAttribute("WallHeight", height)
boundary:SetAttribute("CliffMaximumY", top+22)
return {stage="SmallBoundary",changedParts=changed,targetParts=editCount,
	wallHeight=height,wallThickness=thickness,wallBottom=bottom,wallTop=top,
	cliffWidth=cliffWidth,cliffTopRange={top+14,top+22},playableSpan=half*2,
	unrelatedGeometryAndAllCollisionPreserved=true}

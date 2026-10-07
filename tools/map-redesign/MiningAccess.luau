-- Common first, in Edit. The owner's ground-only revision retires elevated access.
local RunService=game:GetService("RunService")
assert(RunService:IsStudio() and not RunService:IsRunning(),"Studio Edit required")
local A=assert(_G.MapRedesignArt,"Run current Common first")
assert(A.geometry and A.crater,"Run current Common first")
assert(A.map and A.map==workspace:FindFirstChild("Map_Redesign") and A.map:GetAttribute("MapRedesignOwned"),
	"Owned staged map required")
local crater=assert(A.map:FindFirstChild("Crater"),"Staged crater missing")
assert(crater:GetAttribute("MapRedesignOwned"),"Unowned staged crater")
local access=crater:FindFirstChild("MiningAccess")
local removedParts=0
if access then
	assert(access:GetAttribute("MapRedesignOwned"),"Refusing to remove unowned MiningAccess")
	removedParts=A.count(access)
	access:Destroy()
end
assert(not crater:FindFirstChild("MiningAccess"),"Elevated mining access remains")
A.map:SetAttribute("MiningAccessPass",nil)
A.map:SetAttribute("MiningAccessMode","GroundOnly")
return {stage="MiningAccess",mode="GroundOnly",removedParts=removedParts,parts=0,
	rerunnable=true,totalParts=A.count(A.map)}

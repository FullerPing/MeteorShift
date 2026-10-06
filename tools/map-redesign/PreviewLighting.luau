-- Temporary Edit visual QA only. Run RestoreLightingPreview before saving or Play.
assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
assert(not _G.MapRedesignLightingPreview, "Restore the existing preview first")
local profile = assert(workspace.Map_Redesign.Atmosphere:FindFirstChild("LightingProfile"))
local lighting, terrain = game:GetService("Lighting"), workspace.Terrain
local properties = {
	"ClockTime", "GeographicLatitude", "Brightness", "ExposureCompensation", "Ambient",
	"OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom", "GlobalShadows", "ShadowSoftness",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale", "FogColor", "FogStart", "FogEnd",
}
local state = {properties={}, originalEffects=lighting:GetChildren(), originalClouds={}, temporary={}}
for _,name in properties do state.properties[name]=lighting[name] end
for _,v in terrain:GetChildren() do
	if v:IsA("Clouds") then table.insert(state.originalClouds,v) end
end
local function restore()
	for _,v in state.temporary do v:Destroy() end
	for name,value in state.properties do lighting[name]=value end
	for _,v in state.originalEffects do v.Parent=lighting end
	for _,v in state.originalClouds do v.Parent=terrain end
	_G.MapRedesignLightingPreview=nil
end
state.restore=restore
_G.MapRedesignLightingPreview=state
local ok,problem=pcall(function()
	for _,v in state.originalEffects do v.Parent=nil end
	for _,v in state.originalClouds do v.Parent=nil end
	for _,name in properties do lighting[name]=assert(profile:GetAttribute(name),name) end
	for _,v in profile:GetChildren() do
		if v.Name~="CloudSettings" then
			assert(v:IsA("Sky") or v:IsA("Atmosphere") or v:IsA("PostEffect"),"Unexpected profile child")
			local copy=v:Clone()
			table.insert(state.temporary,copy)
			copy.Parent=lighting
		end
	end
	local cloud=Instance.new("Clouds")
	table.insert(state.temporary,cloud)
	for _,name in {"Enabled","Cover","Density","Color"} do
		cloud[name]=assert(profile.CloudSettings:GetAttribute(name),name)
	end
	cloud.Parent=terrain
end)
if not ok then restore(); error(problem) end
return {temporaryPreviewActive=true,properties=#properties,effects=#state.temporary,restoreBeforeSave=true}

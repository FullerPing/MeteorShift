-- Restore actual original effect instances and property values; no saved scripts.
local state=assert(_G.MapRedesignLightingPreview,"No lighting preview is active")
state.restore()
local lighting=game:GetService("Lighting")
local comparisons=0
for name,value in state.properties do
	assert(lighting[name]==value,"Lighting restore mismatch: "..name)
	comparisons+=1
end
for _,v in state.originalEffects do assert(v.Parent==lighting) end
for _,v in state.originalClouds do assert(v.Parent==workspace.Terrain) end
return {restored=true,propertyComparisons=comparisons,originalEffects=#state.originalEffects,
	originalClouds=#state.originalClouds,previewActive=false}

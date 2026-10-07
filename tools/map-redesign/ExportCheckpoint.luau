-- Serializes staging data only. Does not save/publish or replace final asset files.
assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")
assert(not _G.MapRedesignLightingPreview,"Restore temporary lighting before checkpoint export/save")
local map=assert(workspace:FindFirstChild("Map_Redesign"))
assert(map:GetAttribute("MapRedesignOwned"),"Unowned staged map")
local scaled=assert(_G.MapRedesignScaledAssets or game.ServerStorage:FindFirstChild("Assets_Redesign"),
	"Verified doubled meteor assets required")
assert(scaled:GetAttribute("MapRedesignOwned"),"Unowned staged assets")
local snapshot=map:Clone()
snapshot.WorldPivot=CFrame.new(0,0,3000)
for _,v in snapshot:GetDescendants() do
	if v:GetAttribute("PreviewOnly") then v:Destroy() end
	-- Staging exports never retain the temporary new-map Play spawn selection.
	if v:IsA("SpawnLocation") then v.Enabled=false end
end
local ref=map.TownSquare.Refinery:Clone()
ref:PivotTo(ref:GetPivot()-Vector3.new(0,0,3000))
local assets=scaled:Clone()
local lighting=assert(map.Atmosphere:FindFirstChild("LightingProfile"),"Run Lighting first"):Clone()
lighting.Name="Lighting_Redesign"
local entries={
	{"Map_Redesign.rbxm",snapshot},
	{"ServerAssets_Redesign.rbxm",assets},
	{"Refinery_Redesign.rbxm",ref},
	{"Lighting_Redesign.rbxm",lighting},
}
local serializer=game:GetService("SerializationService")
local encoder=game:GetService("EncodingService")
_G.MapRedesignStageExportStrings={}
local manifest={}
for _,entry in entries do
	local name,root=entry[1],entry[2]
	local parts,scripts=0,0
	for _,v in root:GetDescendants() do
		if v:IsA("BasePart") then parts+=1 end
		if v:IsA("LuaSourceContainer") then scripts+=1 end
	end
	assert(scripts==0,"Checkpoint contains scripts")
	local bytes=serializer:SerializeInstancesAsync({root})
	local encoded=buffer.tostring(encoder:Base64Encode(bytes))
	_G.MapRedesignStageExportStrings[name]=encoded
	local restored=serializer:DeserializeInstancesAsync(bytes)
	assert(#restored==1 and restored[1].Name==root.Name,"Serialization roundtrip failed")
	local restoredParts=0
	for _,v in restored[1]:GetDescendants() do if v:IsA("BasePart") then restoredParts+=1 end end
	assert(restoredParts==parts,"Roundtrip part count changed")
	for name,value in root:GetAttributes() do
		assert(restored[1]:GetAttribute(name)==value,"Roundtrip attribute changed: "..name)
	end
	local pivot=if root:IsA("Model") then root:GetPivot().Position else nil
	table.insert(manifest,{file=name,bytes=buffer.len(bytes),base64Chars=#encoded,parts=parts,
		pivot=if pivot then {pivot.X,pivot.Y,pivot.Z} else nil,scripts=scripts,roundtripPassed=true})
	restored[1]:Destroy()
	root:Destroy()
end
return {stagingOnly=true,published=false,placeSavePerformed=false,files=manifest}

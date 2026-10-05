-- Run after Common. Stores an inactive lighting profile inside the staged map.
-- No saved scripts, no live Lighting/Terrain changes and no publishing.
local atmosphere = assert(A.map:FindFirstChild("Atmosphere"), "Run Routes first")
local backup = assert(_G.MapRedesignBackup, "Pristine baseline required")
local pristine = assert(backup.lighting, "Lighting rollback snapshot required")
local previous = atmosphere:FindFirstChild("LightingProfile")
if previous then
	assert(previous:GetAttribute("MapRedesignOwned"), "Unowned lighting profile")
	previous:Destroy()
end
local profile = pristine:Clone()
profile.Name = "LightingProfile"
profile:SetAttribute("MapRedesignOwned", true)
profile:SetAttribute("LightingProfileVersion", 1)
profile:SetAttribute("PendingVisualQA", true)
local properties = {
	ClockTime = 14,
	GeographicLatitude = 0,
	Brightness = 2.5,
	ExposureCompensation = 0.1,
	Ambient = Color3.fromRGB(104,116,143),
	OutdoorAmbient = Color3.fromRGB(132,143,166),
	ColorShift_Top = Color3.fromRGB(255,248,232),
	ColorShift_Bottom = Color3.new(0,0,0),
	GlobalShadows = true,
	ShadowSoftness = 0.3,
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.35,
	FogColor = Color3.fromRGB(184,221,255),
	FogStart = 900,
	FogEnd = 2000,
}
for name,value in properties do profile:SetAttribute(name,value) end
local haze = assert(profile:FindFirstChildWhichIsA("Atmosphere"))
haze.Density, haze.Offset = 0.17, 0.1
haze.Color, haze.Decay = Color3.fromRGB(177,225,255), Color3.fromRGB(153,191,235)
haze.Haze, haze.Glare = 0.5, 0.03
local bloom = assert(profile:FindFirstChildWhichIsA("BloomEffect"))
bloom.Enabled, bloom.Intensity, bloom.Size, bloom.Threshold = true, 0.08, 18, 1.35
local grade = assert(profile:FindFirstChildWhichIsA("ColorCorrectionEffect"))
grade.Enabled, grade.Brightness, grade.Contrast, grade.Saturation = true, 0, 0.025, 0.06
grade.TintColor = Color3.new(1,1,1)
local sun = assert(profile:FindFirstChildWhichIsA("SunRaysEffect"))
sun.Enabled, sun.Intensity, sun.Spread = true, 0.015, 0.7
local depth = assert(profile:FindFirstChildWhichIsA("DepthOfFieldEffect"))
depth.Enabled = false
local clouds = assert(profile:FindFirstChildWhichIsA("Clouds"))
clouds:Destroy()
-- Clouds must be directly under Terrain. Keep only data while staging in Workspace.
local cloudSettings = Instance.new("Folder")
cloudSettings.Name = "CloudSettings"
cloudSettings:SetAttribute("TargetClass", "Clouds")
cloudSettings:SetAttribute("TargetParent", "Workspace.Terrain")
cloudSettings:SetAttribute("Enabled", true)
cloudSettings:SetAttribute("Cover", 0.2)
cloudSettings:SetAttribute("Density", 0.3)
cloudSettings:SetAttribute("Color", Color3.fromRGB(247,251,255))
cloudSettings.Parent = profile
for _,instance in profile:GetDescendants() do
	assert(not instance:IsA("LuaSourceContainer"), "Lighting profile contains code")
end
profile.Parent = atmosphere
return {
	stage = "Lighting", profile = profile:GetFullName(), effects = #profile:GetChildren()-1,
	cloudSettingsStagedAsData = true,
	clockTime = profile:GetAttribute("ClockTime"), brightness = profile:GetAttribute("Brightness"),
	hazeDensity = haze.Density, depthOfFieldEnabled = depth.Enabled,
	liveLightingUnchanged = true, visualQAPending = true,
}

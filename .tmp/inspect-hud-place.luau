local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local place = roblox.deserializePlace(fs.readFile("MeteorShift-newest.rbxl"))
for _, service in place:GetChildren() do
	print(service.Name, service.ClassName, #service:GetChildren(), #service:GetDescendants())
end
for _, child in place:GetService("ServerStorage"):GetChildren() do print("SERVER_STORAGE", child.Name, child.ClassName, #child:GetDescendants()) end
for _, path in {{"ReplicatedStorage", "Shared"}, {"ReplicatedStorage", "Packages"}, {"ServerScriptService", "Server"}, {"ServerStorage", "Tests"}, {"StarterPlayer", "StarterPlayerScripts", "Client"}} do
	local item = place
	for _, name in path do item = item:FindFirstChild(name) end
	print("SUBTREE", table.concat(path, "/"), item and item.ClassName, item and #item:GetDescendants())
	if item then
		for _, d in item:GetDescendants() do
			if not d:IsA("LuaSourceContainer") and not d:IsA("Folder") then
				print("NON_SOURCE", d:GetFullName(), d.ClassName)
			end
		end
	end
end

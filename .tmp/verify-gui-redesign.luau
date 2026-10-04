local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local process = require("@lune/process")
local entries = {
	{"src/client/UI.luau", {"StarterPlayer", "StarterPlayerScripts", "Client", "UI"}},
	{"src/client/HudView.luau", {"StarterPlayer", "StarterPlayerScripts", "Client", "HudView"}},
	{"src/client/Controllers/HUDController.luau", {"StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "HUDController"}},
	{"src/client/Controllers/IndexController.luau", {"StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "IndexController"}},
	{"src/client/Controllers/ShopController.luau", {"StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "ShopController"}},
	{"src/client/Controllers/StoreController.luau", {"StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "StoreController"}},
	{"src/client/Controllers/RebirthController.luau", {"StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "RebirthController"}},
	{"src/shared/Config/Hud.luau", {"ReplicatedStorage", "Shared", "Config", "Hud"}},
	{"src/shared/HudLayout.luau", {"ReplicatedStorage", "Shared", "HudLayout"}},
	{"src/shared/HudMessages.luau", {"ReplicatedStorage", "Shared", "HudMessages"}},
	{"tests/HudMessages.spec.luau", {"ServerStorage", "Tests", "HudMessages.spec"}},
	{"tests/HudLayout.spec.luau", {"ServerStorage", "Tests", "HudLayout.spec"}},
}
local saved = if process.args[1] then roblox.deserializePlace(fs.readFile(process.args[1])) else nil
local function normalized(source)
	return (source:gsub("\r\n", "\n"))
end
for _, entry in entries do
	local source = fs.readFile(entry[1])
	assert(luau.load(source), "Compilation failed: " .. entry[1])
	if saved then
		local instance = saved
		for _, name in entry[2] do
			instance = assert(instance:FindFirstChild(name), "Missing saved module: " .. entry[1])
		end
		assert(normalized(instance.Source) == normalized(source), "Saved source mismatch: " .. entry[1])
	end
end
if saved then
	for _, instance in saved:GetDescendants() do
		assert(not instance.Name:match("^Menu.*PreviewQA$"), "Temporary preview saved: " .. instance.Name)
	end
end
print(tostring(#entries) .. " GUI sources compile" .. (if saved then " and match the saved place" else ""))

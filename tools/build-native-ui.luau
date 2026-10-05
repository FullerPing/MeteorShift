--!strict
-- Run in Studio Edit mode after syncing source. Build once, then edit StarterGui.
-- Re-running replaces these generated menus; the owner's button reference is preserved.
local authors = game.StarterPlayer.StarterPlayerScripts.Client.NativeMenus
local names = { "Shop", "Refinery", "Index", "Rebirth", "Store", "Hatch", "Settings", "Backpack", "WelcomeBack" }
local results = {}
for _, name in names do
	local module = authors:FindFirstChild(name)
	assert(module and module:IsA("ModuleScript"), "Missing native author: " .. name)
	local fresh = module:Clone()
	fresh.Parent = authors
	local ok, result = pcall(function() return require(fresh).build() end)
	fresh:Destroy()
	assert(ok, tostring(result))
	local gui = result :: ScreenGui
	local previous = game.StarterGui:FindFirstChild(gui.Name)
	if previous then
		assert(previous:IsA("ScreenGui"), "Name conflict: " .. gui.Name)
		previous:Destroy()
	end
	gui.Parent = game.StarterGui
	table.insert(results, gui.Name)
end
local ExactNavButton = require(game.StarterPlayer.StarterPlayerScripts.Client.ExactNavButton)
local Icons = require(game.ReplicatedStorage.Shared.Config.HudIcons)
for _, definition in {
	{ "GearShop", "ShopButton", "Gear", Icons.equipment },
	{ "MineralIndex", "IndexButton", "Index", Icons.index },
	{ "Rebirth", "RebirthButton", "Rebirth", Icons.rebirth },
	{ "Store", "StoreButton", "Store", Icons.premium },
} do
	ExactNavButton.author(game.StarterGui[definition[1]], definition[2], definition[3], definition[4])
end
-- Keep the editable source instead of showing an unwired duplicate at runtime.
game.StarterGui["MY index button"].Enabled = false
return results

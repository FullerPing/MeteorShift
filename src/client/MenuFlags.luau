--!strict
-- The one list of player attributes a menu sets while it is open. Consumers that must ignore some
-- (their own flag, or the small Backpack popup) build their list with MenuFlags.except.
local Players = game:GetService("Players")
local MenuFlags = {}

MenuFlags.ALL = {
	"ShopOpen", "PetsOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "DailyOpen", "CodesOpen", "PerksOpen",
	"OreFieldsOpen", "OfferPreviewOpen", "RefineryOpen", "SettingsOpen", "HatchOpen", "IntroOpen",
	"WelcomeBackOpen", "BackpackOpen", "QuestsOpen",
}

function MenuFlags.except(...: string): { string }
	local skip: { [string]: boolean } = {}
	for _, name in { ... } do skip[name] = true end
	local list = {}
	for _, name in MenuFlags.ALL do
		if not skip[name] then table.insert(list, name) end
	end
	return list
end

function MenuFlags.anyOpen(flags: { string }?): boolean
	local player = Players.LocalPlayer
	for _, name in flags or MenuFlags.ALL do
		if player:GetAttribute(name) == true then return true end
	end
	return false
end

-- Calls `callback(name, open)` whenever one of `flags` changes.
function MenuFlags.onChanged(flags: { string }, callback: (string, boolean) -> ()): { RBXScriptConnection }
	local player = Players.LocalPlayer
	local connections = {}
	for _, name in flags do
		table.insert(connections, player:GetAttributeChangedSignal(name):Connect(function()
			callback(name, player:GetAttribute(name) == true)
		end))
	end
	return connections
end

return MenuFlags

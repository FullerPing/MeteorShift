local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local client = player.PlayerScripts:WaitForChild("Client")
local UI = require(client.UI)
local controller = require(client.Controllers.RefineryController)
while not controller.Gui do task.wait() end
local oldGui, oldHud, oldGet = player.PlayerGui:FindFirstChild("RefineryMenu") or controller.Gui, UI.hud, Knit.GetService
local viewportValue
local snapshot = {
	plotId = 1, refinePriority = { "iron", "crystal", "frost" },
	hopperInventory = { iron = 20, crystal = 12, frost = 8 }, collectorInventory = { iron = 2, crystal = 3, frost = 1 },
	line = { rate = 0.75, hopper = { amount = 40 }, collector = { amount = 6 }, refinery = { level = 2, activeOre = "iron", progress = 0.45 } },
}
local opened = Instance.new("BindableEvent")
UI.hud = function(scope)
	viewportValue = scope:Value({ viewport = Vector2.new(1280, 720), inset = 58 })
	return viewportValue
end
Knit.GetService = function(name)
	if name == "PlayerStateService" then return { State = { Observe = function(_, fn) fn(snapshot) end } } end
	if name == "RefineryService" then return { Open = opened.Event, SetPriority = function() return true end } end
	return oldGet(name)
end
local ok, problem = pcall(function() controller:KnitStart() end)
UI.hud, Knit.GetService = oldHud, oldGet
assert(ok, problem)
local gui = controller.Gui
gui.Name = "RefineryLayoutQA"
local checks, samples = 0, {}
local function check(condition, message) checks += 1; assert(condition, message) end
local function bottom(node) return node.AbsolutePosition.Y + node.AbsoluteSize.Y end
local function right(node) return node.AbsolutePosition.X + node.AbsoluteSize.X end
local panel = gui.Panel
for _, size in { Vector2.new(1280, 720), Vector2.new(390, 844), Vector2.new(568, 320), Vector2.new(844, 390), Vector2.new(320, 568) } do
	viewportValue:set({ viewport = size, inset = 58 })
	task.wait(0.15)
	check(panel.AbsolutePosition.X - gui.AbsolutePosition.X >= 12 and right(panel) - gui.AbsolutePosition.X <= size.X - 11, "panel horizontal bounds")
	check(panel.AbsolutePosition.Y - gui.AbsolutePosition.Y >= 70 and bottom(panel) - gui.AbsolutePosition.Y <= size.Y - 11, "panel vertical bounds")
	check(panel.Inventory.AbsoluteSize.Y >= 52, "inventory must fit a row")
	check(bottom(panel.Inventory) <= panel.ResetPriority.AbsolutePosition.Y - 7, "list overlaps footer")
	check(bottom(panel.Totals) <= panel.Inventory.AbsolutePosition.Y, "totals overlap list")
	local row = panel.Inventory.ironContents
	check(bottom(row) <= bottom(panel.Inventory) + 1, "first row clipped")
	check(right(row.Type) <= row.PriorityUp.AbsolutePosition.X, "name overlaps controls")
	for _, target in { panel.Close, panel.ResetPriority, row.PriorityUp, row.PriorityDown } do
		check(target.AbsoluteSize.X >= 44 and target.AbsoluteSize.Y >= 44, "target below 44 pixels")
	end
	for _, target in { row.PriorityUp, row.PriorityDown } do
		check(target.AbsolutePosition.Y >= panel.Inventory.AbsolutePosition.Y and bottom(target) <= bottom(panel.Inventory), "priority button clipped")
	end
	check(row.PriorityDown.Active, "queue priority control must be enabled")
	check(panel.Rate.Text:find("0.75", 1, true), "fractional rate missing")
	if panel.AbsoluteSize.Y < 340 then check(not panel.Hint.Visible and row.AbsoluteSize.Y == 52, "compact layout missing") end
	table.insert(samples, { viewport = { size.X, size.Y }, panel = { panel.AbsoluteSize.X, panel.AbsoluteSize.Y }, inventoryHeight = panel.Inventory.AbsoluteSize.Y })
end
local result = { success = true, checks = checks, samples = samples }
ReplicatedStorage:SetAttribute("RefineryLayoutQAResult", game:GetService("HttpService"):JSONEncode(result))
gui:Destroy()
opened:Destroy()
controller.Gui = oldGui
script:Destroy()

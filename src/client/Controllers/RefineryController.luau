--!strict
-- Named editable ScreenGui controls; production remains authoritative on the server.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Knit = require(RS.Packages.Knit)
local Queue = require(RS.Shared.RefineryQueue)
local Layout = require(RS.Shared.RefineryLayout)
local Home = require(RS.Shared.Config.Home)
local Format = require(RS.Shared.Format)
local Levels = require(RS.Shared.Levels)
local Config = require(RS.Shared.Config)
local Price = require(RS.Shared.Price)
local N = require(script.Parent.Parent.NativeUI)
local player = Players.LocalPlayer
local Controller = Knit.CreateController({ Name = "RefineryController" })
local OTHER_MENUS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "SettingsOpen" }
function Controller:Open()
	for _, name in OTHER_MENUS do if player:GetAttribute(name) then return end end
	player:SetAttribute("BackpackOpen", false); player:SetAttribute("FoundryExpanded", false)
	player:SetAttribute("RefineryOpen", true)
end
function Controller:Close() player:SetAttribute("RefineryOpen", false) end
function Controller:KnitStart()
	local service, upgrades = Knit.GetService("RefineryService"), Knit.GetService("UpgradeService")
	local gui = N.get("RefineryMenu")
	self.Gui = gui
	local p: any = gui.Panel
	local state: any = nil
	local transaction: string? = nil
	local upgrading: string? = nil
	local busy, page, feedback = false, "refine", ""
	local rowViews: { [string]: any } = {}
	local geometry = Layout.compute(570)
	local update: () -> ()
	local function save(order: { string })
		if busy then return end
		busy = true; update()
		task.spawn(function()
			local ok, accepted = pcall(function() return service:SetPriority(order) end)
			busy = false
			if not ok or not accepted then feedback = "Could not change refinery priority. Try again." end
			update()
		end)
	end
	local function queuedIds(): { string }
		local ids = {}
		for _, row in Queue.rows(state and state.hopperInventory, state and state.collectorInventory, state and state.refinePriority) do
			if row.ore > 0 and Home.OreNames[row.id] then table.insert(ids, row.id) end
		end
		return ids
	end
	local function move(id: string, direction: number)
		if busy or not state then return end
		local ids = queuedIds()
		local index = table.find(ids, id)
		local neighbor = index and ids[index + direction]
		if not neighbor then return end
		local order = Queue.order(state.refinePriority)
		local a, b = table.find(order, id), table.find(order, neighbor)
		if a and b then order[a], order[b] = order[b], order[a]; save(order) end
	end
	local function canAct(action: string): boolean
		if not state or not state.line or transaction then return false end
		return if action == "deposit" then state.carried > 0 and state.line.hopper.amount < state.line.hopper.capacity else state.line.collector.amount > 0
	end
	local function transact(action: string)
		if not canAct(action) then return end
		transaction, feedback = action, ""; update()
		task.spawn(function()
			local ok, amount = pcall(function() return if action == "deposit" then service:Deposit() else service:Claim() end)
			transaction = nil
			if not ok then feedback = "Couldn't complete that. Please try again."
			elseif type(amount) == "number" and amount > 0 then
				feedback = (if action == "deposit" then "Deposited " else "Claimed ") .. Format.number(amount) .. (if action == "deposit" then " ore." else " bars. Sell them at the Trading Post.")
			elseif feedback == "" then feedback = if action == "deposit" then "No ore deposited. Check your backpack and hopper space." else "No finished bars to claim yet." end
			update()
		end)
	end
	local units = { hopper = "ore capacity", conveyor = "ore/s", refinery = "bars/s", collector = "bar capacity" }
	local descriptions = { hopper = "Store more ore before depositing again.", conveyor = "Feed ore into the smelter faster.", refinery = "Smelt ore faster. The slower machine sets line speed.", collector = "Hold more finished bars between claims." }
	local function stat(id: string, entry: any): string
		return (if entry.Rate then string.format("%g", entry.Rate) else Format.number(entry.Capacity or 0)) .. " " .. units[id]
	end
	update = function()
		local l, line = geometry, state and state.line
		local refining = page == "refine"
		for _, action in { "deposit", "claim" } do
			local card: any = p[action .. "Card"]
			local amount = if action == "deposit" then (state and state.carried or 0) else (line and line.collector.amount or 0)
			card.Visible = refining
			card.Position = UDim2.new(if action == "deposit" then 0 else .5, if action == "deposit" then 16 else 4, 0, l.actions)
			card.Size = UDim2.new(.5, -20, 0, l.actionH)
			card.Quantity.Visible = not l.minimal
			card.Quantity.Text = Format.number(amount)
			card.Quantity.Position = UDim2.fromOffset(12, if l.compact then 4 else 8)
			card.Quantity.Size = UDim2.new(1, -24, 0, if l.compact then 24 else 30)
			card.Hint.Visible = not l.compact
			card.Hint.Text = if action == "deposit" and line then Format.number(math.max(0, line.hopper.capacity - line.hopper.amount)) .. " hopper space" else "Move bars to your backpack"
			card.Action.Position = UDim2.new(0, 8, 1, if l.minimal then -44 else -52)
			N.enable(card.Action, canAct(action), if action == "deposit" then N.ORANGE else N.GREEN)
			card.Action.Text = if transaction == action then (if action == "deposit" then "Depositing..." else "Claiming...")
				elseif not state then "Loading..."
				elseif action == "deposit" and line and line.hopper.amount >= line.hopper.capacity then "Hopper full"
				elseif l.minimal then (if action == "deposit" then "Deposit " else "Claim ") .. Format.number(amount) .. (if action == "deposit" then " ore" else " bars")
				else (if action == "deposit" then "Deposit ore" else "Claim bars")
		end
		p.refineTab.BackgroundColor3 = if refining then N.CYAN else N.CARD
		p.productionTab.BackgroundColor3 = if refining then N.CARD else N.ORANGE
		p.UpgradeWallet.Visible, p.ProductionUpgrades.Visible = not refining, not refining
		p.UpgradeWallet.Text = if state then Format.cash(state.cash) .. " · " .. Format.number(state.shards) .. " shards · Your production line" else "Loading..."
		p.ProductionUpgrades.Size = UDim2.new(1, -32, 1, -188)
		for _, id in Home.StationOrder do
			local card, def = p.ProductionUpgrades[id .. "Upgrade"], Home.Stations[id]
			local level = if line and line[id] then line[id].level else 1
			local nextLevel = def.Levels[level + 1]
			local enabled = state ~= nil and nextLevel ~= nil and upgrading == nil and transaction == nil and Price.canAfford(state, nextLevel.Cost, nextLevel.Shards)
			card.Station.Text = def.Name .. " · Level " .. level
			card.Improvement.Text = stat(id, def.Levels[level]) .. (if nextLevel then " → " .. stat(id, nextLevel) else " · MAX LEVEL")
			card.Purpose.Text = descriptions[id]
			N.enable(card.BuyUpgrade, enabled, N.ORANGE)
			card.BuyUpgrade.Text = if not state then "Loading..." elseif upgrading == id then "Upgrading..." elseif not nextLevel then "MAX LEVEL"
				else (if enabled then "UPGRADE" else "SAVE UP") .. "\n" .. Price.text(nextLevel.Cost, nextLevel.Shards)
		end
		local rows = Queue.rows(state and state.hopperInventory, state and state.collectorInventory, state and state.refinePriority)
		local visible, ids = {}, queuedIds()
		for index, row in rows do
			visible[row.id] = true
			local view = rowViews[row.id]
			if not view then
				view = gui.Templates.OreRow:Clone()
				view.Name, view.Parent = row.id .. "Contents", p.Inventory
				view.Visible = true
				view.PriorityUp.Activated:Connect(function() move(row.id, -1) end)
				view.PriorityDown.Activated:Connect(function() move(row.id, 1) end)
				rowViews[row.id] = view
			end
			view.LayoutOrder, view.Size = index, UDim2.new(1, -4, 0, l.row)
			view.Type.Position = UDim2.fromOffset(10, if l.compact then 2 else 6)
			view.Amount.Position = UDim2.fromOffset(10, if l.compact then 26 else 30)
			view.Type.Text = row.name .. (if line and line.refinery.activeOre == row.id then " · NEXT" else "")
			view.Type.TextTruncate = Enum.TextTruncate.AtEnd
			view.Amount.Text = Format.number(row.ore) .. " ore · " .. Format.number(row.bars) .. " ready bars"
			local speed = Levels.clearance(if state then state.level or 1 else 1, row.id)
			if speed < 1 then view.Amount.Text ..= string.format(" · %d%% speed, full at level %d", math.max(math.floor(speed * 100 + .5), 1), Config.Levels.OreLevel[row.id] or 1) end
			view.Amount.TextTruncate = Enum.TextTruncate.AtEnd
			for _, direction in { -1, 1 } do
				local button = if direction < 0 then view.PriorityUp else view.PriorityDown
				local at = table.find(ids, row.id)
				N.enable(button, not busy and row.ore > 0 and at ~= nil and ids[(at or 0) + direction] ~= nil, N.CYAN)
				button.Position = UDim2.new(1, if direction < 0 then -96 else -48, 0, if l.compact then 4 else 8)
			end
		end
		for id, row in rowViews do if not visible[id] then row:Destroy(); rowViews[id] = nil end end
		local r = line and line.refinery
		p.Status.Visible = refining and not l.hideStatus
		p.Status.Position = UDim2.fromOffset(16, l.status)
		p.Status.Text = if not r then "Loading your refinery..." elseif r.blocked == "collector" then "Storage full · claim bars to resume"
			elseif not r.activeOre then "Ready to work · deposit ore above" else "Refining " .. (Home.OreNames[r.activeOre] or r.activeOre)
		p.Progress.Visible, p.Progress.Position = refining, UDim2.fromOffset(16, l.progress)
		p.Progress.Fill.Size = UDim2.fromScale(if r and r.activeOre then r.progress or 0 else 0, 1)
		p.Totals.Visible, p.Totals.Position = refining and not l.hideStatus, UDim2.fromOffset(16, l.totals)
		p.Totals.Text = "REFINING ORDER · " .. Format.number(line and line.hopper.amount or 0) .. " queued ore"
		p.Inventory.Visible, p.Inventory.Position = refining, UDim2.fromOffset(16, l.list)
		p.Inventory.Size = UDim2.new(1, -32, 0, l.inventoryHeight)
		p.Empty.Visible, p.Empty.Position = refining and #rows == 0, UDim2.fromOffset(16, l.list)
		p.ResetPriority.Visible = refining
		p.ResetPriority.Text = if busy then "Saving..." else "Reset order"
		N.enable(p.ResetPriority, state ~= nil and not busy, N.CYAN)
		p.Feedback.Size = UDim2.new(1, if refining then -168 else -32, 0, 44)
		p.Feedback.Text = if feedback ~= "" then feedback elseif not refining then "Upgrade your line. Balance feeding and smelting speeds."
			elseif r and r.blocked == "collector" then "Claim bars to resume refining."
			elseif l.hideStatus and r and r.activeOre then "Refining " .. (Home.OreNames[r.activeOre] or r.activeOre)
			elseif #rows > 0 then "Use arrows to set refining order." else "Deposit ore. Claim finished bars."
	end
	p.depositCard.Action.Activated:Connect(function() transact("deposit") end)
	p.claimCard.Action.Activated:Connect(function() transact("claim") end)
	p.ResetPriority.Activated:Connect(function() if state then save({}) end end)
	for _, id in { "refine", "production" } do p[id .. "Tab"].Activated:Connect(function() page, feedback = id, ""; update() end) end
	for _, id in Home.StationOrder do
		p.ProductionUpgrades[id .. "Upgrade"].BuyUpgrade.Activated:Connect(function()
			local def = Home.Stations[id]
			local nextLevel = state and state.line and def.Levels[state.line[id].level + 1]
			if not nextLevel or upgrading or transaction or not Price.canAfford(state, nextLevel.Cost, nextLevel.Shards) then return end
			upgrading, feedback = id, ""; update()
			task.spawn(function()
				local ok, accepted = pcall(function() return upgrades:BuyStation(id) end)
				upgrading = nil
				if ok and accepted then feedback = def.Name .. " upgraded." elseif not ok then feedback = "Couldn't upgrade. Please try again." end
				update()
			end)
		end)
	end
	service.Notice:Connect(function(message) feedback = message; update() end)
	upgrades.Notice:Connect(function(message) feedback = message; update() end)
	Knit.GetService("PlayerStateService").State:Observe(function(snapshot) state = snapshot; update() end)
	service.Open:Connect(function() self:Open() end)
	N.bindOpen(gui, "RefineryOpen", function() self:Close() end)
	player:GetAttributeChangedSignal("RefineryOpen"):Connect(function() if gui.Enabled then page, feedback = "refine", ""; update() end end)
	for _, name in OTHER_MENUS do player:GetAttributeChangedSignal(name):Connect(function() if player:GetAttribute(name) then self:Close() end end) end
	player:GetAttributeChangedSignal("BackpackOpen"):Connect(function() if player:GetAttribute("BackpackOpen") then self:Close() end end)
	player:GetAttributeChangedSignal("PlotId"):Connect(function() if not player:GetAttribute("PlotId") then self:Close() end end)
	N.onLayoutChanged(function(hud)
		local w, h = math.min(620, hud.viewport.X - 24), math.min(570, hud.viewport.Y - hud.inset - 24)
		p.AnchorPoint = Vector2.zero
		p.Position = UDim2.fromOffset((hud.viewport.X - w) / 2, hud.inset + (hud.viewport.Y - hud.inset - h) / 2)
		p.Size = UDim2.fromOffset(w, h)
		geometry = Layout.compute(h)
		update()
	end)
end
return Controller

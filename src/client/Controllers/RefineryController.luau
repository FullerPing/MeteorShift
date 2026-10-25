--!strict
-- Named editable ScreenGui controls; production remains authoritative on the server.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local Knit = require(RS.Packages.Knit)
local Queue = require(RS.Shared.RefineryQueue)
local Layout = require(RS.Shared.RefineryLayout)
local MenuFit = require(RS.Shared.MenuFit)
local Home = require(RS.Shared.Config.Home)
local Format = require(RS.Shared.Format)
local Line = require(RS.Shared.Line)
local Config = require(RS.Shared.Config)
local Price = require(RS.Shared.Price)
local Rebirth = require(RS.Shared.Rebirth)
local WorldMap = require(RS.Shared.WorldMap)
local N = require(script.Parent.Parent.NativeUI)
local RefineryMenu = require(script.Parent.Parent.NativeMenus.Refinery)
local Theme = require(script.Parent.Parent.MenuTheme)
local Palette = require(RS.Shared.MenuPalette)
local UpgradePanel = require(script.Parent.Parent.UpgradePanel)
local player = Players.LocalPlayer
local Controller = Knit.CreateController({ Name = "RefineryController" })
local OTHER_MENUS = require(script.Parent.Parent.MenuFlags).except("RefineryOpen", "BackpackOpen")
local ORE_TINTS: { [string]: Color3 } = {
	iron = Color3.fromRGB(255, 196, 36), frost = Color3.fromRGB(120, 220, 255),
	crystal = Color3.fromRGB(221, 161, 255), alien = Color3.fromRGB(130, 255, 150),
	quartz = Color3.fromRGB(255, 190, 236), nebula = Color3.fromRGB(190, 160, 255),
	solar = Color3.fromRGB(255, 200, 90), eclipse = Color3.fromRGB(236, 130, 255),
}
-- colours that read on the cartoon light body (Shared.MenuPalette)
local STATUS_RED, STATUS_ICE, STATUS_LIME = Palette.UNMET, Palette.BLUE_BOTTOM, Palette.UP
-- The server only deposits and claims within reach of the refinery (WorldMap.canUseRefinery); the menu opens anywhere
local function nearFoundry(): boolean
	return WorldMap.canUseRefinery(WorldMap.find(), player.Character)
end
function Controller:Open()
	for _, name in OTHER_MENUS do if player:GetAttribute(name) then return end end
	player:SetAttribute("BackpackOpen", false); player:SetAttribute("FoundryExpanded", false)
	player:SetAttribute("RefineryOpen", true)
end
function Controller:Close() player:SetAttribute("RefineryOpen", false) end
function Controller:KnitStart()
	local service, upgrades = Knit.GetService("RefineryService"), Knit.GetService("UpgradeService")
	-- a copy saved in the place before the cartoon light redesign is replaced by a fresh build
	local saved = player:WaitForChild("PlayerGui"):FindFirstChild("RefineryMenu")
	if saved and saved:GetAttribute("RefineryLayout") ~= RefineryMenu.LAYOUT then saved:Destroy() end
	local gui = N.getOrBuild("RefineryMenu", RefineryMenu.build)
	self.Gui = gui
	local p: any = gui.Panel
	local state: any = nil
	local transaction: string? = nil
	local upgrading: string? = nil
	local busy, page, feedback = false, "refine", ""
	local near = nearFoundry()
	local rowViews: { [string]: any } = {}
	local geometry = Layout.compute(Layout.Size.X, Layout.Size.Y)
	local update: () -> ()
	-- The next useful button breathes, and the foundry icon pulses while it works (off with Reduce Effects)
	local pulses: { [string]: { scale: UIScale, tween: Tween, playing: boolean } } = {}
	local function pulseOf(key: string, target: GuiObject, amount: number): { scale: UIScale, tween: Tween, playing: boolean }
		local entry = pulses[key]
		if not entry then
			local scale = Instance.new("UIScale")
			scale.Name = "Pulse"
			scale.Parent = target
			entry = { scale = scale, tween = TweenService:Create(scale, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = amount }), playing = false }
			pulses[key] = entry
		end
		return entry
	end
	local function setPulse(key: string, target: GuiObject, on: boolean, amount: number)
		local entry = pulseOf(key, target, amount)
		on = on and player:GetAttribute("ReduceEffects") ~= true
		if on == entry.playing then return end
		entry.playing = on
		if on then entry.tween:Play() else entry.tween:Cancel(); entry.scale.Scale = 1 end
	end
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
		if not near then return false end
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
				feedback = (if action == "deposit" then "Deposited " else "Claimed ") .. Format.number(amount) .. (if action == "deposit" then " ore." else " bars. Tap SELL on your HUD.")
			elseif feedback == "" then feedback = if action == "deposit" then "No ore deposited. Check your backpack and hopper space." else "No finished bars to claim yet." end
			update()
		end)
	end
	-- Gatherer-style upgrades page: one production line level raises every station; the rows show
	-- what each station does now and what the next level adds. Pick an amount, then Upgrade.
	local shortUnits = { hopper = " ore", conveyor = " ore/s", refinery = " bars/s", collector = " bars" }
	local LINE_AMOUNTS = { 1, 5, math.huge }
	local lineAmount = 1
	local view = UpgradePanel.new(p, { amounts = { "1x", "5x", "MAX" }, portrait = true })
	local function amountOf(entry: any): number return entry.Rate or entry.Capacity or 0 end
	local function shortStat(id: string, value: number): string
		return (if Home.Stations[id].Levels[1].Rate then string.format("%g", value) else Format.number(value)) .. shortUnits[id]
	end
	local function lineLevel(): number
		return if state and state.line and state.line.level then state.line.level else 1
	end
	-- How many line levels the wallet and the player level cover for the chosen amount, their price
	-- with the rebirth inflation (what the server charges, UpgradeService) and what stopped it (Shared.Line.plan)
	local function linePlan(): (number, number, string?)
		if not state then return 0, 0, nil end
		local count, cash, stop = Line.plan(lineLevel(), LINE_AMOUNTS[lineAmount], state.cash, state.level or 1, Rebirth.priceMult(state.rebirths), state.rebirths)
		return count, cash, stop
	end
	local function buyLine()
		local count = linePlan()
		if count < 1 or upgrading or transaction then return end
		upgrading, feedback = "line", ""; update()
		task.spawn(function()
			-- one request for the whole batch: the server buys the levels in a row
			local ok, accepted = pcall(function() return upgrades:BuyLine(count) end)
			upgrading = nil
			if ok and accepted then feedback = Home.Line.Name .. " upgraded" .. (if count > 1 then " ×" .. count else "") .. "."
			elseif feedback == "" then feedback = "Couldn't upgrade. Please try again." end
			update()
		end)
	end
	view.onAmount = function(index: number) lineAmount = index; update() end
	view.onUpgrade = buyLine
	-- one card of the line, inside its box: caption, the well (roomy panels), the number row, the bar, then the action
	-- (or, on the middle card, the note)
	local function placeCard(card: any, box: Layout.Rect, wells: boolean)
		local w, h = box.w, box.h
		card.Position, card.Size = UDim2.fromOffset(box.x, box.y), UDim2.fromOffset(w, h)
		card.Caption.Position, card.Caption.Size = UDim2.fromOffset(8, 8), UDim2.fromOffset(w - 16, 20)
		card.Well.Visible = wells
		card.Well.Position, card.Well.Size = UDim2.fromOffset(12, 34), UDim2.fromOffset(w - 24, 92)
		local top = if wells then 134 else 32
		local left = math.floor((w - 24) * 0.55)
		card.Quantity.Position, card.Quantity.Size = UDim2.fromOffset(12, top), UDim2.fromOffset(left, 26)
		card.Sub.Position, card.Sub.Size = UDim2.fromOffset(12 + left, top + 4), UDim2.fromOffset(w - 24 - left, 20)
		card.Meter.Position, card.Meter.Size = UDim2.fromOffset(12, top + 32), UDim2.fromOffset(w - 24, 10)
		local action = card:FindFirstChild("Action")
		if action then action.Position, action.Size = UDim2.fromOffset(8, h - 56), UDim2.fromOffset(w - 16, 48) end
		local note = card:FindFirstChild("Note")
		if note then note.Position, note.Size = UDim2.fromOffset(10, top + 48), UDim2.fromOffset(w - 20, math.max(20, h - top - 56)) end
	end
	update = function()
		local l, line = geometry, state and state.line
		local refining = page == "refine"
		local width = p.Size.X.Offset
		local carried = if state then state.carried else 0
		-- the tabs: under the ribbon, or beside it on short panels
		local half = math.floor((l.tabs.w - 8) / 2)
		p.refineTab.Position, p.refineTab.Size = UDim2.fromOffset(l.tabs.x, l.tabs.y), UDim2.fromOffset(half, l.tabs.h)
		p.productionTab.Position, p.productionTab.Size = UDim2.fromOffset(l.tabs.x + half + 8, l.tabs.y), UDim2.fromOffset(half, l.tabs.h)
		Theme.tab(p.refineTab, refining)
		Theme.tab(p.productionTab, not refining)
		-- the wallet left of Close (not on short panels, where the tabs sit there): cash on REFINE, cash and shards on UPGRADES
		local chipsShown = state ~= nil and not l.short
		p.CashChip.Visible, p.ShardChip.Visible = chipsShown, chipsShown and not refining
		p.ShardChip.Position = UDim2.fromOffset(width - 56 - 142, 12)
		p.CashChip.Position = UDim2.fromOffset(if refining then width - 56 - 142 else width - 56 - 142 * 2 - 8, 12)
		if state then
			p.CashChip.Amount.Text = Format.cash(state.cash)
			p.ShardChip.Amount.Text = Format.number(state.shards)
		end

		-- the production line: ore hopper -> foundry -> finished bars
		local r = line and line.refinery
		for index, name in { "depositCard", "FoundryCard", "claimCard" } do
			local card: any = p[name]
			card.Visible = refining
			placeCard(card, l.cards[index], l.wells)
		end
		for index, name in { "FlowArrow1", "FlowArrow2" } do
			local box = l.arrows[index]
			p[name].Visible = refining
			p[name].Position, p[name].Size = UDim2.fromOffset(box.x, box.y), UDim2.fromOffset(box.w, box.h)
		end
		for _, action in { "deposit", "claim" } do
			local deposit = action == "deposit"
			local card: any = p[action .. "Card"]
			local stored = if line then (if deposit then line.hopper else line.collector) else nil
			local ratio = if stored then stored.amount / math.max(stored.capacity, 1) else 0
			card.Quantity.Text = Format.number(if stored then stored.amount else 0)
			card.Sub.Text = if stored then "of " .. Format.number(stored.capacity) .. (if deposit then " ore" else " bars") else ""
			card.Meter.Fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
			card.Meter.Fill.BackgroundColor3 = if ratio >= 1 then Palette.UNMET elseif deposit then Palette.BAR_FILL else Palette.GOLD_BOTTOM
			Theme.state(card.Action, canAct(action), "lime")
			local amount = if deposit then carried else (if line then line.collector.amount else 0)
			card.Action.Text = if transaction == action then (if deposit then "DEPOSITING..." else "CLAIMING...")
				elseif not state then "LOADING..."
				elseif not near then "AT THE FOUNDRY"
				elseif deposit and line and line.hopper.amount >= line.hopper.capacity then "HOPPER FULL"
				elseif amount <= 0 then (if deposit then "BACKPACK EMPTY" else "NO BARS YET")
				else (if deposit then "DEPOSIT " else "CLAIM ") .. Format.number(amount) .. (if deposit then " ORE" else " BARS")
			setPulse(action, card.Action, refining and canAct(action), 1.05)
		end
		-- the foundry in the middle: what it refines, how fast, its progress and a note
		local middle: any = p.FoundryCard
		local ore = if r and r.activeOre then (Home.OreNames[r.activeOre] or r.activeOre) else ""
		middle.Quantity.Text = if not r then "Loading..." elseif r.blocked == "collector" then "Storage full"
			elseif not r.activeOre then "Needs ore" else "Refining " .. ore
		middle.Quantity.TextColor3 = if r and r.blocked == "collector" then STATUS_RED elseif r and r.activeOre then Palette.NAVY else STATUS_ICE
		-- a running Overclock (Mini Overclock, Starter Pack) says so here, with its time left
		local overclock = if state then state.overclockLeft or 0 else 0
		local boosted = overclock > 0
		middle.Sub.Text = if line and r and r.activeOre and line.rate > 0 then (if boosted then "⚡" else "") .. Format.rate(line.rate) .. " bars/s" else ""
		middle.Sub.TextColor3 = STATUS_LIME
		middle.Meter.Fill.Size = UDim2.fromScale(if r and r.activeOre then r.progress or 0 else 0, 1)
		middle.Note.Text = if r and r.blocked == "collector" then "Claim bars to start it again."
			elseif boosted then string.format("OVERCLOCK ×%s speed, +%d%% bar value · %s left",
				Format.number(Config.Monetization.Overclock.SpeedMult), math.floor(Config.Monetization.Overclock.BarBonus * 100 + 0.5), Format.time(overclock))
			else ""
		middle.Note.TextColor3 = if boosted and not (r and r.blocked == "collector") then Palette.GOLD_TEXT else Palette.SECOND
		setPulse("foundry", middle.Well.Icon, refining and l.wells and r ~= nil and r.activeOre ~= nil and r.blocked == nil, 1.1)

		-- UPGRADES: one level for the whole line; every row shows its station now and after the chosen amount
		view.root.Visible = not refining
		view.root.Position = UDim2.fromOffset(l.upgrades.x, l.upgrades.y)
		local level, top = lineLevel(), Line.max()
		local count, cash, stop = linePlan()
		local target = math.min(level + math.max(count, 1), top)
		local stationRows = {}
		for _, id in Home.StationOrder do
			local current, after = Line.station(id, level), Line.station(id, target)
			table.insert(stationRows, {
				id = id, name = Home.Stations[id].Name, value = shortStat(id, amountOf(current)),
				delta = if level < top then "+" .. shortStat(id, amountOf(after) - amountOf(current)) else "MAX",
				locked = level >= top,
			})
		end
		view:select(nil)
		view:setRows(stationRows)
		view:layout(l.upgrades.w, l.upgrades.h)
		view:setPortrait(Config.HudIcons.foundry)
		local priceMult = Rebirth.priceMult(if state then state.rebirths else 0)
		local nextCost = Line.cost(level + 1, priceMult)
		view:setInfo({
			levelLabel = "Line level",
			level = if level < top then "Lv. " .. level .. " → " .. target else "Lv. " .. level,
			cost = if level >= top then "MAXED" elseif count > 0 then Price.text(cash, 0) else Price.text(nextCost or 0, 0),
			button = if not state then "Loading..." elseif upgrading == "line" then "Upgrading..." elseif level >= top then "Max level"
				elseif count == 0 and stop == "level" then "Needs level " .. Line.levelNeeded(level + 1)
				elseif count == 0 and stop == "rebirth" then "Needs rebirth " .. Line.rebirthsNeeded(level + 1) else "Upgrade all",
			enabled = state ~= nil and count >= 1 and upgrading == nil and transaction == nil,
		}, lineAmount)

		-- the refining order, top first
		local order: any = p.Order
		order.Visible = refining
		order.Position, order.Size = UDim2.fromOffset(l.order.x, l.order.y), UDim2.fromOffset(l.order.w, l.order.h)
		order.How.Visible = false -- the arrows explain themselves
		order.Totals.Size = UDim2.fromOffset(if l.order.w >= 560 then 170 else l.order.w - 160, 26)
		local rows = Queue.rows(state and state.hopperInventory, state and state.collectorInventory, state and state.refinePriority)
		local visible, ids = {}, queuedIds()
		for index, row in rows do
			visible[row.id] = true
			local rowView = rowViews[row.id]
			if not rowView then
				rowView = gui.Templates.OreRow:Clone()
				rowView.Name, rowView.Parent = row.id .. "Contents", order.Inventory
				rowView.Visible = true
				rowView.PriorityUp.Activated:Connect(function() move(row.id, -1) end)
				rowView.PriorityDown.Activated:Connect(function() move(row.id, 1) end)
				rowViews[row.id] = rowView
			end
			rowView.LayoutOrder, rowView.Size = index, UDim2.new(1, -4, 0, l.row)
			rowView.Place.Text = tostring(index)
			rowView.Icon.ImageColor3 = ORE_TINTS[row.id] or N.WHITE
			rowView.Type.Text = row.name .. " ore" .. (if line and line.refinery.activeOre == row.id then " · NEXT" else "")
			rowView.Amount.Text = Format.number(row.ore) .. " queued" .. (if row.bars > 0 then " · " .. Format.number(row.bars) .. " bars" else "")
			rowView.Divider.Visible = index < #rows
			for _, direction in { -1, 1 } do
				local button = if direction < 0 then rowView.PriorityUp else rowView.PriorityDown
				local at = table.find(ids, row.id)
				Theme.state(button, not busy and row.ore > 0 and at ~= nil and ids[(at or 0) + direction] ~= nil, "tabOff")
			end
		end
		for id, row in rowViews do if not visible[id] then row:Destroy(); rowViews[id] = nil end end
		order.Empty.Visible = #rows == 0
		order.ResetPriority.Text = if busy then "Saving..." else "Reset order"
		Theme.state(order.ResetPriority, state ~= nil and not busy, "tabOff")

		p.Feedback.Position, p.Feedback.Size = UDim2.fromOffset(l.feedback.x, l.feedback.y), UDim2.fromOffset(l.feedback.w, l.feedback.h)
		-- only what blocks you: a refusal, being too far away, or a full collector
		p.Feedback.Text = if feedback ~= "" then feedback
			elseif refining and not near then "Walk to the Foundry to deposit ore."
			elseif refining and r and r.blocked == "collector" then "Claim bars to resume refining."
			else ""
	end
	p.depositCard.Action.Activated:Connect(function() transact("deposit") end)
	p.claimCard.Action.Activated:Connect(function() transact("claim") end)
	p.Order.ResetPriority.Activated:Connect(function() if state then save({}) end end)
	for _, id in { "refine", "production" } do p[id .. "Tab"].Activated:Connect(function() page, feedback = id, ""; update() end) end
	local function notice(message: string)
		feedback = message; update()
		-- a "Move closer" the server sent while we stand at a refinery point (it saw us late): don't leave it up
		if message:find("Move closer") and near then
			task.delay(2, function() if feedback == message then feedback = ""; update() end end)
		end
	end
	service.Notice:Connect(notice)
	upgrades.Notice:Connect(notice)
	Knit.GetService("PlayerStateService").State:Observe(function(snapshot) state = snapshot; update() end)
	service.Open:Connect(function() self:Open() end)
	N.bindOpen(gui, "RefineryOpen", function() self:Close() end)
	task.spawn(function()
		while true do
			task.wait(0.3)
			local now = nearFoundry()
			if now ~= near then
				near = now
				if now and feedback:find("Foundry") then feedback = "" end
				if gui.Enabled then update() end
			end
		end
	end)
	player:GetAttributeChangedSignal("RefineryOpen"):Connect(function() if gui.Enabled then page, feedback = "refine", ""; update() end end)
	for _, name in OTHER_MENUS do player:GetAttributeChangedSignal(name):Connect(function() if player:GetAttribute(name) then self:Close() end end) end
	player:GetAttributeChangedSignal("BackpackOpen"):Connect(function() if player:GetAttribute("BackpackOpen") then self:Close() end end)
	player:GetAttributeChangedSignal("PlotId"):Connect(function() if not player:GetAttribute("PlotId") then self:Close() end end)
	N.onLayoutChanged(function(hud)
		-- centred under the top bar with room for the title ribbon and the lip (MenuFit.centred); the layout adapts the
		-- inside to the height that leaves (Shared.RefineryLayout)
		local view = N.menuView(hud)
		local rect = MenuFit.centred(view, Layout.Size)
		N.place(p, rect, view)
		geometry = Layout.compute(rect.w, rect.h)
		update()
	end)
end
return Controller

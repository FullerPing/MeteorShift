--!strict
-- Named editable ScreenGui controls; production remains authoritative on the server.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local Knit = require(RS.Packages.Knit)
local Queue = require(RS.Shared.RefineryQueue)
local Layout = require(RS.Shared.RefineryLayout)
local Home = require(RS.Shared.Config.Home)
local Format = require(RS.Shared.Format)
local Line = require(RS.Shared.Line)
local Config = require(RS.Shared.Config)
local Price = require(RS.Shared.Price)
local Rebirth = require(RS.Shared.Rebirth)
local WorldMap = require(RS.Shared.WorldMap)
local N = require(script.Parent.Parent.NativeUI)
local RefineryMenu = require(script.Parent.Parent.NativeMenus.Refinery)
local UpgradePanel = require(script.Parent.Parent.UpgradePanel)
local player = Players.LocalPlayer
local Controller = Knit.CreateController({ Name = "RefineryController" })
local OTHER_MENUS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "SettingsOpen" }
local ORE_TINTS: { [string]: Color3 } = {
	iron = Color3.fromRGB(255, 196, 36), frost = Color3.fromRGB(120, 220, 255),
	crystal = Color3.fromRGB(221, 161, 255), alien = Color3.fromRGB(130, 255, 150),
}
local STATUS_RED, STATUS_ICE, STATUS_LIME = Color3.fromRGB(255, 120, 120), Color3.fromRGB(196, 242, 255), Color3.fromRGB(176, 255, 92)
local AWAY_TEXT = Color3.fromRGB(255, 196, 120)
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
	local gui = N.getOrBuild("RefineryMenu", RefineryMenu.build, function(menu)
		local header = menu:WaitForChild("Panel"):FindFirstChild("Header")
		if header and header:IsA("GuiObject") then header.BackgroundColor3 = N.CYAN end
	end)
	self.Gui = gui
	local p: any = gui.Panel
	local state: any = nil
	local transaction: string? = nil
	local upgrading: string? = nil
	local busy, page, feedback = false, "refine", ""
	local near = nearFoundry()
	local rowViews: { [string]: any } = {}
	local geometry = Layout.compute(570, 620)
	local short = false -- phones in landscape (set with the layout)
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
				feedback = (if action == "deposit" then "Deposited " else "Claimed ") .. Format.number(amount) .. (if action == "deposit" then " ore." else " bars. Sell them at the Trading Post.")
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
	view.root.Position = UDim2.fromOffset(16, 132)
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
		local count, cash, stop = Line.plan(lineLevel(), LINE_AMOUNTS[lineAmount], state.cash, state.level or 1, Rebirth.priceMult(state.rebirths))
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
	update = function()
		local l, line = geometry, state and state.line
		local refining = page == "refine"
		local width = p.Size.X.Offset
		local flow = l.flow and refining
		local arrowGap = 30
		local sideW = math.floor((width - 32 - arrowGap * 2) * .37)
		local midW = width - 32 - arrowGap * 2 - sideW * 2
		local midX = 16 + sideW + arrowGap
		local carried = if state then state.carried else 0
		for _, action in { "deposit", "claim" } do
			local deposit = action == "deposit"
			local card: any = p[action .. "Card"]
			local amount = if deposit then carried else (line and line.collector.amount or 0)
			local stored = if line then (if deposit then line.hopper else line.collector) else nil
			card.Visible = refining
			if flow then
				card.Position = UDim2.fromOffset(if deposit then 16 else width - 16 - sideW, l.actions)
				card.Size = UDim2.fromOffset(sideW, l.actionH)
			else
				card.Position = UDim2.new(if deposit then 0 else .5, if deposit then 16 else 4, 0, l.actions)
				card.Size = UDim2.new(.5, -20, 0, l.actionH)
			end
			for _, name in { "Icon", "Caption", "Meter", "MeterText" } do card[name].Visible = flow end
			card.Quantity.Visible = flow or not l.minimal
			card.Quantity.Text = Format.number(amount)
			card.Quantity.Position = UDim2.fromOffset(12, if flow then 58 elseif l.compact then 4 else 8)
			card.Quantity.Size = UDim2.new(1, -24, 0, if flow then 44 elseif l.compact then 24 else 30)
			card.Quantity.TextSize = if flow then 38 else 25
			card.Caption.Text = if deposit then "YOUR ORE" else "BARS READY"
			-- the hint only speaks up when you are away: these buttons work at the Foundry
			card.Hint.Visible = not near and (flow or not l.compact)
			card.Hint.TextColor3 = AWAY_TEXT
			card.Hint.Position = if flow then UDim2.fromOffset(62, 32) else UDim2.fromOffset(12, 40)
			card.Hint.Size = if flow then UDim2.new(1, -72, 0, 18) else UDim2.new(1, -24, 0, 18)
			card.Hint.Text = "📍 Foundry or Commissary"
			if flow then
				local ratio = if stored then stored.amount / math.max(stored.capacity, 1) else 0
				card.Meter.Position = UDim2.fromOffset(12, 112)
				card.Meter.Fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
				card.Meter.Fill.BackgroundColor3 = if ratio >= 1 then N.RED elseif deposit then N.ORANGE else N.HUD_GOLD
				card.MeterText.Position = UDim2.fromOffset(12, 128)
				card.MeterText.Text = if stored then (if deposit then "Hopper " else "Storage ") .. Format.number(stored.amount) .. " / " .. Format.number(stored.capacity) else ""
			end
			card.Action.Position = UDim2.new(0, 8, 1, if flow then -56 elseif l.minimal then -44 else -52)
			card.Action.Size = UDim2.new(1, -16, 0, if flow then 48 else 44)
			N.enable(card.Action, canAct(action), if deposit then N.ORANGE else N.GREEN)
			card.Action.Text = if transaction == action then (if deposit then "Depositing..." else "Claiming...")
				elseif not state then "Loading..."
				elseif not near then "📍 At a Foundry"
				elseif deposit and line and line.hopper.amount >= line.hopper.capacity then "Hopper full"
				elseif flow and amount <= 0 then (if deposit then "Backpack empty" else "No bars yet")
				elseif flow or l.minimal then (if deposit then "Deposit " else "Claim ") .. Format.number(amount) .. (if deposit then " ore" else " bars")
				else (if deposit then "Deposit ore" else "Claim bars")
			setPulse(action, card.Action, refining and canAct(action), 1.05)
		end
		-- the foundry in the middle: icon, status, progress and line speed (the same controls serve the two-card layout)
		local middle: any = p.FoundryCard
		middle.Visible = flow
		p.FlowArrow1.Visible, p.FlowArrow2.Visible = flow, flow
		if flow then
			middle.Position, middle.Size = UDim2.fromOffset(midX, l.actions), UDim2.fromOffset(midW, l.actionH)
			middle.Icon.Position = UDim2.fromOffset(math.floor((midW - 72) / 2), 10)
			middle.Rate.Position = UDim2.fromOffset(8, l.actionH - 32)
			p.FlowArrow1.Position = UDim2.fromOffset(16 + sideW + (arrowGap - 26) // 2, l.actions + l.actionH // 2 - 13)
			p.FlowArrow2.Position = UDim2.fromOffset(width - 16 - sideW - arrowGap + (arrowGap - 26) // 2, l.actions + l.actionH // 2 - 13)
			p.FlowArrow1.Size, p.FlowArrow2.Size = UDim2.fromOffset(26, 26), UDim2.fromOffset(26, 26)
		end
		setPulse("foundry", middle.Icon, flow and line ~= nil and line.refinery.activeOre ~= nil and line.refinery.blocked == nil, 1.1)
		p.refineTab.BackgroundColor3 = if refining then N.CYAN else N.CARD
		p.productionTab.BackgroundColor3 = if refining then N.CARD else N.ORANGE
		-- short screens: the wallet chips move up beside the title and the hint line only shows real feedback
		p.UpgradeWallet.Visible = not refining and not short
		view.root.Visible = not refining
		p.UpgradeWallet.Text = if state then "Your production line" else "Loading..."
		local wallet = { p.ShardChip, p.CashChip }
		local chipsRight, chipsY = if short then 60 else 16, if short then 4 else 96
		p.ShardChip.Position = UDim2.fromOffset(p.Size.X.Offset - chipsRight - 142, chipsY)
		p.CashChip.Position = UDim2.fromOffset(p.Size.X.Offset - chipsRight - 142 * 2 - 8, chipsY)
		local hintShown = refining or not short or feedback ~= ""
		p.Feedback.Visible = hintShown
		view.root.Position = UDim2.fromOffset(16, if short then 100 else 132)
		for _, chip in wallet do chip.Visible = not refining and state ~= nil end
		if state then
			p.CashChip.Amount.Text = Format.cash(state.cash)
			p.ShardChip.Amount.Text = Format.number(state.shards)
		end
		-- one level for the whole line: every row shows its station now and after the chosen amount
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
		view:layout(p.Size.X.Offset - 32, math.max(0, p.Size.Y.Offset - (if short then 100 + (if hintShown then 54 else 8) else 188)))
		view:setPortrait(Config.HudIcons.foundry)
		local priceMult = Rebirth.priceMult(if state then state.rebirths else 0)
		local nextCost = Line.cost(level + 1, priceMult)
		view:setInfo({
			levelLabel = "Line level",
			level = if level < top then "Lv. " .. level .. " → " .. target else "Lv. " .. level,
			cost = if level >= top then "MAXED" elseif count > 0 then Price.text(cash, 0) else Price.text(nextCost or 0, 0),
			button = if not state then "Loading..." elseif upgrading == "line" then "Upgrading..." elseif level >= top then "Max level"
				elseif count == 0 and stop == "level" then "Needs level " .. Line.levelNeeded(level + 1) else "Upgrade all",
			enabled = state ~= nil and count >= 1 and upgrading == nil and transaction == nil,
		}, lineAmount)
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
			view.Type.Position = UDim2.fromOffset(56, if l.compact then 2 else 6)
			view.Amount.Position = UDim2.fromOffset(56, if l.compact then 26 else 30)
			local iconSize = math.min(40, l.row - 12)
			view.Icon.Size, view.Icon.Position = UDim2.fromOffset(iconSize, iconSize), UDim2.fromOffset(8, (l.row - iconSize) // 2)
			view.Icon.ImageColor3 = ORE_TINTS[row.id] or N.WHITE
			view.Type.Text = row.name .. (if line and line.refinery.activeOre == row.id then " · NEXT" else "")
			view.Type.TextTruncate = Enum.TextTruncate.AtEnd
			view.Amount.Text = Format.number(row.ore) .. " ore · " .. Format.number(row.bars) .. " bars"
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
		p.Status.Visible = refining and (flow or not l.hideStatus)
		local ore = if r and r.activeOre then (Home.OreNames[r.activeOre] or r.activeOre) else ""
		p.Status.Text = if not r then "Loading your refinery..."
			elseif r.blocked == "collector" then (if flow then "STORAGE FULL" else "Storage full · claim bars to resume")
			elseif not r.activeOre then (if flow then "NEEDS ORE" else "Ready to work · deposit ore above")
			else (if flow then "REFINING" .. string.char(10) .. ore else "Refining " .. ore)
		p.Status.TextColor3 = if r and r.blocked == "collector" then STATUS_RED elseif r and r.activeOre then STATUS_LIME elseif flow then STATUS_ICE else N.WHITE
		p.Status.TextWrapped = flow
		p.Status.TextXAlignment = if flow then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
		p.Status.TextSize = if flow then 17 else 18
		if flow then
			p.Status.Position, p.Status.Size = UDim2.fromOffset(midX + 6, l.actions + 88), UDim2.fromOffset(midW - 12, 44)
			p.Progress.Position, p.Progress.Size = UDim2.fromOffset(midX + 14, l.actions + 142), UDim2.fromOffset(midW - 28, 12)
			middle.Rate.Text = if line and r and r.activeOre and line.rate > 0 then "Line speed " .. Format.rate(line.rate) .. "/s" else ""
		else
			p.Status.Position, p.Status.Size = UDim2.fromOffset(16, l.status), UDim2.new(1, -32, 0, 26)
			p.Progress.Position, p.Progress.Size = UDim2.fromOffset(16, l.progress), UDim2.new(1, -32, 0, 5)
		end
		p.Progress.Visible = refining
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
			elseif not near then "Walk to the Foundry in town or the Commissary up north to deposit ore and claim bars."
			elseif r and r.blocked == "collector" then "Claim bars to resume refining."
			elseif l.hideStatus and r and r.activeOre then "Refining " .. (Home.OreNames[r.activeOre] or r.activeOre)
			elseif state and state.carried > 0 and (not r or not r.activeOre) then "Press Deposit to start refining your ore."
			elseif #rows > 0 then "Use the arrows to choose which ore is refined first."
			elseif state and state.carried <= 0 then "Mine ore in the fields, then come back and deposit it."
			else "Mine ore, deposit it, claim the bars, then sell them at the Trading Post."
	end
	p.depositCard.Action.Activated:Connect(function() transact("deposit") end)
	p.claimCard.Action.Activated:Connect(function() transact("claim") end)
	p.ResetPriority.Activated:Connect(function() if state then save({}) end end)
	for _, id in { "refine", "production" } do p[id .. "Tab"].Activated:Connect(function() page, feedback = id, ""; update() end) end
	service.Notice:Connect(function(message) feedback = message; update() end)
	upgrades.Notice:Connect(function(message) feedback = message; update() end)
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
		-- phones in landscape: wider, and from just under the top bar (the title ribbon pokes 16 px above the
		-- panel) to the bottom, so the upgrades page has room for its rows
		local view = N.menuView(hud)
		local screen, inset = view.viewport, view.inset
		short = screen.Y - inset < 400
		local w, h = math.min(620, screen.X - 24), math.min(570, screen.Y - inset - 24)
		local top = inset + (screen.Y - inset - h) / 2
		if short then
			w = math.min(860, screen.X - 24)
			top = inset + 18
			h = math.max(0, screen.Y - top - 8)
		end
		N.place(p, { x = (screen.X - w) / 2, y = top, w = w, h = h }, view)
		geometry = Layout.compute(h, w)
		update()
	end)
end
return Controller

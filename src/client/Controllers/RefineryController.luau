--!strict
-- Live production contents and saved ore priority; production stays on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Queue = require(ReplicatedStorage.Shared.RefineryQueue)
local Home = require(ReplicatedStorage.Shared.Config.Home)
local Format = require(ReplicatedStorage.Shared.Format)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Config = require(ReplicatedStorage.Shared.Config)
local Price = require(ReplicatedStorage.Shared.Price)
local UI = require(script.Parent.Parent.UI)
local Children, OnEvent = Fusion.Children, Fusion.OnEvent
local player = Players.LocalPlayer
local Controller = Knit.CreateController({ Name = "RefineryController" })
local OTHER_MENUS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "SettingsOpen" }

function Controller:Open()
	for _, name in OTHER_MENUS do if player:GetAttribute(name) then return end end
	player:SetAttribute("BackpackOpen", false)
	player:SetAttribute("FoundryExpanded", false)
	player:SetAttribute("RefineryOpen", true)
end
function Controller:Close() player:SetAttribute("RefineryOpen", false) end

local function ownsPrompt(prompt: Instance): boolean
	local node: Instance? = prompt
	while node and node ~= workspace do
		if node:GetAttribute("PlotId") ~= nil then return node:GetAttribute("OwnerUserId") == player.UserId end
		node = node.Parent
	end
	return false
end

function Controller:KnitStart()
	local service = Knit.GetService("RefineryService")
	local upgrades = Knit.GetService("UpgradeService")
	local scope = Fusion.scoped(Fusion)
	local hud, state, busy = UI.hud(scope), scope:Value(nil :: any), scope:Value(false)
	local transaction, feedback = scope:Value(nil :: string?), scope:Value("")
	local page, upgrading = scope:Value("refine"), scope:Value(nil :: string?)
	local refining = scope:Computed(function(use) return use(page) == "refine" end)
	local producing = scope:Computed(function(use) return use(page) == "production" end)
	service.Notice:Connect(function(message) feedback:set(message) end)
	upgrades.Notice:Connect(function(message) feedback:set(message) end)
	local function transact(action: string)
		if Fusion.peek(transaction) then return end
		transaction:set(action)
		feedback:set("")
		task.spawn(function()
			local ok, amount = pcall(function()
				return if action == "deposit" then service:Deposit() else service:Claim()
			end)
			transaction:set(nil)
			if not ok then feedback:set("Couldn't complete that. Please try again.")
			elseif amount > 0 then
				feedback:set((if action == "deposit" then "Deposited " else "Claimed ") .. Format.number(amount) .. (if action == "deposit" then " ore." else " bars. Sell them at the Trading Post."))
			elseif Fusion.peek(feedback) == "" then
				feedback:set(if action == "deposit" then "No ore deposited. Check your backpack and hopper space." else "No finished bars to claim yet.")
			end
		end)
	end
	local opened = scope:Value(player:GetAttribute("RefineryOpen") == true)
	scope:Observer(opened):onChange(function() if Fusion.peek(opened) then page:set("refine"); feedback:set("") end end)
	table.insert(scope, player:GetAttributeChangedSignal("RefineryOpen"):Connect(function() opened:set(player:GetAttribute("RefineryOpen") == true) end))
	Knit.GetService("PlayerStateService").State:Observe(function(snapshot) state:set(snapshot) end)
	service.Open:Connect(function() self:Open() end)
	for _, name in OTHER_MENUS do
		table.insert(scope, player:GetAttributeChangedSignal(name):Connect(function() if player:GetAttribute(name) then self:Close() end end))
	end
	table.insert(scope, player:GetAttributeChangedSignal("BackpackOpen"):Connect(function() if player:GetAttribute("BackpackOpen") then self:Close() end end))
	table.insert(scope, UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then self:Close() end
	end))
	local function promptVisibility(prompt: Instance)
		if prompt:IsA("ProximityPrompt") and prompt.Name == "ManageRefinery" then prompt.Enabled = ownsPrompt(prompt) end
	end
	for _, node in workspace:GetDescendants() do promptVisibility(node) end
	table.insert(scope, workspace.DescendantAdded:Connect(promptVisibility))
	table.insert(scope, player:GetAttributeChangedSignal("PlotId"):Connect(function()
		for _, node in workspace:GetDescendants() do promptVisibility(node) end
		if not player:GetAttribute("PlotId") then self:Close() end
	end))
	local fit = scope:Computed(function(use)
		local l = use(hud)
		local w, h = math.min(620, l.viewport.X - 24), math.min(570, l.viewport.Y - l.inset - 24)
		return { w = w, h = h, x = (l.viewport.X - w) / 2, y = l.inset + (l.viewport.Y - l.inset - h) / 2 }
	end)
	local layout = scope:Computed(function(use)
		local compact = use(fit).h < 420
		return if compact then { compact = true, title = 8, rate = 37, actions = 100, actionH = 82, status = 188, progress = 216, totals = 224, list = 252, row = 52 }
			else { compact = false, title = 16, rate = 48, actions = 108, actionH = 116, status = 240, progress = 271, totals = 284, list = 316, row = 60 }
	end)
	local function at(section: string)
		return scope:Computed(function(use) return UDim2.fromOffset(16, use(layout)[section]) end)
	end
	local rows = scope:Computed(function(use)
		local s = use(state)
		return Queue.rows(s and s.hopperInventory, s and s.collectorInventory, s and s.refinePriority)
	end)
	local function save(order: { string })
		if Fusion.peek(busy) then return end
		busy:set(true)
		task.spawn(function()
			local ok, accepted = pcall(function() return service:SetPriority(order) end)
			busy:set(false)
			if not ok or not accepted then Knit.GetController("HUDController"):Toast("Could not change refinery priority. Try again.") end
		end)
	end
	local function queuedIds(): { string }
		local out = {}
		for _, row in Fusion.peek(rows) do if row.ore > 0 and Home.OreNames[row.id] then table.insert(out, row.id) end end
		return out
	end
	local function move(id: string, direction: number)
		local visible = queuedIds()
		local index = table.find(visible, id)
		local neighbor = index and visible[index + direction]
		local s = Fusion.peek(state)
		if not s or not neighbor then return end
		local order = Queue.order(s.refinePriority)
		local a, b = table.find(order, id), table.find(order, neighbor)
		if a and b then order[a], order[b] = order[b], order[a]; save(order) end
	end
	local function caption(rowScope: UI.Scope, props: { [any]: any })
		local base: { [any]: any } = { Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left }
		for key, value in props do base[key] = value end
		return UI.hudText(rowScope, base)
	end
	local ids = scope:Computed(function(use) local out = {}; for i, row in use(rows) do out[i] = row.id end; return out end)
	local rowViews = scope:ForPairs(ids, function(_use: any, rowScope: UI.Scope, index: number, id: string)
		local row = rowScope:Computed(function(use)
			for _, item in use(rows) do if item.id == id then return item end end
			return { id = id, name = id, ore = 0, bars = 0 }
		end)
		local current = rowScope:Computed(function(use) local s = use(state); return s and s.line and s.line.refinery.activeOre == id end)
		local controls = {}
		for _, direction in { -1, 1 } do
			local enabled = rowScope:Computed(function(use)
				if use(busy) or use(row).ore <= 0 or not Home.OreNames[id] then return false end
				local queued = {}; for _, item in use(rows) do if item.ore > 0 and Home.OreNames[item.id] then table.insert(queued, item.id) end end
				local at = table.find(queued, id)
				return at ~= nil and queued[at + direction] ~= nil
			end)
			table.insert(controls, rowScope:New("TextButton")({
				Name = if direction < 0 then "PriorityUp" else "PriorityDown", Position = rowScope:Computed(function(use) return UDim2.new(1, if direction < 0 then -96 else -48, 0, if use(layout).compact then 4 else 8) end),
				Size = UDim2.fromOffset(44, 44), Text = if direction < 0 then "↑" else "↓", Font = Enum.Font.GothamBold, TextSize = 24,
				BackgroundColor3 = UI.HUD_BORDER, BorderSizePixel = 0, AutoButtonColor = enabled, Active = enabled, Selectable = enabled,
				TextColor3 = rowScope:Computed(function(use) return if use(enabled) then UI.HUD_MINT else UI.HUD_MUTED end),
				[Children] = { UI.corner(rowScope, 6) }, [OnEvent("Activated")] = function() if Fusion.peek(enabled) then move(id, direction) end end,
			}))
		end
		return index, rowScope:New("Frame")({
			Name = id .. "Contents", LayoutOrder = index, Size = rowScope:Computed(function(use) return UDim2.new(1, -4, 0, use(layout).row) end), BorderSizePixel = 0,
			BackgroundColor3 = rowScope:Computed(function(use) return if use(current) then Color3.fromRGB(37, 57, 53) else UI.HUD_SURFACE end),
			[Children] = {
				UI.corner(rowScope, 7),
				caption(rowScope, { Name = "Type", Position = rowScope:Computed(function(use) return UDim2.fromOffset(10, if use(layout).compact then 2 else 6) end), Size = UDim2.new(1, -114, 0, 22), Font = Enum.Font.GothamBold, TextSize = 16,
					Text = rowScope:Computed(function(use) return use(row).name .. (if use(current) then " · NEXT" else "") end), TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = rowScope:Computed(function(use) return if use(current) then UI.HUD_GOLD else UI.WHITE end) }),
				caption(rowScope, { Name = "Contents", Position = rowScope:Computed(function(use) return UDim2.fromOffset(10, if use(layout).compact then 26 else 30) end), Size = UDim2.new(1, -114, 0, 22), TextSize = 12, TextColor3 = UI.HUD_MUTED,
					Text = rowScope:Computed(function(use)
						local r, s = use(row), use(state)
						local text = Format.number(r.ore) .. " ore  ·  " .. Format.number(r.bars) .. " ready bars"
						local speed = Levels.clearance(if s and s.level then s.level else 1, id)
						if speed < 1 then
							text ..= string.format("  ·  %d%% speed, full at level %d", math.max(math.floor(speed * 100 + 0.5), 1), Config.Levels.OreLevel[id] or 1)
						end
						return text
					end), TextTruncate = Enum.TextTruncate.AtEnd }),
				controls,
			},
		})
	end)
	local actions = {}
	for index, action in { "deposit", "claim" } do
		local enabled = scope:Computed(function(use)
			local s = use(state)
			if not s or not s.line or use(transaction) ~= nil then return false end
			return if action == "deposit" then s.carried > 0 and s.line.hopper.amount < s.line.hopper.capacity else s.line.collector.amount > 0
		end)
		local color = if action == "deposit" then UI.HUD_GOLD else UI.HUD_MINT
		table.insert(actions, scope:New("Frame")({
			Name = if action == "deposit" then "DepositCard" else "ClaimCard",
			Visible = refining,
			Position = scope:Computed(function(use) return UDim2.new((index - 1) * .5, if index == 1 then 16 else 4, 0, use(layout).actions) end),
			Size = scope:Computed(function(use) return UDim2.new(.5, -20, 0, use(layout).actionH) end),
			BackgroundColor3 = UI.CARD, BorderSizePixel = 0,
			[Children] = {
				UI.corner(scope, 12),
				caption(scope, { Name = "Quantity", Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 24), Font = Enum.Font.GothamBold, TextSize = 16,
					Text = scope:Computed(function(use)
						local s = use(state)
						if not s or not s.line then return "Loading..." end
						return if action == "deposit" then Format.number(s.carried) .. " carried ore" else Format.number(s.line.collector.amount) .. " ready bars"
					end), TextTruncate = Enum.TextTruncate.AtEnd }),
				caption(scope, { Name = "Space", Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 18), TextSize = 12, TextColor3 = UI.HUD_MUTED,
					Visible = scope:Computed(function(use) return not use(layout).compact end),
					Text = scope:Computed(function(use)
						local s = use(state)
						if not s or not s.line then return "" end
						return if action == "deposit" then Format.number(math.max(0, s.line.hopper.capacity - s.line.hopper.amount)) .. " hopper space" else "Move bars to your backpack"
					end), TextTruncate = Enum.TextTruncate.AtEnd }),
				scope:New("TextButton")({
					Name = if action == "deposit" then "DepositOre" else "ClaimBars", Position = UDim2.new(0, 8, 1, -52), Size = UDim2.new(1, -16, 0, 44),
					Font = Enum.Font.GothamBold, TextSize = 15, BorderSizePixel = 0, Active = enabled, Selectable = enabled, AutoButtonColor = enabled,
					BackgroundColor3 = scope:Computed(function(use) return if use(enabled) then color else UI.HUD_BORDER end),
					TextColor3 = scope:Computed(function(use) return if use(enabled) then UI.OUTLINE else UI.HUD_MUTED end),
					Text = scope:Computed(function(use)
						if use(transaction) == action then return if action == "deposit" then "Depositing..." else "Claiming..." end
						local s = use(state)
						if not s then return "Loading..." end
						if action == "deposit" and s.line and s.line.hopper.amount >= s.line.hopper.capacity then return "Hopper full" end
						return if action == "deposit" then "Deposit ore" else "Claim bars"
					end),
					[Children] = { UI.corner(scope, 8) }, [OnEvent("Activated")] = function() if Fusion.peek(enabled) then transact(action) end end,
				}),
			},
		}))
	end
	local tabs, upgradeCards = {}, {}
	for index, id in { "refine", "production" } do
		tabs[index] = UI.button(scope, {
			Name = id .. "Tab", Position = UDim2.new((index - 1) * .5, if index == 1 then 16 else 4, 0, 48), Size = UDim2.new(.5, -20, 0, 44),
			Text = if id == "refine" then "DEPOSIT / CLAIM" else "PRODUCTION UPGRADES", TextScaled = true,
			BackgroundColor3 = scope:Computed(function(use) return if use(page) == id then UI.HUD_GOLD else UI.CARD end),
			TextColor3 = scope:Computed(function(use) return if use(page) == id then UI.OUTLINE else UI.HUD_MUTED end),
			[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 10, MaxTextSize = 14 }) },
			[OnEvent("Activated")] = function() page:set(id); feedback:set("") end,
		})
	end
	local units = { hopper = "ore capacity", conveyor = "ore/s", refinery = "bars/s", collector = "bar capacity" }
	local descriptions = { hopper = "Store more ore before depositing again.", conveyor = "Feed ore into the smelter faster.", refinery = "Smelt ore faster. The slower machine sets the line speed.", collector = "Hold more finished bars between claims." }
	for index, id in Home.StationOrder do
		local def = Home.Stations[id]
		local level = scope:Computed(function(use) local s = use(state); return if s and s.line and s.line[id] then s.line[id].level else 1 end)
		local nextLevel = scope:Computed(function(use) return def.Levels[use(level) + 1] end)
		local enabled = scope:Computed(function(use)
			local s, n = use(state), use(nextLevel)
			return s ~= nil and n ~= nil and use(upgrading) == nil and use(transaction) == nil and Price.canAfford(s, n.Cost, n.Shards)
		end)
		local function stat(entry: any): string
			return (if entry.Rate then string.format("%g", entry.Rate) else Format.number(entry.Capacity or 0)) .. " " .. units[id]
		end
		upgradeCards[index] = scope:New("Frame")({
			Name = id .. "Upgrade", LayoutOrder = index, Size = UDim2.new(1, -4, 0, 118), BackgroundColor3 = UI.CARD, BorderSizePixel = 0,
			[Children] = {
				UI.corner(scope, 10),
				caption(scope, { Name = "Station", Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 22), Font = Enum.Font.GothamBold, TextSize = 16,
					Text = scope:Computed(function(use) return def.Name .. "  ·  Level " .. use(level) end) }),
				caption(scope, { Name = "Improvement", Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 22), TextSize = 13, TextColor3 = UI.HUD_MINT,
					Text = scope:Computed(function(use) local n = use(nextLevel); return stat(def.Levels[use(level)]) .. (if n then "  →  " .. stat(n) else "  ·  MAX LEVEL") end) }),
				caption(scope, { Name = "Purpose", Position = UDim2.fromOffset(12, 64), Size = UDim2.new(1, -180, 0, 44), TextSize = 12, TextWrapped = true, TextColor3 = UI.HUD_MUTED, Text = descriptions[id] }),
				UI.button(scope, {
					Name = "BuyUpgrade", Position = UDim2.new(1, -160, 0, 64), Size = UDim2.fromOffset(148, 44), TextScaled = true, Active = enabled, Selectable = enabled, AutoButtonColor = enabled,
					BackgroundColor3 = scope:Computed(function(use) return if use(enabled) then UI.HUD_GOLD else UI.PANEL_DARK end),
					TextColor3 = scope:Computed(function(use) return if use(enabled) then UI.OUTLINE else UI.HUD_MUTED end),
					Text = scope:Computed(function(use)
						local s, n = use(state), use(nextLevel)
						if not s then return "Loading..." end
						if use(upgrading) == id then return "Upgrading..." end
						if not n then return "MAX LEVEL" end
						return (if Price.canAfford(s, n.Cost, n.Shards) then "UPGRADE" else "SAVE UP") .. "\n" .. Price.text(n.Cost, n.Shards)
					end),
					[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 10, MaxTextSize = 14 }) },
					[OnEvent("Activated")] = function()
						if not Fusion.peek(enabled) then return end
						upgrading:set(id); feedback:set("")
						task.spawn(function()
							local ok, accepted = pcall(function() return upgrades:BuyStation(id) end)
							upgrading:set(nil)
							if ok and accepted then feedback:set(def.Name .. " upgraded.")
							elseif not ok then feedback:set("Couldn't upgrade. Please try again.") end
						end)
					end,
				}),
			},
		})
	end
	self.Gui = scope:New("ScreenGui")({
		Name = "RefineryMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 19, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = opened, Parent = player:WaitForChild("PlayerGui"),
		[Children] = {
			scope:New("TextButton")({ Name = "Dimmer", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.OUTLINE, BackgroundTransparency = .3, BorderSizePixel = 0, Text = "", AutoButtonColor = false, Modal = true, [OnEvent("Activated")] = function() self:Close() end }),
			scope:New("Frame")({
			Name = "Panel", BackgroundColor3 = UI.HUD_SURFACE, BorderSizePixel = 0, Active = true, ZIndex = 2,
			Position = scope:Computed(function(use) local r = use(fit); return UDim2.fromOffset(r.x, r.y) end),
			Size = scope:Computed(function(use) local r = use(fit); return UDim2.fromOffset(r.w, r.h) end),
			[Children] = {
				UI.corner(scope, 16), scope:New("UIStroke")({ Color = UI.HUD_BORDER, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				actions, tabs,
				caption(scope, { Name = "UpgradeWallet", Position = UDim2.fromOffset(16, 100), Size = UDim2.new(1, -32, 0, 24), TextSize = 13, TextColor3 = UI.HUD_GOLD, Visible = producing,
					Text = scope:Computed(function(use) local s = use(state); return if s then Format.cash(s.cash) .. "  ·  " .. Format.number(s.shards) .. " shards  ·  Your production line" else "Loading..." end) }),
				scope:New("ScrollingFrame")({ Name = "ProductionUpgrades", Visible = producing, Position = UDim2.fromOffset(16, 132), Size = UDim2.new(1, -32, 1, -188),
					BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = UI.HUD_GOLD, ScrollingDirection = Enum.ScrollingDirection.Y,
					[Children] = { scope:New("UIListLayout")({ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }), upgradeCards } }),
				caption(scope, { Name = "Title", Position = at("title"), Size = UDim2.new(1, -80, 0, 26), Text = "REFINERY", TextSize = 24, Font = Enum.Font.GothamBold, TextColor3 = UI.HUD_GOLD }),
				scope:New("ImageButton")({ Name = "Close", Position = UDim2.new(1, -52, 0, 8), Size = UDim2.fromOffset(44, 44), Image = "", BackgroundTransparency = 1,
					[Children] = { UI.hudIcon(scope, "close", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(20, 20) }) }, [OnEvent("Activated")] = function() self:Close() end }),
				caption(scope, { Name = "Rate", Position = at("rate"), Size = UDim2.new(1, -80, 0, 18), TextSize = 12, TextColor3 = UI.HUD_MUTED,
					Visible = false,
					Text = scope:Computed(function(use) local s = use(state); local l = s and s.line; return if l then "Level " .. l.refinery.level .. "  ·  " .. (if l.rate < 10 then string.format("%g", l.rate) else Format.number(l.rate)) .. " bars/s" else "Loading refinery..." end) }),
				caption(scope, { Name = "Status", Position = at("status"), Size = UDim2.new(1, -32, 0, 26), TextSize = 18, Font = Enum.Font.GothamBold,
					Visible = refining,
					Text = scope:Computed(function(use)
						local s = use(state); local r = s and s.line and s.line.refinery
						if not r then return "Loading your refinery..." end
						if r.blocked == "collector" then return "Storage full · claim bars to resume" end
						if not r.activeOre then return "Ready to work · deposit ore above" end
						return "Refining " .. (Home.OreNames[r.activeOre] or r.activeOre)
					end), TextTruncate = Enum.TextTruncate.AtEnd }),
				scope:New("Frame")({ Name = "Progress", Visible = refining, Position = at("progress"), Size = UDim2.new(1, -32, 0, 5), BorderSizePixel = 0, BackgroundColor3 = UI.HUD_BORDER,
					[Children] = { UI.corner(scope, 3), scope:New("Frame")({ Name = "Fill", Size = scope:Computed(function(use) local s = use(state); local r = s and s.line and s.line.refinery; return UDim2.fromScale(if r then r.progress or 0 else 0, 1) end), BackgroundColor3 = UI.HUD_MINT, BorderSizePixel = 0, [Children] = { UI.corner(scope, 3) } }) } }),
				caption(scope, { Name = "Totals", Visible = refining, Position = at("totals"), Size = UDim2.new(1, -32, 0, 22), TextSize = 12, TextColor3 = UI.HUD_MUTED, Text = scope:Computed(function(use) local s = use(state); local l = s and s.line; return if l then "REFINING ORDER  ·  " .. Format.number(l.hopper.amount) .. " queued ore" else "" end) }),
				scope:New("ScrollingFrame")({ Name = "Inventory", Visible = refining, Position = at("list"), Size = scope:Computed(function(use) return UDim2.new(1, -32, 1, -use(layout).list - 56) end), BackgroundTransparency = 1, BorderSizePixel = 0,
					CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = UI.HUD_MUTED, ScrollingDirection = Enum.ScrollingDirection.Y,
					[Children] = { scope:New("UIListLayout")({ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }), rowViews } }),
				caption(scope, { Name = "Empty", Position = at("list"), Size = UDim2.new(1, -32, 0, 44), Text = "Mine ore, then deposit it here to start refining.", TextSize = 13, TextWrapped = true, TextColor3 = UI.HUD_MUTED, Visible = scope:Computed(function(use) return use(refining) and #use(rows) == 0 end) }),
				caption(scope, { Name = "Feedback", Position = UDim2.new(0, 16, 1, -54), Size = scope:Computed(function(use) return UDim2.new(1, if use(refining) then -168 else -32, 0, 44) end), TextSize = 12, TextWrapped = true, TextColor3 = UI.HUD_MUTED,
					Text = scope:Computed(function(use) local message = use(feedback); return if message ~= "" then message elseif use(producing) then "Upgrades apply to your own line. Keep conveyor and smelter speeds balanced." else "Use the arrows to refine an ore type first." end) }),
				scope:New("TextButton")({ Name = "ResetPriority", Visible = refining, Position = UDim2.new(1, -144, 1, -54), Size = UDim2.fromOffset(128, 44), Text = scope:Computed(function(use) return if use(busy) then "Saving..." else "Reset order" end),
					Font = Enum.Font.GothamBold, TextSize = 12, BackgroundColor3 = UI.CARD, BorderSizePixel = 0, TextColor3 = UI.HUD_MUTED,
					[Children] = { UI.corner(scope, 7) }, [OnEvent("Activated")] = function() if Fusion.peek(state) then save({}) end end }),
			},
		}) },
	})
end
return Controller

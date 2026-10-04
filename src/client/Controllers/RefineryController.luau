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
	local scope = Fusion.scoped(Fusion)
	local hud, state, busy = UI.hud(scope), scope:Value(nil :: any), scope:Value(false)
	local opened = scope:Value(player:GetAttribute("RefineryOpen") == true)
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
		local w, h = math.min(560, l.viewport.X - 24), math.min(460, l.viewport.Y - l.inset - 24)
		return { w = w, h = h, x = (l.viewport.X - w) / 2, y = l.inset + (l.viewport.Y - l.inset - h) / 2 }
	end)
	local layout = scope:Computed(function(use)
		local compact = use(fit).h < 340
		return if compact then { compact = true, title = 8, rate = 34, status = 54, progress = 82, totals = 92, list = 120, row = 52 }
			else { compact = false, title = 12, rate = 50, status = 78, progress = 110, totals = 124, list = 194, row = 60 }
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
					TextColor3 = rowScope:Computed(function(use) return if use(current) then UI.HUD_MINT else UI.WHITE end) }),
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
	self.Gui = scope:New("ScreenGui")({
		Name = "RefineryMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 19, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = opened, Parent = player:WaitForChild("PlayerGui"),
		[Children] = { scope:New("Frame")({
			Name = "Panel", BackgroundColor3 = UI.HUD_SURFACE, BorderSizePixel = 0, Active = false,
			Position = scope:Computed(function(use) local r = use(fit); return UDim2.fromOffset(r.x, r.y) end),
			Size = scope:Computed(function(use) local r = use(fit); return UDim2.fromOffset(r.w, r.h) end),
			[Children] = {
				UI.hudFill(scope), caption(scope, { Name = "Title", Position = at("title"), Size = UDim2.new(1, -80, 0, 26), Text = "REFINERY", TextSize = 24, Font = Enum.Font.GothamBold, TextColor3 = UI.HUD_GOLD }),
				scope:New("ImageButton")({ Name = "Close", Position = UDim2.new(1, -52, 0, 8), Size = UDim2.fromOffset(44, 44), Image = "", BackgroundTransparency = 1,
					[Children] = { UI.hudIcon(scope, "close", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(20, 20) }) }, [OnEvent("Activated")] = function() self:Close() end }),
				caption(scope, { Name = "Rate", Position = at("rate"), Size = UDim2.new(1, -80, 0, 18), TextSize = 12, TextColor3 = UI.HUD_MUTED,
					Text = scope:Computed(function(use) local s = use(state); local l = s and s.line; return if l then "Level " .. l.refinery.level .. "  ·  " .. (if l.rate < 10 then string.format("%g", l.rate) else Format.number(l.rate)) .. " bars/s" else "Loading refinery..." end) }),
				caption(scope, { Name = "Status", Position = at("status"), Size = UDim2.new(1, -32, 0, 26), TextSize = 18, Font = Enum.Font.GothamBold,
					Text = scope:Computed(function(use)
						local s = use(state); local r = s and s.line and s.line.refinery
						if not r then return "Claim a plot to refine ore" end
						if r.blocked == "collector" then return "Storage full · collect your bars" end
						if not r.activeOre then return "Empty · deposit ore in your hopper" end
						return "Refining " .. (Home.OreNames[r.activeOre] or r.activeOre)
					end), TextTruncate = Enum.TextTruncate.AtEnd }),
				scope:New("Frame")({ Name = "Progress", Position = at("progress"), Size = UDim2.new(1, -32, 0, 5), BorderSizePixel = 0, BackgroundColor3 = UI.HUD_BORDER,
					[Children] = { UI.corner(scope, 3), scope:New("Frame")({ Name = "Fill", Size = scope:Computed(function(use) local s = use(state); local r = s and s.line and s.line.refinery; return UDim2.fromScale(if r then r.progress or 0 else 0, 1) end), BackgroundColor3 = UI.HUD_MINT, BorderSizePixel = 0, [Children] = { UI.corner(scope, 3) } }) } }),
				caption(scope, { Name = "Totals", Position = at("totals"), Size = UDim2.new(1, -32, 0, 22), Text = scope:Computed(function(use) local s = use(state); local l = s and s.line; return if l then Format.number(l.hopper.amount) .. " queued ore  ·  " .. Format.number(l.collector.amount) .. " ready bars" else "" end) }),
				caption(scope, { Name = "Hint", Position = UDim2.fromOffset(16, 153), Size = UDim2.new(1, -32, 0, 34), Text = "Use arrows to refine higher rows first. Empty types are skipped.", TextSize = 12, TextWrapped = true, TextColor3 = UI.HUD_MUTED, Visible = scope:Computed(function(use) return not use(layout).compact end) }),
				scope:New("ScrollingFrame")({ Name = "Inventory", Position = at("list"), Size = scope:Computed(function(use) return UDim2.new(1, -32, 1, -use(layout).list - 64) end), BackgroundTransparency = 1, BorderSizePixel = 0,
					CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = UI.HUD_MUTED, ScrollingDirection = Enum.ScrollingDirection.Y,
					[Children] = { scope:New("UIListLayout")({ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }), rowViews } }),
				caption(scope, { Name = "Empty", Position = at("list"), Size = UDim2.new(1, -32, 0, 44), Text = "Empty", TextColor3 = UI.HUD_MUTED, Visible = scope:Computed(function(use) return #use(rows) == 0 end) }),
				scope:New("TextButton")({ Name = "ResetPriority", Position = UDim2.new(0, 16, 1, -56), Size = UDim2.new(1, -32, 0, 44), Text = scope:Computed(function(use) return if use(busy) then "SAVING..." else "RESET DEFAULT ORDER" end),
					Font = Enum.Font.GothamBold, TextSize = 14, BackgroundColor3 = UI.HUD_BORDER, BorderSizePixel = 0, TextColor3 = UI.HUD_MINT,
					[Children] = { UI.corner(scope, 7) }, [OnEvent("Activated")] = function() local s = Fusion.peek(state); if s and s.plotId then save({}) end end }),
			},
		}) },
	})
end
return Controller

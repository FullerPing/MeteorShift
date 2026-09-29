--!strict
-- Mineral index book (spec §8.2). The INDEX button, under SHOP in the same column,
-- opens a panel with one tab per meteor type page. Every mineral is a card (unknown
-- ones as "???" silhouettes) with its published odds; each page shows its progress,
-- its reward and which pickaxes can find it, and the header the total bar sale
-- bonus and the best title earned. A new find pops a toast and lights the button;
-- a repeat find floats a small "+1 X" off the button.
--
-- IndexService owns the index and rolls every drop; the panel reads the `index`
-- in the player's State and is presentation only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local MineralIndex = require(ReplicatedStorage.Shared.MineralIndex)
local UI = require(script.Parent.Parent.UI)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent
local player = Players.LocalPlayer

local IndexController = Knit.CreateController({ Name = "IndexController" })

type Scope = UI.Scope
type PlayerIndex = MineralIndex.PlayerIndex

local Pages = Config.Index.Pages
local PageOrder = Config.Index.PageOrder
local RICH = Config.Index.RichColor

local PANEL_WIDTH, PANEL_HEIGHT = 740, 520
local CARD_WIDTH, CARD_HEIGHT, CARD_GAP = 160, 222, 12
-- The HUD button column (ShopController's SHOP button sits at 296): INDEX goes right under it
local BUTTON_WIDTH, BUTTON_HEIGHT = 138, 46
local INDEX_BUTTON_Y = 296 + BUTTON_HEIGHT + 10

-- "+2%" from a fraction of 0.02
local function percent(fraction: number): string
	return "+" .. Format.number(math.floor(fraction * 100 + 0.5)) .. "%"
end

-- A cut gem in the mineral's colour, or a dark "?" silhouette until it is found.
local function gem(scope: Scope, mineral: Config.Mineral, known: Fusion.UsedAs<boolean>)
	local function diamond(position: UDim2, color: Fusion.UsedAs<Color3>, children: { any }?)
		return scope:New("Frame")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = position,
			Size = UDim2.fromScale(0.62, 0.62),
			Rotation = 45,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			[Children] = { UI.corner(scope, 8), children },
		})
	end
	return scope:New("Frame")({
		Name = "Gem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(84, 84),
		BackgroundTransparency = 1,
		[Children] = {
			diamond(UDim2.fromScale(0.55, 0.57), scope:Computed(function(use)
				return if use(known) then mineral.Color:Lerp(Color3.new(0, 0, 0), 0.5) else Color3.fromRGB(20, 14, 12)
			end)),
			diamond(UDim2.fromScale(0.5, 0.5), scope:Computed(function(use)
				return if use(known) then mineral.Color else UI.OUTLINE
			end), {
				scope:New("Frame")({
					Name = "Shine",
					Position = UDim2.fromScale(0.14, 0.14),
					Size = UDim2.fromScale(0.34, 0.34),
					BackgroundColor3 = UI.WHITE,
					BackgroundTransparency = scope:Computed(function(use)
						return if use(known) then 0.45 else 1
					end),
					BorderSizePixel = 0,
					[Children] = { UI.corner(scope, 4) },
				}),
			}),
			UI.label(scope, {
				Size = UDim2.fromScale(1, 1),
				Text = "?",
				TextSize = 36,
				TextColor3 = UI.SUBTEXT,
				Visible = scope:Computed(function(use)
					return not use(known)
				end),
			}),
		},
	})
end

local function mineralCard(scope: Scope, order: number, mineral: Config.Mineral, index: Fusion.UsedAs<PlayerIndex>)
	local count = scope:Computed(function(use)
		return use(index)[mineral.Id] or 0
	end)
	local known = scope:Computed(function(use)
		return use(count) > 0
	end)
	return scope:New("Frame")({
		Name = mineral.Id,
		LayoutOrder = order,
		Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
		BackgroundColor3 = UI.CARD,
		[Children] = {
			UI.corner(scope, 12),
			scope:New("UIStroke")({
				Thickness = 2,
				Color = scope:Computed(function(use)
					return if use(known) then mineral.Color elseif mineral.RichOnly then RICH else UI.OUTLINE
				end),
			}),
			scope:New("Frame")({
				Name = "Showcase",
				Position = UDim2.fromOffset(10, 10),
				Size = UDim2.new(1, -20, 0, 100),
				BackgroundColor3 = UI.PANEL_DARK,
				[Children] = { UI.corner(scope, 10), gem(scope, mineral, known) },
			}),
			UI.label(scope, {
				Name = "MineralName",
				Position = UDim2.fromOffset(8, 116),
				Size = UDim2.new(1, -16, 0, 40),
				TextSize = 18,
				TextWrapped = true,
				Text = scope:Computed(function(use)
					return if use(known) then mineral.Name else "???"
				end),
				TextColor3 = scope:Computed(function(use)
					return if use(known) then mineral.Color:Lerp(UI.WHITE, 0.35) else UI.SUBTEXT
				end),
			}),
			UI.body(scope, {
				Name = "Found",
				Position = UDim2.fromOffset(8, 158),
				Size = UDim2.new(1, -16, 0, 18),
				TextSize = 13,
				Text = scope:Computed(function(use)
					return if use(known) then "Found ×" .. Format.number(use(count)) else "Not found yet"
				end),
				TextColor3 = scope:Computed(function(use)
					return if use(known) then UI.GREEN else UI.SUBTEXT
				end),
			}),
			UI.body(scope, {
				Name = "Odds",
				Position = UDim2.fromOffset(8, 178),
				Size = UDim2.new(1, -16, 0, 34),
				TextSize = 13,
				TextWrapped = true,
				Text = MineralIndex.oddsText(mineral),
				TextColor3 = if mineral.RichOnly then RICH else UI.SUBTEXT,
			}),
		},
	})
end

-- One page: its progress, reward and tier line, then a row of mineral cards.
local function pageView(scope: Scope, page: Config.IndexPage, index: Fusion.UsedAs<PlayerIndex>, visible: Fusion.UsedAs<boolean>)
	local meteorType = Config.Meteor.Types[page.Id]
	local glow = if meteorType then meteorType.GlowColor else UI.ORANGE
	local requiredTier = if meteorType then meteorType.RequiredTier else 1
	local total = #page.Minerals
	local found = scope:Computed(function(use)
		return MineralIndex.found(use(index), page.Id)
	end)
	local complete = scope:Computed(function(use)
		return use(found) >= total
	end)

	local cards = {}
	for order, mineral in page.Minerals do
		cards[order] = mineralCard(scope, order, mineral, index)
	end
	local reward = percent(page.CashBonus) .. " bar sales and the title \"" .. page.Title .. "\""
	local drops = if requiredTier <= 1
		then "Drops for every pickaxe on " .. page.Name .. " meteors"
		else "Drops only for Tier " .. requiredTier .. "+ pickaxes on " .. page.Name .. " meteors"

	return scope:New("Frame")({
		Name = page.Id .. "Page",
		Position = UDim2.fromOffset(20, 162),
		Size = UDim2.new(1, -40, 0, 300),
		BackgroundTransparency = 1,
		Visible = visible,
		[Children] = {
			UI.label(scope, {
				Size = UDim2.new(0.5, 0, 0, 26),
				Text = string.upper(page.Name) .. " PAGE",
				TextSize = 22,
				TextColor3 = glow,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			UI.body(scope, {
				Position = UDim2.fromOffset(0, 28),
				Size = UDim2.new(0.45, 0, 0, 16),
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = scope:Computed(function(use)
					return if use(complete)
						then "PAGE COMPLETE!"
						else Format.number(use(found)) .. " / " .. Format.number(total) .. " minerals found"
				end),
				TextColor3 = scope:Computed(function(use)
					return if use(complete) then UI.GREEN else UI.SUBTEXT
				end),
			}),
			scope:New("Frame")({
				Name = "Progress",
				Position = UDim2.fromOffset(0, 48),
				Size = UDim2.new(0.45, 0, 0, 8),
				BackgroundColor3 = UI.OUTLINE,
				BorderSizePixel = 0,
				[Children] = {
					UI.corner(scope, 4),
					scope:New("Frame")({
						Size = scope:Computed(function(use)
							return UDim2.fromScale(use(found) / math.max(total, 1), 1)
						end),
						BackgroundColor3 = scope:Computed(function(use)
							return if use(complete) then UI.GREEN else glow
						end),
						BorderSizePixel = 0,
						[Children] = { UI.corner(scope, 4) },
					}),
				},
			}),
			UI.body(scope, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.53, 0, 0, 58),
				TextSize = 13,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = scope:Computed(function(use)
					return (if use(complete) then "Earned: " else "Complete it for ") .. reward .. "\n" .. drops
				end),
			}),
			scope:New("ScrollingFrame")({
				Name = "Cards",
				Position = UDim2.fromOffset(0, 66),
				Size = UDim2.new(1, 0, 0, CARD_HEIGHT + 12),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(total * (CARD_WIDTH + CARD_GAP) - CARD_GAP + 24, 0),
				ScrollingDirection = Enum.ScrollingDirection.X,
				ScrollBarThickness = 5,
				ScrollBarImageColor3 = UI.CASH,
				ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
				[Children] = {
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 3) }),
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, CARD_GAP),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					cards,
				},
			}),
		},
	})
end

function IndexController:KnitStart()
	local IndexService = Knit.GetService("IndexService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local HUDController = Knit.GetController("HUDController")

	local scope = Fusion.scoped(Fusion)
	local open, tab, fresh = scope:Value(false), scope:Value(PageOrder[1]), scope:Value(false)
	local shopOpen = scope:Value(player:GetAttribute("ShopOpen") == true)
	table.insert(scope, player:GetAttributeChangedSignal("ShopOpen"):Connect(function()
		shopOpen:set(player:GetAttribute("ShopOpen") == true)
	end))

	-- Same sizing as the shop: the panel scales to fit the screen height
	local viewport = scope:Value(Vector2.new(1280, 720))
	local cameraConnection: RBXScriptConnection? = nil
	local function bindCamera()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
		local camera = workspace.CurrentCamera
		if camera then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				viewport:set(camera.ViewportSize)
			end)
			viewport:set(camera.ViewportSize)
		end
	end
	bindCamera()
	table.insert(scope, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
	local scale = scope:Computed(function(use)
		return math.min(1, math.max(0.35, (use(viewport).Y - 52) / PANEL_HEIGHT))
	end)
	local hudScale = scope:Computed(function(use)
		local v = use(viewport)
		return math.clamp(math.min(v.X / 1050, v.Y / 760), 0.45, 1)
	end)
	local width = scope:Computed(function(use)
		return math.min(PANEL_WIDTH, (use(viewport).X - 24) / use(scale))
	end)
	local compact = scope:Computed(function(use)
		return use(width) < 650
	end)

	local playerState = scope:Value(nil :: any)
	PlayerStateService.State:Observe(function(value)
		playerState:set(value)
	end)
	local index = scope:Computed(function(use): PlayerIndex
		local s = use(playerState)
		return if s and s.index then s.index else {}
	end)

	scope:Observer(open):onChange(function()
		if Fusion.peek(open) then
			fresh:set(false)
		end
	end)
	table.insert(scope, UserInputService.InputBegan:Connect(function(input)
		if Fusion.peek(open) and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			open:set(false)
		end
	end))

	local tabButtons = {}
	local pages = {}
	for order, pageId in PageOrder do
		local page = Pages[pageId]
		tabButtons[order] = UI.button(scope, {
			Name = pageId .. "Tab",
			LayoutOrder = order,
			Size = UDim2.new(1 / #PageOrder, -6, 1, 0),
			TextSize = 16,
			Text = scope:Computed(function(use)
				local found = MineralIndex.found(use(index), pageId)
				return string.upper(page.Name) .. "  " .. Format.number(found) .. "/" .. Format.number(#page.Minerals)
			end),
			BackgroundColor3 = scope:Computed(function(use)
				return if use(tab) == pageId then UI.CASH else UI.CARD
			end),
			TextColor3 = scope:Computed(function(use)
				return if use(tab) == pageId then UI.OUTLINE else UI.SUBTEXT
			end),
			[OnEvent("Activated")] = function()
				tab:set(pageId)
			end,
		})
		pages[order] = pageView(scope, page, index, scope:Computed(function(use)
			return use(tab) == pageId
		end))
	end

	local gui = scope:New("ScreenGui")({
		Name = "MineralIndex",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		-- Above the shop, so its dimmer covers the SHOP button; the INDEX button hides while the shop is open
		DisplayOrder = 21,
		Parent = player:WaitForChild("PlayerGui"),
		[Children] = {
			UI.button(scope, {
				Name = "IndexButton",
				AnchorPoint = Vector2.new(1, 0),
				Position = scope:Computed(function(use)
					return UDim2.new(1, -18, 0, 36 + INDEX_BUTTON_Y * use(hudScale))
				end),
				Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT),
				Text = "INDEX",
				TextSize = 28,
				-- Lights up after a new find until the panel is opened
				BackgroundColor3 = scope:Spring(scope:Computed(function(use)
					return if use(fresh) then UI.GREEN else UI.SHARD
				end), 12, 1),
				Visible = scope:Computed(function(use)
					return not use(open) and not use(shopOpen)
				end),
				[Children] = { scope:New("UIScale")({ Scale = hudScale }) },
				[OnEvent("Activated")] = function()
					open:set(true)
				end,
			}),
			scope:New("TextButton")({
				Name = "Dimmer",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(9, 10, 16),
				BackgroundTransparency = 0.28,
				Text = "",
				AutoButtonColor = false,
				BorderSizePixel = 0,
				Visible = open,
				ZIndex = 2,
				Modal = true,
				[OnEvent("Activated")] = function()
					open:set(false)
				end,
			}),
			scope:New("Frame")({
				Name = "Panel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = scope:Computed(function(use)
					return UDim2.fromOffset(use(width), PANEL_HEIGHT)
				end),
				BackgroundColor3 = UI.PANEL,
				Visible = open,
				ZIndex = 3,
				Active = true,
				[Children] = {
					UI.panelFill(scope),
					scope:New("UIScale")({ Scale = scale }),
					scope:New("Frame")({
						Name = "Interior",
						Position = UDim2.fromOffset(9, 104),
						Size = UDim2.new(1, -18, 1, -113),
						BackgroundColor3 = UI.PANEL_DARK,
						[Children] = { UI.corner(scope, 12) },
					}),
					UI.label(scope, {
						Position = UDim2.fromOffset(22, 12),
						Size = UDim2.fromOffset(300, 37),
						Text = "MINERAL INDEX",
						TextSize = 32,
						TextColor3 = UI.SHARD,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					UI.body(scope, {
						Position = UDim2.fromOffset(24, 53),
						Size = UDim2.fromOffset(330, 24),
						Text = "Rare finds from meteor hits. The odds never change.",
						TextSize = 15,
						TextXAlignment = Enum.TextXAlignment.Left,
						Visible = scope:Computed(function(use)
							return not use(compact)
						end),
					}),
					-- Total bonus from completed pages and the best title earned
					scope:New("Frame")({
						Name = "Bonus",
						Position = scope:Computed(function(use)
							return if use(compact) then UDim2.fromOffset(20, 54) else UDim2.new(1, -318, 0, 18)
						end),
						Size = UDim2.fromOffset(250, 46),
						BackgroundColor3 = UI.PANEL_DARK,
						[Children] = {
							UI.corner(scope, 10),
							UI.label(scope, {
								Position = UDim2.fromOffset(12, 4),
								Size = UDim2.new(1, -24, 0, 20),
								TextSize = 17,
								TextColor3 = UI.CASH,
								TextXAlignment = Enum.TextXAlignment.Left,
								Text = scope:Computed(function(use)
									local bonus = MineralIndex.cashBonus(use(index)) - 1
									return if bonus > 0 then percent(bonus) .. " bar sales" else "No index bonus yet"
								end),
							}),
							UI.body(scope, {
								Position = UDim2.fromOffset(12, 25),
								Size = UDim2.new(1, -24, 0, 16),
								TextSize = 12,
								TextXAlignment = Enum.TextXAlignment.Left,
								Text = scope:Computed(function(use)
									local titles = MineralIndex.titles(use(index))
									local best = titles[#titles]
									return if best then "Title: " .. best else "Complete a page for a title"
								end),
							}),
						},
					}),
					UI.button(scope, {
						Name = "Close",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -18, 0, 18),
						Size = UDim2.fromOffset(42, 42),
						Text = "X",
						TextSize = 23,
						BackgroundColor3 = UI.RED,
						TextColor3 = UI.WHITE,
						[OnEvent("Activated")] = function()
							open:set(false)
						end,
					}),
					scope:New("Frame")({
						Name = "Tabs",
						Position = UDim2.fromOffset(20, 112),
						Size = UDim2.new(1, -40, 0, 40),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0, 9),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							tabButtons,
						},
					}),
					pages,
					UI.body(scope, {
						Name = "Footer",
						Position = UDim2.new(0, 20, 1, -50),
						Size = UDim2.new(1, -40, 0, 36),
						TextSize = 13,
						TextWrapped = true,
						Text = "Rich nodes sparkle gold. Only your own pickaxe unlocks a meteor's minerals, and nothing you can buy changes the odds.",
					}),
				},
			}),
		},
	})

	-- "+1 Magnetite" rises off the INDEX button on a repeat find
	local function floatUp(text: string, color: Color3)
		local s = Fusion.peek(hudScale)
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(1, 0.5)
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(1, -18 - (BUTTON_WIDTH + 8) * s, 0, 36 + (INDEX_BUTTON_Y + BUTTON_HEIGHT / 2) * s)
		label.Size = UDim2.fromOffset(280, 30)
		label.Font = UI.FONT
		label.Text = text
		label.TextSize = 24 * s
		label.TextColor3 = color
		label.TextStrokeColor3 = UI.OUTLINE
		label.TextStrokeTransparency = 0
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.Parent = gui
		TweenService:Create(label, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = label.Position - UDim2.fromOffset(0, 40 * s),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(1.5, function()
			label:Destroy()
		end)
	end

	IndexService.Discovered:Connect(function(mineralId: string, _count: number, isNew: boolean)
		local mineral, page = MineralIndex.find(mineralId)
		if not mineral or not page then
			return
		end
		if isNew then
			HUDController:Toast("New mineral: " .. mineral.Name .. "!")
			if not Fusion.peek(open) then
				fresh:set(true)
				tab:set(page.Id) -- the panel opens on the page of the new find
			end
		else
			floatUp("+1 " .. mineral.Name, mineral.Color:Lerp(UI.WHITE, 0.3))
		end
	end)
end

return IndexController

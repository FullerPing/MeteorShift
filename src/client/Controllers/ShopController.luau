--!strict
-- The shop (spec §10): pickaxes, backpacks and the plot's production line.
-- Opens from the SHOP button or the Pickaxe Shop in town. Every tier is listed so
-- players can see what's ahead; only the next one can be bought, and the server
-- checks the price again (ShopService, UpgradeService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Price = require(ReplicatedStorage.Shared.Price)
local UI = require(script.Parent.Parent.UI)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local player = Players.LocalPlayer

local ShopController = Knit.CreateController({
	Name = "ShopController",
})

type Scope = UI.Scope
type RowState = "owned" | "equipped" | "next" | "locked" | "max"

local TABS = {
	{ Id = "pickaxe", Name = "Pickaxes" },
	{ Id = "backpack", Name = "Backpacks" },
	{ Id = "plot", Name = "Plot" },
}

local STATION_UNITS = { hopper = "ore", conveyor = "ore/s", refinery = "bars/s", collector = "bars" }

-- Other controllers may call in before KnitStart builds the UI, so keep the
-- wanted state here and hand it to the Fusion values once they exist.
local wantOpen = false
local wantHighlight = false
local isOpen: Fusion.Value<boolean>? = nil
local highlight: Fusion.Value<boolean>? = nil

function ShopController:Open()
	wantOpen = true
	if isOpen then
		isOpen:set(true)
	end
end

-- The tutorial points at the SHOP button on its last step.
function ShopController:SetHighlight(on: boolean)
	wantHighlight = on
	if highlight then
		highlight:set(on)
	end
end

local function row(
	scope: Scope,
	props: {
		Order: number,
		Title: Fusion.UsedAs<string>,
		Detail: Fusion.UsedAs<string>,
		TitleColor: Color3?,
		State: Fusion.UsedAs<RowState>,
		Cost: Fusion.UsedAs<number>,
		Shards: Fusion.UsedAs<number>,
		Wallet: Fusion.UsedAs<Price.Wallet>,
		OnBuy: () -> (),
	}
)
	local affordable = scope:Computed(function(use)
		return Price.canAfford(use(props.Wallet), use(props.Cost), use(props.Shards))
	end)
	return scope:New("Frame")({
		LayoutOrder = props.Order,
		Size = UDim2.new(1, -10, 0, 58),
		BackgroundColor3 = UI.OUTLINE,
		BackgroundTransparency = scope:Computed(function(use)
			return if use(props.State) == "next" then 0.55 else 0.75
		end),
		[Children] = {
			UI.corner(scope, 10),
			UI.label(scope, {
				Position = UDim2.fromOffset(12, 5),
				Size = UDim2.new(1, -150, 0, 26),
				Text = props.Title,
				TextSize = 21,
				TextColor3 = props.TitleColor or UI.WHITE,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			UI.label(scope, {
				Position = UDim2.fromOffset(12, 31),
				Size = UDim2.new(1, -150, 0, 20),
				Text = props.Detail,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			UI.button(scope, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(128, 40),
				TextSize = 17,
				AutoButtonColor = scope:Computed(function(use)
					return use(props.State) == "next"
				end),
				Text = scope:Computed(function(use)
					local state = use(props.State)
					if state == "equipped" then
						return "EQUIPPED"
					elseif state == "owned" then
						return "OWNED"
					elseif state == "max" then
						return "MAX"
					end
					return Price.text(use(props.Cost), use(props.Shards))
				end),
				BackgroundColor3 = scope:Computed(function(use)
					local state = use(props.State)
					if state == "equipped" or state == "owned" or state == "max" then
						return UI.GREEN
					elseif state == "next" and use(affordable) then
						return UI.CASH
					end
					return UI.MUTED
				end),
				BackgroundTransparency = scope:Computed(function(use)
					return if use(props.State) == "locked" then 0.4 else 0
				end),
				[OnEvent("Activated")] = function()
					if Fusion.peek(props.State) == "next" then
						props.OnBuy()
					end
				end,
			}),
		},
	})
end

local function list(scope: Scope, visible: Fusion.UsedAs<boolean>, rows: { any })
	return scope:New("ScrollingFrame")({
		Position = UDim2.fromOffset(14, 104),
		Size = UDim2.new(1, -28, 1, -118),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UI.OUTLINE,
		Visible = visible,
		[Children] = {
			scope:New("UIListLayout")({
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			scope:New("UIPadding")({ PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) }),
			rows,
		},
	})
end

-- Owned / equipped / next / locked for a tier list the player climbs one step at a time.
local function tierState(owned: number, tier: number, equippedName: boolean): RowState
	if tier == owned then
		return if equippedName then "equipped" else "owned"
	elseif tier < owned then
		return "owned"
	elseif tier == owned + 1 then
		return "next"
	end
	return "locked"
end

function ShopController:KnitStart()
	local ShopService = Knit.GetService("ShopService")
	local UpgradeService = Knit.GetService("UpgradeService")
	local PlayerStateService = Knit.GetService("PlayerStateService")

	local scope = Fusion.scoped(Fusion)
	local open = scope:Value(wantOpen)
	local tab = scope:Value("pickaxe")
	local glow = scope:Value(wantHighlight)
	isOpen = open
	highlight = glow

	local playerState = scope:Value(nil :: any)
	PlayerStateService.State:Observe(function(value)
		playerState:set(value)
	end)
	ShopService.Open:Connect(function()
		open:set(true)
	end)

	local wallet = scope:Computed(function(use): Price.Wallet
		local s = use(playerState)
		return { cash = if s then s.cash else 0, shards = if s then s.shards else 0 }
	end)
	local function owned(key: string)
		return scope:Computed(function(use)
			local s = use(playerState)
			return if s then s[key] else 1
		end)
	end
	local pickaxeTier = owned("pickaxeTier")
	local backpackTier = owned("backpackTier")

	local function buy(kind: string)
		task.spawn(function()
			ShopService:Buy(kind)
		end)
	end

	local pickaxeRows = {}
	for tier, pickaxe in Config.Pickaxes do
		pickaxeRows[tier] = row(scope, {
			Order = tier,
			Title = pickaxe.Name,
			TitleColor = pickaxe.Color:Lerp(UI.WHITE, 0.35),
			Detail = string.format(
				"%s ore/hit  ·  %.2fs swing  ·  %s dmg",
				Format.number(pickaxe.OrePerHit),
				pickaxe.Swing,
				Format.number(pickaxe.Damage)
			),
			State = scope:Computed(function(use)
				return tierState(use(pickaxeTier), tier, true)
			end),
			Cost = pickaxe.Cost,
			Shards = pickaxe.Shards,
			Wallet = wallet,
			OnBuy = function()
				buy("pickaxe")
			end,
		})
	end

	local backpackRows = {}
	for tier, backpack in Config.Backpacks do
		backpackRows[tier] = row(scope, {
			Order = tier,
			Title = backpack.Name,
			Detail = "Holds " .. Format.number(backpack.Capacity) .. " ore",
			State = scope:Computed(function(use)
				return tierState(use(backpackTier), tier, true)
			end),
			Cost = backpack.Cost,
			Shards = backpack.Shards,
			Wallet = wallet,
			OnBuy = function()
				buy("backpack")
			end,
		})
	end

	local stationRows = {}
	for order, stationId in Config.Home.StationOrder do
		local station = Config.Home.Stations[stationId]
		local level = scope:Computed(function(use)
			local s = use(playerState)
			return if s then s.line[stationId].level else 1
		end)
		local nextLevel = scope:Computed(function(use)
			return station.Levels[use(level) + 1]
		end)
		local function stat(entry: Config.Level): string
			local value = entry.Capacity or entry.Rate or 0
			local text = if entry.Rate then string.format("%g", value) else Format.number(value)
			return text .. " " .. STATION_UNITS[stationId]
		end
		stationRows[order] = row(scope, {
			Order = order,
			Title = scope:Computed(function(use)
				return string.format("%s  ·  Lv %d/%d", station.Name, use(level), #station.Levels)
			end),
			Detail = scope:Computed(function(use)
				local current = station.Levels[use(level)]
				local upcoming = use(nextLevel)
				return if upcoming then stat(current) .. "  →  " .. stat(upcoming) else stat(current)
			end),
			State = scope:Computed(function(use): RowState
				return if use(nextLevel) then "next" else "max"
			end),
			Cost = scope:Computed(function(use)
				local upcoming = use(nextLevel)
				return if upcoming then upcoming.Cost else 0
			end),
			Shards = scope:Computed(function(use)
				local upcoming = use(nextLevel)
				return if upcoming then upcoming.Shards else 0
			end),
			Wallet = wallet,
			OnBuy = function()
				task.spawn(function()
					UpgradeService:BuyStation(stationId)
				end)
			end,
		})
	end

	local tabButtons = {}
	for index, info in TABS do
		tabButtons[index] = UI.button(scope, {
			LayoutOrder = index,
			Size = UDim2.new(1 / #TABS, -6, 1, 0),
			Text = info.Name,
			TextSize = 18,
			BackgroundColor3 = scope:Computed(function(use)
				return if use(tab) == info.Id then UI.CASH else UI.PANEL
			end),
			[OnEvent("Activated")] = function()
				tab:set(info.Id)
			end,
		})
	end

	scope:New("ScreenGui")({
		Name = "Shop",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 2,
		Parent = player:WaitForChild("PlayerGui"),
		[Children] = {
			UI.button(scope, {
				Name = "ShopButton",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -18, 0, 276),
				Size = UDim2.fromOffset(120, 46),
				Text = "SHOP",
				TextSize = 26,
				BackgroundColor3 = scope:Spring(
					scope:Computed(function(use)
						return if use(glow) then UI.GREEN else UI.CASH
					end),
					12,
					1
				),
				Visible = scope:Computed(function(use)
					return not use(open)
				end),
				[OnEvent("Activated")] = function()
					open:set(true)
				end,
			}),

			scope:New("Frame")({
				Name = "Panel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.92, 0.82),
				BackgroundColor3 = UI.PANEL,
				Visible = open,
				[Children] = {
					UI.panelFill(scope),
					scope:New("UISizeConstraint")({ MaxSize = Vector2.new(500, 470) }),
					UI.label(scope, {
						Position = UDim2.fromOffset(0, 10),
						Size = UDim2.new(1, 0, 0, 36),
						Text = "SHOP",
						TextSize = 32,
						TextColor3 = UI.CASH,
					}),
					UI.label(scope, {
						Position = UDim2.fromOffset(18, 14),
						Size = UDim2.fromOffset(160, 28),
						Text = scope:Computed(function(use)
							local w = use(wallet)
							return Format.cash(w.cash) .. "   " .. Format.number(w.shards) .. " ◆"
						end),
						TextSize = 17,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					UI.button(scope, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -12, 0, 12),
						Size = UDim2.fromOffset(38, 38),
						Text = "X",
						TextSize = 22,
						BackgroundColor3 = UI.RED,
						TextColor3 = UI.WHITE,
						[OnEvent("Activated")] = function()
							open:set(false)
						end,
					}),
					scope:New("Frame")({
						Position = UDim2.fromOffset(14, 56),
						Size = UDim2.new(1, -28, 0, 38),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0, 6),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							tabButtons,
						},
					}),
					list(scope, scope:Computed(function(use)
						return use(tab) == "pickaxe"
					end), pickaxeRows),
					list(scope, scope:Computed(function(use)
						return use(tab) == "backpack"
					end), backpackRows),
					list(scope, scope:Computed(function(use)
						return use(tab) == "plot"
					end), stationRows),
				},
			}),
		},
	})
end

return ShopController

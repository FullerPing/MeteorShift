--!strict
-- Small round buttons in the game for the three things that are not in the Store: the 2x Ore
-- pass, the 2x Cash pass and the one-per-player Starter Value Pack. They sit in a row to the
-- column going up from the INDEX button, tap straight to the Roblox purchase prompt, and disappear once
-- the item is owned (or while it is not on sale: Id 0). Move or hide them as "Offers" in
-- Config.HudEdit.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local UI = require(script.Parent.Parent.UI)
local Cartoon = require(script.Parent.Parent.Cartoon)
local Sfx = require(script.Parent.Parent.Sfx)

local player = Players.LocalPlayer
local Monetization = Config.Monetization
local OfferController = Knit.CreateController({ Name = "OfferController" })

local SIZE, GAP = 54, 8
local PANEL_FLAGS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "PetsOpen", "DailyOpen", "CodesOpen", "SettingsOpen", "RefineryOpen", "HatchOpen", "IntroOpen", "BackpackOpen" }

type Offer = { key: string, kind: "pass" | "product", caption: string, icon: string, color: string }
-- bottom to top in the column, nearest the INDEX button first
local OFFERS: { Offer } = {
	{ key = "StarterPack", kind = "product", caption = "STARTER", icon = "bars", color = "green" },
	{ key = "TwoXCash", kind = "pass", caption = "2x CASH", icon = "coin", color = "gold" },
	{ key = "TwoXOre", kind = "pass", caption = "2x ORE", icon = "ore", color = "orange" },
}

function OfferController:KnitStart()
	local MonetizationService = Knit.GetService("MonetizationService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local scope = Fusion.scoped(Fusion)
	local hud = UI.hud(scope)

	local ownedPasses: { [string]: boolean } = {}
	local purchased: { [string]: boolean } = {}

	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "Offers", false, true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local buttons: { [string]: TextButton } = {}
	for _, offer in OFFERS do
		local button = Instance.new("TextButton")
		button.Name, button.Text, button.AutoButtonColor, button.BackgroundTransparency = offer.key, "", false, 1
		button.Size = UDim2.fromOffset(SIZE, SIZE)
		Cartoon.surface(offer.color, { round = true, edge = 3, lip = 4, studs = 0.84, studSize = 18 }).Parent = button
		local icon = UI.hudIcon(scope, offer.icon, {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.1), Size = UDim2.fromScale(0.5, 0.5), ZIndex = 2,
		})
		icon.Parent = button
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency, label.Font, label.TextScaled, label.TextColor3, label.Text = 1, UI.FONT, true, UI.WHITE, offer.caption
		label.Position, label.Size, label.ZIndex = UDim2.fromScale(0.04, 0.58), UDim2.fromScale(0.92, 0.3), 2
		Cartoon.outlineLabel(label)
		label.Parent = button
		button.Activated:Connect(function()
			Sfx.play("Click")
			local definition = if offer.kind == "pass" then Monetization.Passes[offer.key] else Monetization.Products[offer.key]
			if definition.Id == 0 then return end
			local ok, err = pcall(function()
				if offer.kind == "pass" then
					MarketplaceService:PromptGamePassPurchase(player, definition.Id)
				else
					MarketplaceService:PromptProductPurchase(player, definition.Id)
				end
			end)
			if not ok then warn("[OfferController] purchase prompt failed:", err) end
		end)
		button.Parent = gui
		buttons[offer.key] = button
	end

	local function owned(offer: Offer): boolean
		return if offer.kind == "pass" then ownedPasses[offer.key] == true else purchased[offer.key] == true
	end
	local function panelOpen(): boolean
		for _, flag in PANEL_FLAGS do
			if player:GetAttribute(flag) == true then return true end
		end
		return false
	end
	local function refresh()
		local layout = Fusion.peek(hud)
		local index = layout.buttons.INDEX
		-- Daily Rewards can sit right above Index: the offers climb from whichever of the two is higher
		local daily = layout.buttons.DAILY
		local top = if index and daily and math.abs(daily.x - index.x) < 1 then math.min(index.y, daily.y) elseif index then index.y else 0
		local hidden = panelOpen() or HudLayout.isHidden(layout, "Offers") or index == nil
		local blockers = {}
		for _, other in { layout.timer, layout.eventPanel, layout.backpack, layout.thumbstick, layout.jump, layout.mine, layout.settings } do
			table.insert(blockers, other)
		end
		local slot = 0
		for _, offer in OFFERS do
			local button = buttons[offer.key]
			local definition = if offer.kind == "pass" then Monetization.Passes[offer.key] else Monetization.Products[offer.key]
			local visible = not hidden and definition.Id ~= 0 and not owned(offer)
			if visible and index then
				slot += 1
				local rect = HudLayout.nudged(layout, "Offers", {
					x = index.x + (index.w - SIZE) / 2, y = top - 8 - (SIZE + GAP) * slot, w = SIZE, h = SIZE,
				})
				for _, other in blockers do
					if other and HudLayout.overlaps(rect, other) then visible = false break end
				end
				button.Position = UDim2.fromOffset(rect.x, rect.y)
				button.Size = UDim2.fromOffset(rect.w, rect.h)
			end
			button.Visible = visible
		end
	end

	MonetizationService.Owned:Observe(function(value)
		ownedPasses = value or {}
		refresh()
	end)
	PlayerStateService.State:Observe(function(value)
		local bought = if value then value.purchased else nil
		purchased = { StarterPack = bought ~= nil and bought.starterPack == true }
		refresh()
	end)
	for _, flag in PANEL_FLAGS do player:GetAttributeChangedSignal(flag):Connect(refresh) end
	scope:Observer(hud):onChange(refresh)
	gui.Parent = player:WaitForChild("PlayerGui")
	refresh()
end

return OfferController

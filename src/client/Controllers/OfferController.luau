--!strict
-- Small buttons in the game, drawn like the menu buttons (ExactNavButton.tile), for the 2x Ore pass, the 2x Cash
-- pass and the one-per-player Starter Value Pack. On desktop they climb in a column from the
-- INDEX button; on phones they take the free cells in line with the menu buttons (HudLayout.offerSlots). They open the
-- Store (which sells all three), and disappear once
-- the item is owned (or while it is not on sale: Id 0). Move or hide them as "Offers" in
-- Config.HudEdit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local UI = require(script.Parent.Parent.UI)
local ExactNavButton = require(script.Parent.Parent.ExactNavButton)
local Sfx = require(script.Parent.Parent.Sfx)

local player = Players.LocalPlayer
local Monetization = Config.Monetization
local OfferController = Knit.CreateController({ Name = "OfferController" })

local SIZE, GAP = 54, 14 -- the tile's caption hangs a little below it
local PANEL_FLAGS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "PetsOpen", "DailyOpen", "CodesOpen", "SettingsOpen", "RefineryOpen", "HatchOpen", "IntroOpen", "BackpackOpen" }

type Offer = { key: string, kind: "pass" | "product", caption: string, icon: string }
-- bottom to top in the column, nearest the INDEX button first
local OFFERS: { Offer } = {
	{ key = "StarterPack", kind = "product", caption = "Starter", icon = "bars" },
	{ key = "TwoXCash", kind = "pass", caption = Monetization.Passes.TwoXCash.Name, icon = "coin" },
	{ key = "TwoXOre", kind = "pass", caption = Monetization.Passes.TwoXOre.Name, icon = "ore" },
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
		-- drawn at the menu buttons' 80 x 80 and scaled to the cell
		button.Size = UDim2.fromOffset(80, 80)
		ExactNavButton.tile(button, offer.icon, offer.caption)
		local scale = Instance.new("UIScale")
		scale.Name, scale.Parent = "LayoutScale", button
		-- Opens the Store, where the card shows what it is and costs (ad test 2026-10-18: a straight Robux prompt
		-- converted 0 of 24); the Featured and Passes sections are at the top
		button.Activated:Connect(function()
			Sfx.play("Click")
			player:SetAttribute("StoreOpen", true)
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
		local grid = layout.touch or layout.portrait -- phones: the cells HudLayout found beside the menu buttons
		local hidden = panelOpen() or HudLayout.isHidden(layout, "Offers") or (index == nil and not grid)
		local blockers = {}
		for _, other in { layout.timer, layout.eventPanel, layout.backpack, layout.thumbstick, layout.jump, layout.mine, layout.settings } do
			table.insert(blockers, other)
		end
		local slot = 0
		for _, offer in OFFERS do
			local button = buttons[offer.key]
			local definition = if offer.kind == "pass" then Monetization.Passes[offer.key] else Monetization.Products[offer.key]
			local visible = not hidden and definition.Id ~= 0 and not owned(offer)
			local cell: HudLayout.Rect? = nil
			if visible then
				slot += 1
				cell = if grid then layout.offers[slot] elseif index then {
					x = index.x + (index.w - SIZE) / 2, y = top - 8 - (SIZE + GAP) * slot, w = SIZE, h = SIZE,
				} else nil
				visible = cell ~= nil
			end
			if visible then
				local rect = HudLayout.nudged(layout, "Offers", cell :: HudLayout.Rect)
				-- (the phone cells already keep clear of everything)
				for _, other in if grid then {} else blockers do
					if other and HudLayout.overlaps(rect, other) then visible = false break end
				end
				button.Position = UDim2.fromOffset(rect.x, rect.y)
				;(button:FindFirstChild("LayoutScale") :: UIScale).Scale = math.min(rect.w, rect.h) / 80
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
